// SPDX-License-Identifier: 0BSD
'use strict';

const vscode = require('vscode');
const childProcess = require('child_process');
const path = require('path');
const fs = require('fs');

const MAX_MESSAGE_BYTES = 4 * 1024 * 1024;
const MAX_HEADER_BYTES = 8 * 1024;
const MAX_PENDING_REQUESTS = 128;
const MAX_DOCUMENTS = 8;
const MAX_RESTARTS = 3;

function lineStart(source, wantedLine) {
  let line = 0;
  let start = 0;
  while (line < wantedLine) {
    const newline = source.indexOf('\n', start);
    if (newline < 0) return source.length;
    start = newline + 1;
    line += 1;
  }
  return start;
}

function toLspPosition(source, value) {
  const start = lineStart(source, value.line);
  const prefix = source.slice(start, start + value.character);
  return {line: value.line, character: Buffer.byteLength(prefix, 'utf8')};
}

function fromLspPosition(source, value) {
  const start = lineStart(source, value.line);
  let end = source.indexOf('\n', start);
  if (end < 0) end = source.length;
  if (end > start && source[end - 1] === '\r') end -= 1;
  const line = source.slice(start, end);
  let bytes = 0;
  let units = 0;
  for (const scalar of line) {
    const width = Buffer.byteLength(scalar, 'utf8');
    if (bytes + width > value.character) break;
    bytes += width;
    units += scalar.length;
  }
  return new vscode.Position(value.line, units);
}

function fromLspRange(source, value) {
  return new vscode.Range(
    fromLspPosition(source, value.start),
    fromLspPosition(source, value.end)
  );
}

function documentSymbol(value, source) {
  const result = new vscode.DocumentSymbol(
    value.name, value.detail || '', value.kind,
    fromLspRange(source, value.range),
    fromLspRange(source, value.selectionRange)
  );
  result.children = (value.children || []).map(child => documentSymbol(child, source));
  return result;
}

function completionItem(value) {
  const result = new vscode.CompletionItem(value.label, value.kind);
  if (value.detail) result.detail = value.detail;
  if (value.insertText) result.insertText = value.insertText;
  if (value.sortText) result.sortText = value.sortText;
  if (value.filterText) result.filterText = value.filterText;
  return result;
}

function hoverContents(value) {
  if (value && typeof value === 'object' && value.kind === 'markdown') {
    return new vscode.MarkdownString(value.value);
  }
  return value;
}

function workspaceEdit(value, client) {
  if (!value || !value.changes) return null;
  const result = new vscode.WorkspaceEdit();
  for (const [uri, edits] of Object.entries(value.changes)) {
    result.set(vscode.Uri.parse(uri), edits.map(edit =>
      vscode.TextEdit.replace(
        fromLspRange(client.sourceFor(uri), edit.range), edit.newText
      )));
  }
  return result;
}

class OpenCClient {
  constructor(context) {
    this.context = context;
    this.output = vscode.window.createOutputChannel('OpenC');
    this.diagnostics = vscode.languages.createDiagnosticCollection('openc');
    this.process = undefined;
    this.buffer = Buffer.alloc(0);
    this.nextId = 1;
    this.pending = new Map();
    this.documents = new Map();
    this.ready = false;
    this.stopping = false;
    this.restartCount = 0;
    this.restartTimer = undefined;
    context.subscriptions.push(this.output, this.diagnostics, this);
  }

  compilerPath() {
    const configured = vscode.workspace.getConfiguration('openc')
      .get('compilerPath', '').trim();
    if (configured) return configured;
    const packaged = [
      this.context.asAbsolutePath(path.join('bin', 'openc.exe')),
      path.resolve(this.context.extensionPath, '..', '..', 'openc.exe')
    ];
    return packaged.find(candidate => fs.existsSync(candidate)) || packaged[1];
  }

  trace(direction, message) {
    if (vscode.workspace.getConfiguration('openc').get('trace.server', false)) {
      this.output.appendLine(`${direction} ${JSON.stringify(message)}`);
    }
  }

  async start() {
    if (this.process || this.stopping) return;
    const executable = this.compilerPath();
    this.output.appendLine(`Starting ${executable} lsp --stdio`);
    const server = childProcess.spawn(executable, ['lsp', '--stdio'], {
      cwd: vscode.workspace.workspaceFolders?.[0]?.uri.fsPath,
      windowsHide: true,
      stdio: ['pipe', 'pipe', 'pipe']
    });
    this.process = server;
    this.buffer = Buffer.alloc(0);
    server.stdout.on('data', chunk => this.receive(chunk));
    server.stderr.on('data', chunk => this.output.append(chunk.toString('utf8')));
    server.on('error', error => this.output.appendLine(`Server error: ${error.message}`));
    server.on('exit', (code, signal) => this.exited(server, code, signal));

    const root = vscode.workspace.workspaceFolders?.[0]?.uri.toString() || null;
    try {
      await this.request('initialize', {
        processId: process.pid,
        rootUri: root,
        capabilities: {
          general: {positionEncodings: ['utf-8']},
          workspace: {workspaceFolders: true}
        },
        workspaceFolders: (vscode.workspace.workspaceFolders || [])
          .map(folder => ({uri: folder.uri.toString(), name: folder.name}))
      });
      this.ready = true;
      this.restartCount = 0;
      this.notify('initialized', {});
      this.resynchronize();
    } catch (error) {
      this.output.appendLine(`Initialization failed: ${error.message}`);
      server.kill();
    }
  }

  send(message) {
    const body = Buffer.from(JSON.stringify(message), 'utf8');
    if (body.length > MAX_MESSAGE_BYTES) {
      throw new Error(`OpenC protocol message exceeds ${MAX_MESSAGE_BYTES} bytes`);
    }
    if (!this.process || !this.process.stdin.writable) {
      throw new Error('OpenC language server is unavailable');
    }
    this.trace('client -> server', message);
    this.process.stdin.write(`Content-Length: ${body.length}\r\n\r\n`);
    this.process.stdin.write(body);
  }

  notify(method, params) {
    try {
      this.send({jsonrpc: '2.0', method, params});
    } catch (error) {
      this.output.appendLine(error.message);
    }
  }

  request(method, params, token) {
    if (this.pending.size >= MAX_PENDING_REQUESTS) {
      return Promise.reject(new Error('OpenC pending-request limit reached'));
    }
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      let cancellation;
      if (token) {
        cancellation = token.onCancellationRequested(() => {
          if (!this.pending.delete(id)) return;
          this.notify('$/cancelRequest', {id});
          reject(new vscode.CancellationError());
        });
      }
      this.pending.set(id, {resolve, reject, cancellation});
      try {
        this.send({jsonrpc: '2.0', id, method, params});
      } catch (error) {
        this.pending.delete(id);
        cancellation?.dispose();
        reject(error);
      }
    });
  }

  receive(chunk) {
    if (this.buffer.length + chunk.length > MAX_MESSAGE_BYTES + MAX_HEADER_BYTES) {
      this.failProtocol('OpenC protocol receive buffer exceeded its fixed limit');
      return;
    }
    this.buffer = Buffer.concat([this.buffer, chunk]);
    while (true) {
      const headerEnd = this.buffer.indexOf('\r\n\r\n');
      if (headerEnd < 0) {
        if (this.buffer.length > MAX_HEADER_BYTES) this.failProtocol('Oversized LSP header');
        return;
      }
      if (headerEnd > MAX_HEADER_BYTES) {
        this.failProtocol('Oversized LSP header');
        return;
      }
      const header = this.buffer.subarray(0, headerEnd).toString('ascii');
      const match = /^Content-Length:\s*([0-9]+)$/im.exec(header);
      if (!match) {
        this.failProtocol('Missing Content-Length header');
        return;
      }
      const length = Number(match[1]);
      if (!Number.isSafeInteger(length) || length <= 0 || length > MAX_MESSAGE_BYTES) {
        this.failProtocol('Invalid LSP message length');
        return;
      }
      const start = headerEnd + 4;
      if (this.buffer.length < start + length) return;
      const bytes = this.buffer.subarray(start, start + length);
      this.buffer = this.buffer.subarray(start + length);
      try {
        this.dispatch(JSON.parse(bytes.toString('utf8')));
      } catch (error) {
        this.failProtocol(`Invalid LSP JSON: ${error.message}`);
        return;
      }
    }
  }

  dispatch(message) {
    this.trace('server -> client', message);
    if (Object.prototype.hasOwnProperty.call(message, 'id')) {
      const pending = this.pending.get(message.id);
      if (!pending) return;
      this.pending.delete(message.id);
      pending.cancellation?.dispose();
      if (message.error) pending.reject(new Error(message.error.message));
      else pending.resolve(message.result);
      return;
    }
    if (message.method === 'textDocument/publishDiagnostics') {
      const uri = vscode.Uri.parse(message.params.uri);
      const state = this.documents.get(uri.toString());
      if (state && message.params.version !== undefined &&
          message.params.version !== state.version) return;
      const source = state?.text || '';
      const diagnostics = (message.params.diagnostics || []).map(value => {
        const item = new vscode.Diagnostic(
          fromLspRange(source, value.range), value.message,
          value.severity === 1 ? vscode.DiagnosticSeverity.Error : vscode.DiagnosticSeverity.Warning
        );
        item.code = value.code;
        item.source = value.source;
        return item;
      });
      this.diagnostics.set(uri, diagnostics);
    }
  }

  failProtocol(message) {
    this.output.appendLine(message);
    this.process?.kill();
  }

  exited(server, code, signal) {
    if (this.process !== server) return;
    this.process = undefined;
    this.ready = false;
    this.buffer = Buffer.alloc(0);
    for (const pending of this.pending.values()) {
      pending.cancellation?.dispose();
      pending.reject(new Error('OpenC language server exited'));
    }
    this.pending.clear();
    if (this.stopping) return;
    this.output.appendLine(`Server exited (${code ?? signal ?? 'unknown'})`);
    if (this.restartCount >= MAX_RESTARTS) {
      this.output.appendLine('Bounded restart limit reached; reload the window to retry.');
      return;
    }
    this.restartCount += 1;
    this.restartTimer = setTimeout(() => this.start(), 250 * this.restartCount);
  }

  open(document) {
    if (document.languageId !== 'openc' || this.documents.has(document.uri.toString())) return;
    if (this.documents.size >= MAX_DOCUMENTS) {
      this.output.appendLine(`Document limit (${MAX_DOCUMENTS}) reached; ${document.uri} is not synchronized.`);
      return;
    }
    const state = {
      document, version: document.version, text: document.getText()
    };
    this.documents.set(document.uri.toString(), state);
    if (this.ready) this.sendOpen(state);
  }

  sendOpen(state) {
    this.notify('textDocument/didOpen', {textDocument: {
      uri: state.document.uri.toString(), languageId: 'openc',
      version: state.version, text: state.text
    }});
  }

  change(event) {
    const state = this.documents.get(event.document.uri.toString());
    if (!state || event.document.version <= state.version) return;
    const priorText = state.text;
    const changes = event.contentChanges.length === 1
      ? event.contentChanges.map(change => ({
          range: {
            start: toLspPosition(priorText, change.range.start),
            end: toLspPosition(priorText, change.range.end)
          },
          rangeLength: change.rangeLength,
          text: change.text
        }))
      : [{text: event.document.getText()}];
    state.document = event.document;
    state.version = event.document.version;
    state.text = event.document.getText();
    if (!this.ready) return;
    this.notify('textDocument/didChange', {
      textDocument: {uri: event.document.uri.toString(), version: state.version},
      contentChanges: changes
    });
  }

  close(document) {
    const uri = document.uri.toString();
    if (!this.documents.delete(uri)) return;
    this.diagnostics.delete(document.uri);
    if (this.ready) this.notify('textDocument/didClose', {textDocument: {uri}});
  }

  resynchronize() {
    for (const state of this.documents.values()) this.sendOpen(state);
  }

  workspaceChanged(event) {
    if (!this.ready) return;
    this.notify('workspace/didChangeWorkspaceFolders', {event: {
      added: event.added.map(folder => ({uri: folder.uri.toString(), name: folder.name})),
      removed: event.removed.map(folder => ({uri: folder.uri.toString(), name: folder.name}))
    }});
  }

  textDocument(document) {
    return {textDocument: {uri: document.uri.toString()}};
  }

  positionParams(document, value) {
    const source = this.sourceFor(document.uri.toString());
    return {textDocument: {uri: document.uri.toString()}, position: {
      ...toLspPosition(source, value)
    }};
  }

  sourceFor(uri) {
    return this.documents.get(uri)?.text || '';
  }

  location(value) {
    return new vscode.Location(
      vscode.Uri.parse(value.uri),
      fromLspRange(this.sourceFor(value.uri), value.range)
    );
  }

  async stop() {
    this.stopping = true;
    if (this.restartTimer) clearTimeout(this.restartTimer);
    const server = this.process;
    if (!server) return;
    try {
      if (this.ready) await this.request('shutdown', null);
      this.notify('exit', null);
    } catch (_) {
      server.kill();
    }
  }

  dispose() {
    void this.stop();
  }
}

function registerProviders(context, client) {
  const selector = {language: 'openc', scheme: 'file'};
  context.subscriptions.push(
    vscode.languages.registerDocumentFormattingEditProvider(selector, {
      async provideDocumentFormattingEdits(document, options, token) {
        const result = await client.request('textDocument/formatting', {
          ...client.textDocument(document), options
        }, token);
        return (result || []).map(edit => vscode.TextEdit.replace(
          fromLspRange(document.getText(), edit.range), edit.newText
        ));
      }
    }),
    vscode.languages.registerDocumentSymbolProvider(selector, {
      async provideDocumentSymbols(document, token) {
        const values = await client.request(
          'textDocument/documentSymbol', client.textDocument(document), token
        );
        return (values || []).map(value => documentSymbol(value, document.getText()));
      }
    }),
    vscode.languages.registerHoverProvider(selector, {
      async provideHover(document, at, token) {
        const value = await client.request('textDocument/hover', client.positionParams(document, at), token);
        return value ? new vscode.Hover(
          hoverContents(value.contents),
          value.range ? fromLspRange(document.getText(), value.range) : undefined
        ) : null;
      }
    }),
    vscode.languages.registerDefinitionProvider(selector, {
      async provideDefinition(document, at, token) {
        const value = await client.request('textDocument/definition', client.positionParams(document, at), token);
        if (!value) return null;
        return Array.isArray(value)
          ? value.map(item => client.location(item)) : client.location(value);
      }
    }),
    vscode.languages.registerReferenceProvider(selector, {
      async provideReferences(document, at, options, token) {
        const params = client.positionParams(document, at);
        params.context = {includeDeclaration: options.includeDeclaration};
        return (await client.request('textDocument/references', params, token) || [])
          .map(item => client.location(item));
      }
    }),
    vscode.languages.registerCompletionItemProvider(selector, {
      async provideCompletionItems(document, at, token) {
        const value = await client.request(
          'textDocument/completion', client.positionParams(document, at), token
        );
        const values = Array.isArray(value) ? value : (value?.items || []);
        return new vscode.CompletionList(
          values.map(completionItem), Boolean(value?.isIncomplete)
        );
      }
    }),
    vscode.languages.registerRenameProvider(selector, {
      async prepareRename(document, at, token) {
        const value = await client.request('textDocument/prepareRename', client.positionParams(document, at), token);
        return value ? {
          range: fromLspRange(document.getText(), value.range),
          placeholder: value.placeholder
        } : null;
      },
      async provideRenameEdits(document, at, newName, token) {
        const params = client.positionParams(document, at);
        params.newName = newName;
        return workspaceEdit(
          await client.request('textDocument/rename', params, token), client
        );
      }
    })
  );
}

async function activate(context) {
  const client = new OpenCClient(context);
  registerProviders(context, client);
  context.subscriptions.push(
    vscode.workspace.onDidOpenTextDocument(document => client.open(document)),
    vscode.workspace.onDidChangeTextDocument(event => client.change(event)),
    vscode.workspace.onDidCloseTextDocument(document => client.close(document)),
    vscode.workspace.onDidChangeWorkspaceFolders(event => client.workspaceChanged(event))
  );
  for (const document of vscode.workspace.textDocuments) client.open(document);
  await client.start();
}

function deactivate() {}

module.exports = {activate, deactivate};
