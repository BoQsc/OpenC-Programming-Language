# OpenC language server

The public native entry point is:

```text
openc lsp --stdio
```

SH-11 implements the protocol lifecycle, full-document synchronization,
compiler diagnostics, and document formatting in canonical OpenC `.p` source
at `compiler/selfhost/source/cli_lsp.p`. It uses JSON-RPC 2.0 with
`Content-Length` framing on standard input/output and advertises UTF-8
positions, full-document synchronization, and document formatting.

The Windows Hosted runtime only reads and writes framed UTF-8 messages. The
OpenC layer owns JSON-RPC parsing, lifecycle state, request validation,
diagnostic conversion, formatting, and deterministic response serialization.
Input headers are limited to 8 KiB and message bodies to 16 MiB.

Supported SH-11 methods:

```text
initialize
initialized
shutdown
exit
textDocument/didOpen
textDocument/didChange
textDocument/didClose
textDocument/formatting
```

Opening or changing a document runs the native lexer/parser/check path and
publishes stable OpenC rule IDs, severity, UTF-8 ranges, messages, and byte
span data. Formatting calls the same canonical formatter as SH-10 and refuses
to rewrite invalid source.

The deterministic transcript contract is
`schemas/LSP_TRANSCRIPT.schema.json`; the authored request fixture is
`tests/tooling/sh11/session.json`. Run:

```text
python scripts/verify_sh11_lsp.py --force
```

The verifier covers 19 lifecycle, capability, diagnostic, formatting, error,
exit, deterministic-transcript, and framing contracts. Required verification
does not execute the retained D bootstrap seed.

The D implementation under `tools/source/openc/tools/lsp.d` remains as a
comparison implementation. SH-12 is the next native language-intelligence
milestone: document symbols, hover, definition, references, completion, safe
rename, and multi-document/project-aware resolution.

Status: **SH-11 NATIVE IMPLEMENTATION PASS ON WINDOWS X86-64 HOSTED**
