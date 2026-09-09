# OpenC standalone Windows distribution

This package is the OpenC 1.0 Windows x86-64 Hosted standalone distribution.
Its `openc.exe` compiler is built from the canonical OpenC `.p` compiler
source and emits x64 machine code and PE32+ executables through the first-party
OpenC backend.

Build an OpenC project from any working directory:

```powershell
C:\path\to\OpenC\openc.exe build `
  --project=C:\path\to\project\openc.project.json `
  --output=C:\path\to\project\program.exe
```

The compiler owns its CRT-free Windows runtime and backend. It does not invoke
TinyCC, a C compiler, DMD, DUB, Python, an assembler, or an external linker.

Check or run a project directly:

```text
openc.exe check --project=C:\path\to\project\openc.project.json --output=check-record.json
openc.exe run --project=C:\path\to\project\openc.project.json -- arguments
```

`check` prints concise human diagnostics and optionally preserves stable
machine streams in `openc.check.v1`. `version`, `target`, and
`explain RULE-ID` provide compiler, target, and canonical rule information.

Format, inspect, or test a project directly:

```text
openc.exe fmt --check --project=C:\path\to\project\openc.project.json
openc.exe fmt --write C:\path\to\project\source\main.p
openc.exe info --project=C:\path\to\project\openc.project.json --json
openc.exe test --manifest=C:\path\to\project\openc.tests.json --report=test-result.json
```

These commands emit stable `openc.format.v1`, `openc.tool_context.v1`, and
`openc.test_result.v1` records. Test discovery and execution are name-sorted;
language, runtime-assertion, and infrastructure failures remain distinct.

Start the native language server for an editor client with:

```text
openc.exe lsp --stdio
```

SH-12 supports JSON-RPC lifecycle/capability negotiation, bounded
multi-document open/change/close synchronization, stable OpenC rule-ID
diagnostics, SH-10 document formatting, native document symbols and typed
hover, project definition/reference navigation, deterministic completion,
and validated safe rename over `Content-Length` framed UTF-8 messages.
Baseline transcripts use `openc.lsp_transcript.v1`; project-semantic
transcripts use `openc.semantic_lsp_transcript.v1`.

The optional bootstrap seed at `bootstrap/openc-stage0.exe` is a previous
OpenC-native compiler binary retained for bootstrap continuity. It is not
invoked by `openc.exe build` or by the required conformance gate. Legacy D and
Python implementation source is not shipped in this standalone distribution.

Run the OpenC-authored conformance gate with:

```text
openc.exe validate --manifest=conformance/fixtures/MANIFEST.json --output=conformance-report.json
```

For the supported Windows Hosted mode, `openc.exe` provides the six
`system.file`, `system.io`, `system.memory`, `system.path`, `system.process`,
and `system.text` modules. These modules lower to the OpenC-owned Windows
runtime embedded by the native backend. The authored `.p` Native-provider
library sources are included for future Native work; that separately scoped
provider is not a Windows Hosted release gate.

Package integrity is recorded in `STANDALONE-MANIFEST.sha256`; component roles,
input paths, and compiler/backend hashes are in `STANDALONE-RELEASE.json`.
The applicable project licenses are `LICENSE`, `LICENSES/0BSD.txt`, and
`LICENSES/CC0-1.0.txt`. Legacy C/TinyCC and D/Python audit/bootstrap sources
are intentionally outside this standalone distribution.

The supported release target is Windows x86-64 Hosted. Linux, freestanding,
and the separately scoped Native provider are optional future work and do not
gate this package.
