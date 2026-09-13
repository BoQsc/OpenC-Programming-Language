# SH-24 native editor integration and language-service resilience plan

Status: **PASS**

Target: Windows x86-64 Hosted. Linux and freestanding remain optional future
targets and are not gates.

## Required surface

- a first-party Visual Studio Code client for `.p` source that launches the
  native compiler packaged with an OpenC distribution as `openc.exe lsp
  --stdio`;
- dependency-free JSON-RPC `Content-Length` transport and providers for the
  SH-11/SH-12 diagnostics, formatting, symbol, navigation, completion, and
  safe-rename surface;
- incremental UTF-8 document changes with strictly monotonic document versions;
- cooperative request cancellation and workspace-folder lifecycle updates;
- bounded restart and document resynchronization after an unexpected server
  exit; and
- explicit limits for message/header bytes, pending and cancelled requests,
  synchronized documents, and restart attempts.

## Acceptance gates

The OpenC-native `editor-audit` command must pass all 33 records in
`tests/SH24_EDITOR_RESILIENCE_AUDIT_PLAN.tsv`. It statically verifies the
shipped dependency-free client and executes deterministic resilience and
capacity transcripts against the native server. Daily, full, contract,
relocated-release, fixed-point, conformance, throughput, and memory gates must
remain green.

No required SH-24 command may invoke Python, D, C, TinyCC, Node/npm, an
assembler, an external linker, or the network. VS Code's own JavaScript host is
used only when a user runs the extension; it is not part of the OpenC compiler,
build, audit, or release toolchain.
