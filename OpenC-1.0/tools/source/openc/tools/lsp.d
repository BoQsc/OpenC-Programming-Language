module openc.tools.lsp;

import openc.ast : AstNode, NodeKind;
import openc.compiler : CompilationOptions, CompilationResult, Compiler;
import openc.diagnostic : DiagnosticSeverity;
import openc.project : ProjectConfig;
import openc.source : SourceFile, SourceSpan;
import openc.tools.formatter : Formatter;
import std.conv : to;
import std.file : tempDir, write;
import std.format : format;
import std.json : JSONType, JSONValue, parseJSON;
import std.path : buildPath;
import std.stdio : stdin, stdout;
import std.string : indexOf, splitLines, startsWith, strip;
import std.uri : decode;

final class LanguageServer {
private:
    Compiler compiler;
    string[string] documents;
    CompilationResult[string] compilations;
    string[string] virtualPaths;
    bool shutdownRequested;

public:
    this(Compiler compiler) {
        this.compiler = compiler;
    }

    int run() {
        while (!stdin.eof) {
            auto message = readMessage();
            if (message.type == JSONType.null_) break;
            handle(message);
            if (shutdownRequested) break;
        }
        return 0;
    }

private:
    JSONValue readMessage() {
        size_t length;
        while (true) {
            auto line = stdin.readln();
            if (!line.length) return JSONValue(null);
            line = line.strip;
            if (!line.length) break;
            if (line.startsWith("Content-Length:")) {
                length = line[15 .. $].strip.to!size_t;
            }
        }
        if (!length) return JSONValue(null);
        auto buffer = new char[length];
        stdin.rawRead(buffer);
        return parseJSON(cast(string)buffer);
    }

    void send(JSONValue message) {
        auto text = message.toString();
        stdout.write("Content-Length: ", text.length, "\r\n\r\n", text);
        stdout.flush();
    }

    void respond(JSONValue request, JSONValue result) {
        if ("id" !in request.object) return;
        JSONValue response;
        response["jsonrpc"] = "2.0";
        response["id"] = request.object["id"];
        response["result"] = result;
        send(response);
    }

    void respondError(JSONValue request, long code, string message) {
        if ("id" !in request.object) return;
        JSONValue error; error["code"] = code; error["message"] = message;
        JSONValue response; response["jsonrpc"] = "2.0"; response["id"] = request.object["id"]; response["error"] = error;
        send(response);
    }

    void notify(string method, JSONValue params) {
        JSONValue message;
        message["jsonrpc"] = "2.0";
        message["method"] = method;
        message["params"] = params;
        send(message);
    }

    void handle(JSONValue request) {
        auto object = request.object;
        auto method = object.get("method", JSONValue("")).str;
        auto params = object.get("params", JSONValue());
        if (method == "initialize") {
            JSONValue capabilities;
            capabilities["textDocumentSync"] = 1;
            capabilities["documentFormattingProvider"] = true;
            capabilities["documentSymbolProvider"] = true;
            capabilities["hoverProvider"] = true;
            capabilities["definitionProvider"] = true;
            capabilities["referencesProvider"] = true;
            capabilities["renameProvider"] = true;
            JSONValue completion; completion["resolveProvider"] = false;
            capabilities["completionProvider"] = completion;
            JSONValue result; result["capabilities"] = capabilities;
            respond(request, result);
        } else if (method == "shutdown") {
            shutdownRequested = true;
            respond(request, JSONValue(null));
        } else if (method == "exit") {
            shutdownRequested = true;
        } else if (method == "textDocument/didOpen") {
            auto document = params.object["textDocument"].object;
            documents[document["uri"].str] = document["text"].str;
            publish(document["uri"].str);
        } else if (method == "textDocument/didChange") {
            auto uri = params.object["textDocument"].object["uri"].str;
            auto changes = params.object["contentChanges"].array;
            if (changes.length) documents[uri] = changes[$ - 1].object["text"].str;
            publish(uri);
        } else if (method == "textDocument/didClose") {
            auto uri = params.object["textDocument"].object["uri"].str;
            documents.remove(uri);
            compilations.remove(uri);
            virtualPaths.remove(uri);
            JSONValue p; p["uri"] = uri; p["diagnostics"] = JSONValue(JSONValue[].init); notify("textDocument/publishDiagnostics", p);
        } else if (method == "textDocument/formatting") {
            auto uri = documentUri(params);
            auto source = documents.get(uri, "");
            auto formatted = new Formatter().format(source);
            JSONValue[] edits;
            if (formatted.ok && formatted.value != source) {
                JSONValue edit;
                edit["range"] = fullDocumentRange(source);
                edit["newText"] = formatted.value;
                edits ~= edit;
            }
            respond(request, JSONValue(edits));
        } else if (method == "textDocument/documentSymbol") {
            respond(request, documentSymbols(documentUri(params)));
        } else if (method == "textDocument/hover") {
            respond(request, hover(documentUri(params), params.object["position"]));
        } else if (method == "textDocument/definition") {
            respond(request, definition(documentUri(params), params.object["position"]));
        } else if (method == "textDocument/references") {
            respond(request, references(documentUri(params), params.object["position"]));
        } else if (method == "textDocument/completion") {
            respond(request, completion(documentUri(params)));
        } else if (method == "textDocument/rename") {
            respond(request, rename(documentUri(params), params.object["position"], params.object["newName"].str));
        } else if (method.length && "id" in request.object) {
            respondError(request, -32601, "method not implemented: " ~ method);
        }
    }

    string documentUri(JSONValue params) const {
        return params.object["textDocument"].object["uri"].str;
    }

    JSONValue fullDocumentRange(string source) const {
        JSONValue start; start["line"] = 0; start["character"] = 0;
        JSONValue finish; finish["line"] = source.splitLines().length + 1; finish["character"] = 0;
        JSONValue range; range["start"] = start; range["end"] = finish;
        return range;
    }

    void publish(string uri) {
        auto compiled = compileDocument(uri);
        JSONValue[] diagnostics;
        if (compiled !is null) {
            foreach (item; compiled.diagnostics.all()) {
                JSONValue lsp;
                lsp["range"] = lspRange(compiled, item.span);
                lsp["severity"] = item.severity == DiagnosticSeverity.error ? 1 : 2;
                lsp["code"] = item.rule;
                lsp["source"] = "openc";
                lsp["message"] = item.message;
                diagnostics ~= lsp;
            }
        }
        JSONValue params; params["uri"] = uri; params["diagnostics"] = JSONValue(diagnostics);
        notify("textDocument/publishDiagnostics", params);
    }

    CompilationResult compileDocument(string uri) {
        auto found = uri in documents;
        if (found is null) return null;
        auto path = virtualPath(uri);
        write(path, *found);
        auto project = ProjectConfig.singleSource(path, "lsp.document");
        CompilationOptions options; options.stopAfterCheck = true;
        auto result = compiler.compile(project, options);
        if (!result.ok) return null;
        compilations[uri] = result.value;
        return result.value;
    }

    string virtualPath(string uri) {
        auto existing = uri in virtualPaths;
        if (existing !is null) return *existing;
        ulong hash = 1469598103934665603UL;
        foreach (ubyte value; cast(const(ubyte)[])uri) {
            hash ^= value;
            hash *= 1099511628211UL;
        }
        auto path = buildPath(tempDir(), "openc-lsp-" ~ "%016x".format(hash));
        virtualPaths[uri] = path;
        return path;
    }

    CompilationResult currentCompilation(string uri) {
        auto existing = uri in compilations;
        if (existing !is null) return *existing;
        return compileDocument(uri);
    }

    JSONValue documentSymbols(string uri) {
        auto compiled = currentCompilation(uri);
        JSONValue[] result;
        if (compiled is null) return JSONValue(result);
        foreach (sourceId, parsed; compiled.parsed) {
            if (parsed.root is null) continue;
            foreach (child; parsed.root.children) {
                if (!isDeclaration(child.kind)) continue;
                JSONValue symbol;
                symbol["name"] = child.text.length ? child.text : cast(string)child.kind;
                symbol["kind"] = symbolKind(child.kind);
                symbol["range"] = lspRange(compiled, child.span);
                symbol["selectionRange"] = lspRange(compiled, child.span);
                result ~= symbol;
            }
        }
        return JSONValue(result);
    }

    JSONValue hover(string uri, JSONValue position) {
        auto name = wordAt(documents.get(uri, ""), position);
        if (!name.length) return JSONValue(null);
        auto compiled = currentCompilation(uri);
        auto declaration = findDeclaration(compiled, name);
        if (declaration is null) return JSONValue(null);
        JSONValue contents;
        contents["kind"] = "markdown";
        contents["value"] = "```openc\n" ~ declarationSignature(declaration) ~ "\n```";
        JSONValue result; result["contents"] = contents; result["range"] = lspRange(compiled, declaration.span);
        return result;
    }

    JSONValue definition(string uri, JSONValue position) {
        auto name = wordAt(documents.get(uri, ""), position);
        auto compiled = currentCompilation(uri);
        auto declaration = findDeclaration(compiled, name);
        if (declaration is null) return JSONValue(null);
        JSONValue location;
        location["uri"] = uri;
        location["range"] = lspRange(compiled, declaration.span);
        return location;
    }

    JSONValue references(string uri, JSONValue position) {
        auto name = wordAt(documents.get(uri, ""), position);
        JSONValue[] result;
        if (!name.length) return JSONValue(result);
        auto source = documents.get(uri, "");
        size_t index;
        while (index < source.length) {
            auto found = source[index .. $].indexOf(name);
            if (found < 0) break;
            auto start = index + cast(size_t)found;
            auto end = start + name.length;
            bool left = start == 0 || !isIdentifierContinue(source[start - 1]);
            bool right = end == source.length || !isIdentifierContinue(source[end]);
            if (left && right) {
                JSONValue location; location["uri"] = uri; location["range"] = offsetRange(source, start, end);
                result ~= location;
            }
            index = end;
        }
        return JSONValue(result);
    }

    JSONValue completion(string uri) {
        JSONValue[] items;
        string[] keywords = [
            "import", "export", "struct", "resource", "enum", "const", "ref", "ptr", "optional", "storage",
            "own", "out", "if", "else", "while", "for", "switch", "case", "default", "return", "scope",
            "unsafe", "when", "true", "false", "null", "none", "status", "construct", "destroy"
        ];
        foreach (keyword; keywords) {
            JSONValue item; item["label"] = keyword; item["kind"] = 14; items ~= item;
        }
        auto compiled = currentCompilation(uri);
        if (compiled !is null) {
            foreach (sourceId, parsed; compiled.parsed) {
                if (parsed.root is null) continue;
                appendCompletionDeclarations(parsed.root, items);
            }
        }
        return JSONValue(items);
    }

    JSONValue rename(string uri, JSONValue position, string replacement) {
        if (!validIdentifier(replacement)) {
            JSONValue result; result["changes"] = JSONValue(); return result;
        }
        auto refs = references(uri, position).array;
        JSONValue[] edits;
        foreach (location; refs) {
            JSONValue edit; edit["range"] = location.object["range"]; edit["newText"] = replacement; edits ~= edit;
        }
        JSONValue changes; changes[uri] = JSONValue(edits);
        JSONValue result; result["changes"] = changes;
        return result;
    }

    JSONValue lspRange(CompilationResult compiled, SourceSpan span) const {
        auto source = compiled.sources.get(span.source);
        auto startPosition = source.position(span.start);
        auto endPosition = source.position(span.end);
        JSONValue start; start["line"] = startPosition.line - 1; start["character"] = startPosition.column - 1;
        JSONValue finish; finish["line"] = endPosition.line - 1; finish["character"] = endPosition.column - 1;
        JSONValue range; range["start"] = start; range["end"] = finish;
        return range;
    }

    JSONValue offsetRange(string source, size_t startOffset, size_t endOffset) const {
        auto start = offsetPosition(source, startOffset);
        auto finish = offsetPosition(source, endOffset);
        JSONValue range; range["start"] = start; range["end"] = finish;
        return range;
    }

    JSONValue offsetPosition(string source, size_t offset) const {
        size_t line; size_t character;
        foreach (index, value; source[0 .. offset]) {
            if (value == '\n') { ++line; character = 0; }
            else ++character;
        }
        JSONValue result; result["line"] = line; result["character"] = character;
        return result;
    }

    string wordAt(string source, JSONValue position) const {
        auto line = cast(size_t)position.object["line"].integer;
        auto character = cast(size_t)position.object["character"].integer;
        auto lines = source.splitLines();
        if (line >= lines.length) return "";
        auto text = lines[line];
        if (character > text.length) character = text.length;
        size_t start = character;
        size_t end = character;
        while (start > 0 && isIdentifierContinue(text[start - 1])) --start;
        while (end < text.length && isIdentifierContinue(text[end])) ++end;
        return text[start .. end];
    }

    AstNode findDeclaration(CompilationResult compiled, string name) const {
        if (compiled is null || !name.length) return null;
        foreach (sourceId, parsed; compiled.parsed) {
            auto found = findDeclarationRecursive(parsed.root, name);
            if (found !is null) return found;
        }
        return null;
    }

    AstNode findDeclarationRecursive(AstNode node, string name) const {
        if (node is null) return null;
        if (isDeclaration(node.kind) && node.text == name) return node;
        foreach (child; node.children) {
            auto found = findDeclarationRecursive(child, name);
            if (found !is null) return found;
        }
        return null;
    }

    void appendCompletionDeclarations(AstNode node, ref JSONValue[] items) const {
        if (node is null) return;
        if (isDeclaration(node.kind) && node.text.length) {
            JSONValue item; item["label"] = node.text; item["kind"] = completionKind(node.kind); items ~= item;
        }
        foreach (child; node.children) appendCompletionDeclarations(child, items);
    }

    bool isDeclaration(NodeKind kind) const {
        return kind == NodeKind.functionDecl || kind == NodeKind.structDecl || kind == NodeKind.resourceDecl ||
            kind == NodeKind.enumDecl || kind == NodeKind.enumItem || kind == NodeKind.moduleConstDecl ||
            kind == NodeKind.fieldDecl || kind == NodeKind.parameter || kind == NodeKind.localDecl;
    }

    long symbolKind(NodeKind kind) const {
        if (kind == NodeKind.functionDecl) return 12;
        if (kind == NodeKind.structDecl || kind == NodeKind.resourceDecl) return 23;
        if (kind == NodeKind.enumDecl) return 10;
        if (kind == NodeKind.enumItem) return 22;
        if (kind == NodeKind.fieldDecl) return 8;
        if (kind == NodeKind.moduleConstDecl) return 14;
        return 13;
    }

    long completionKind(NodeKind kind) const {
        if (kind == NodeKind.functionDecl) return 3;
        if (kind == NodeKind.structDecl || kind == NodeKind.resourceDecl || kind == NodeKind.enumDecl) return 7;
        if (kind == NodeKind.fieldDecl) return 5;
        return 6;
    }

    string declarationSignature(AstNode declaration) const {
        if (declaration.kind == NodeKind.functionDecl) return "function " ~ declaration.text;
        if (declaration.kind == NodeKind.structDecl) return "struct " ~ declaration.text;
        if (declaration.kind == NodeKind.resourceDecl) return "resource " ~ declaration.text;
        if (declaration.kind == NodeKind.enumDecl) return "enum " ~ declaration.text;
        if (declaration.kind == NodeKind.fieldDecl) return "field " ~ declaration.text;
        if (declaration.kind == NodeKind.parameter) return "parameter " ~ declaration.text;
        if (declaration.kind == NodeKind.moduleConstDecl) return "const " ~ declaration.text;
        return declaration.text;
    }

    bool validIdentifier(string value) const {
        if (!value.length || !isIdentifierStart(value[0])) return false;
        foreach (ch; value[1 .. $]) if (!isIdentifierContinue(ch)) return false;
        return true;
    }

    bool isIdentifierStart(char value) const {
        return (value >= 'A' && value <= 'Z') || (value >= 'a' && value <= 'z') || value == '_';
    }

    bool isIdentifierContinue(char value) const {
        return isIdentifierStart(value) || (value >= '0' && value <= '9');
    }
}
