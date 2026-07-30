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

The canonical unified driver is `compiler/selfhost/source/main_driver.p`.
The older D driver at `compiler/source/app/main.d` and reusable D modules under
`tools/source/openc/tools/` are retained only as legacy audit material.

SH-10 implements `openc fmt`,
`openc info`, and `openc test` in canonical OpenC `.p` source. SH-11
implements `openc lsp --stdio` lifecycle, full-document synchronization,
rule-ID diagnostics, and SH-10 document formatting, with deterministic
JSON-RPC transcript verification from the relocated standalone compiler.
SH-12 adds project symbols, typed hover, definition/references, sorted
completion, safe rename, and open-order-independent semantic transcripts.

SH-13 completes native throughput instrumentation and implementation-authority
cleanup. SH-14 comes next: first-party editor integration,
incremental/versioned synchronization, cancellation/workspace lifecycle, and
bounded stress.
