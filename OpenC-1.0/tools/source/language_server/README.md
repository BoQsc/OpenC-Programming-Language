# OpenC language server

The public native entry point is:

```text
openc lsp --stdio
```

SH-12 implements the protocol lifecycle, bounded multi-document project
synchronization, compiler diagnostics, formatting, and semantic intelligence
in canonical OpenC `.p` source at
`compiler/selfhost/source/cli_lsp.p` and
`compiler/selfhost/source/cli_lsp_semantic.p`. It uses JSON-RPC 2.0 with
`Content-Length` framing on standard input/output and advertises UTF-8
positions and full-document synchronization.

The Windows Hosted runtime only reads and writes framed UTF-8 messages. The
OpenC layer owns JSON-RPC parsing, lifecycle state, request validation,
diagnostic conversion, formatting, and deterministic response serialization.
Input headers are limited to 8 KiB and message bodies to 16 MiB.

Supported SH-12 methods:

```text
initialize
initialized
shutdown
exit
textDocument/didOpen
textDocument/didChange
textDocument/didClose
textDocument/formatting
textDocument/documentSymbol
textDocument/hover
textDocument/definition
textDocument/references
textDocument/completion
textDocument/prepareRename
textDocument/rename
```

Opening or changing a document runs the native lexer/parser/check path and
publishes stable OpenC rule IDs, severity, UTF-8 ranges, messages, and byte
span data. Formatting calls the same canonical formatter as SH-10 and refuses
to rewrite invalid source. Semantic requests resolve the synchronized
`initialize.rootUri` project context in deterministic URI/source order.

The deterministic transcript contract is
`schemas/LSP_TRANSCRIPT.schema.json`; the authored request fixture is
`tests/tooling/sh11/session.json`. Run:

```text
python scripts/verify_sh11_lsp.py --force
python scripts/verify_sh12_semantic_lsp.py --force
```

The baseline verifier covers 19 lifecycle, capability, diagnostic, formatting,
error, exit, deterministic-transcript, and framing contracts. The SH-12
verifier adds 23 project-semantic contracts and
`openc.semantic_lsp_transcript.v1`, including opposite document-open orders,
project-root isolation, safe rename rejection, and synchronized close.
Required verification does not execute the retained D bootstrap seed.

The D implementation under `tools/source/openc/tools/lsp.d` remains as a
comparison implementation. SH-13 is next: first-party editor integration,
incremental/versioned synchronization, cancellation, workspace lifecycle, and
bounded protocol stress.

Status: **SH-12 NATIVE IMPLEMENTATION PASS ON WINDOWS X86-64 HOSTED**
