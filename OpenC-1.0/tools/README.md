# First-party OpenC tool source

Status: **NATIVE OPENC FMT/INFO/TEST/LSP BUILT AND TESTED ON WINDOWS; D TOOL
SOURCES RETAINED**

Authored implementations now exist for:

```text
openc check/build/run/test/eval/live
openc fmt
openc info
openc explain
openc validate
openc adapter
openc lsp --stdio
```

The unified driver is `compiler/source/app/main.d`. Reusable tool modules are in `tools/source/openc/tools/`.

The self-hosted public driver is
`compiler/selfhost/source/main_driver.p`. SH-10 implements `openc fmt`,
`openc info`, and `openc test` in canonical OpenC `.p` source. SH-11
implements `openc lsp --stdio` lifecycle, full-document synchronization,
rule-ID diagnostics, and SH-10 document formatting, with deterministic
JSON-RPC transcript verification from the relocated standalone compiler.

SH-12 comes next: native document symbols, hover, definition, references,
completion, safe rename, and multi-document/project-aware resolution.
