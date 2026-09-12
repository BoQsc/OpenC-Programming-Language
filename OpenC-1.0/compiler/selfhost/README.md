# OpenC compiler in OpenC

This directory contains the canonical self-hosting implementation in `.p`
source. A previous OpenC compiler builds `source/main.p` into the next native
Windows compiler, which implements the complete frontend, semantic pipeline,
deterministic IR, C11 emission, public CLI, and language service in OpenC.
The retained D and Python implementations are historical bootstrap/reference
material only: they are not compiler authority, are not invoked by normal
native builds, and are excluded from the standalone compiler distribution.

This is now a standalone executable self-hosted compiler on Windows x86-64
Hosted. Its normal SH-19 path lowers OpenC directly to x64 machine code, writes
deterministic PE32+ executables, and reaches byte-exact Stage-2/Stage-3 closure
without C, TinyCC, D, Python, an assembler, an external linker, or a Microsoft
CRT. SH-6 established the relocatable distribution baseline. SH-7 adds
OpenC-authored native
conformance and removes the retained D seed from the required package gate.
SH-8 makes the native compiler the default Windows compiler-under-test and
adds exact-cache and performance-budget gates. SH-9 adds the OpenC-authored
public developer CLI and human/machine diagnostic surface. SH-10 adds
OpenC-authored native formatting, project-context inspection, and deterministic
project testing. SH-11 adds OpenC-authored stdio JSON-RPC lifecycle,
synchronized compiler diagnostics, and document formatting. The
gate contract is in
`SELF_HOSTING.md`; the machine-readable gate state is
`SELF_HOSTING_STATE.json`. Post-SH-6 native self-rebuild measurements and
reproduction instructions are in `PERFORMANCE.md`.

Run from the repository root after building stage 0:

```text
python compiler/selfhost/bootstrap.py
```

That command builds stage 1 and executes the 304-case lexer gate, 303-case
parser gate, 22-case project/module gate, 17-case declaration/symbol/type gate,
10 exact name/constant/overload comparisons, 240 current flow/safety
comparisons, and full semantic-outcome/canonical-IR comparison with 123
accepted IR cases and 153 exact rejections. SH-2A through SH-2D, full SH-2,
SH-3A through SH-3D, and full SH-3 pass. SH-4A bootstrap D-source backend
parity, SH-4B Stage-1 self-compilation, SH-4C Stage-2/Stage-3 closure, and full
SH-4 also pass.

Run the SH-5 DMD-independent Windows closure proof with:

```text
python compiler/selfhost/bootstrap_windows_closure.py
```

Run the native daily or full SH-8 workflow with:

```text
python scripts/windows_native_workflow.py daily
python scripts/windows_native_workflow.py full
```

The resulting native compiler exposes the public build command:

```text
openc build --project=path/to/openc.project.json --output=path/to/program.exe
```

It also exposes the public native conformance command:

```text
openc validate --manifest=conformance/fixtures/MANIFEST.json --output=conformance-report.json
```

SH-9 adds the public developer commands:

```text
openc check --project=path/to/openc.project.json [--output=check-record.json]
openc run --project=path/to/openc.project.json [-- arguments...]
openc version
openc target
openc explain OPENC-LEX-COMMENT-001
```

`check` renders human diagnostics and can preserve the stable native stage
streams in an `openc.check.v1` record. Verify the complete 12-case surface
with `python scripts/verify_sh9_cli.py`.

SH-10 adds the native project-workflow commands:

```text
openc fmt --check (--project=path/to/openc.project.json|source.p)
openc fmt --write (--project=path/to/openc.project.json|source.p)
openc info --project=path/to/openc.project.json [--json]
openc test --manifest=path/to/openc.tests.json [--list] [--no-run]
openc test --project=path/to/openc.project.json
```

They produce stable `openc.format.v1`, `openc.tool_context.v1`, and
`openc.test_result.v1` records. Verify all 21 cases with
`python scripts/verify_sh10_project_workflow.py`.

SH-11 adds the native language-service command:

```text
openc lsp --stdio
```

It provides initialization/capability negotiation, full-document
open/change/close synchronization, stable compiler rule-ID diagnostics,
SH-10 formatting, shutdown/exit semantics, and deterministic
`openc.lsp_transcript.v1` evidence. Verify all 19 cases with
`python scripts/verify_sh11_lsp.py --force`.

SH-12 adds native project-semantic methods:

```text
textDocument/documentSymbol
textDocument/hover
textDocument/definition
textDocument/references
textDocument/completion
textDocument/prepareRename
textDocument/rename
```

Verify all 23 cases, including opposite document-open orders, with
`python scripts/verify_sh12_semantic_lsp.py --force`.

Run the SH-4 proofs with a built Stage-1 executable and configured DMD:

```text
python compiler/selfhost/bootstrap_d_parity.py --stage1 build-output/selfhost-sh4/closure-final/openc-stage1.exe --output build-output/selfhost-sh4/parity-final
python compiler/selfhost/bootstrap_closure.py --output build-output/selfhost-sh4/closure-final
```

Run the complete SH-6 distribution proof with the commands recorded in
`release/SH6_STANDALONE_EVIDENCE.md`. SH-6 is **PASS**.

The published RC9 successor proof is recorded in
`release/RC9_STANDALONE_EVIDENCE.md`. It passes 278/278 conformance, all 4
maintained programs, 123 canonical-IR comparisons, and 153 exact semantic
rejections from the relocated package. Its native compiler is byte-identical
through Stage 2 and Stage 3 at SHA-256
`5924db13e20464d392dd563a086d35c95c61dafc6862ad7ba0fc767c0cdae4a6`.

SH-7 native conformance and tooling independence is **PASS**. SH-8 native
developer and release workflow hardening is also **PASS**; complete evidence
is in `release/SH8_NATIVE_WORKFLOW_EVIDENCE.md`. SH-9 native CLI and diagnostic
usability is **PASS**; its evidence is in
`release/SH9_NATIVE_CLI_EVIDENCE.md`. SH-10 native project workflow
completeness is **PASS**; its evidence is in
`release/SH10_NATIVE_PROJECT_WORKFLOW_EVIDENCE.md`. SH-11 native
language-service completeness is **PASS**; its evidence is in
`release/SH11_NATIVE_LANGUAGE_SERVICE_EVIDENCE.md`. SH-12 native semantic
language intelligence is **PASS**; its evidence is in
`release/SH12_NATIVE_SEMANTIC_LANGUAGE_EVIDENCE.md`. SH-13 native compiler
throughput instrumentation and implementation independence is **PASS**.
SH-14 compiler throughput convergence and stability is also **PASS**: the
five-run clean median is 4.137 seconds versus D's 12.731 seconds, small and
one-source medians are 0.158 seconds, worst scaling is 2.112x, closure is
20/20, native conformance is 278/278, and maintained programs are 4/4.
SH-15 Windows x64 ABI and machine-code substrate is **PASS**: 104 OpenC source
units implement the Microsoft x64/LLP64 model, typed encoder, relocations,
unwind records, and deterministic probe report, with 25/25 static and
executable checks. SH-16 PE32+ and CRT-free runtime is **PASS**: 107 OpenC
source units emit a deterministic PE32+ image directly, and 34/34 checks prove
imports, relocations, TLS, unwind, UTF-8 conversion, process-heap allocation,
file I/O, cleanup, and execution without the Microsoft CRT, an assembler, or
an external linker. SH-17 Win32 Metadata and raw projection is **PASS**: 112
OpenC compiler sources parse the real pinned metadata and generate seven
byte-reproducible raw modules with 30/30 checks. SH-18 idiomatic Windows
modules pass 27/27 checks across twelve modules. SH-19 compiler-capable native
backend and TinyCC exit is **PASS**: 116 OpenC compiler sources reach an exact
native fixed point and the relocated package passes 20/20 checks. SH-20 public
throughput convergence is also **PASS**: the fully validating self-build has a
17.064-second five-run median, 11.352-second validation median, and 20/20 exact
closure while beating the measured C and D reference medians. SH-21
OpenC-native workflow replacement is now active; tranche 6 passes the 12-task
full workflow and moves the 16-check PE32+/import/unwind/CRT audit, 42-check
framed LSP regression audit, and 20-build throughput/closure gate into the
121-source OpenC compiler. The native build and validation medians are 13.250
and 8.760 seconds, with all hash buffers explicitly released. Deterministic
release/archive ownership remains active. Native editor
integration and language-service resilience remain deferred to SH-24.

The same-host SH-14 clean-build comparator is:

```text
python compiler/selfhost/benchmark_throughput_suite.py --compiler PATH/TO/openc.exe --output build-output/selfhost-sh14/throughput-suite.json --runs 5 --enforce
```

It writes `openc.throughput_suite.v1`, retains every raw OpenC and forced
release D sample, fingerprints both input trees and tool versions, verifies
repeat-build byte closure, and enforces the absolute and D-relative clean-build
gates together. Omit `--enforce` when recording a failing optimization
baseline; command failures still return a nonzero status.

The extended SH-14 regression gates are reproduced by
`benchmark_sh14_extended.py`; complete evidence is recorded in
`release/SH14_COMPILER_THROUGHPUT_CONVERGENCE_EVIDENCE.md`.

The complete SH-15 ABI and encoder gate is reproduced by:

```text
python scripts/verify_sh15_windows_x64.py --compiler PATH/TO/openc.exe --output build-output/selfhost-sh15/sh15-verification.json
```

Evidence is recorded in
`release/SH15_WINDOWS_X64_ABI_MACHINE_CODE_EVIDENCE.md`.

The complete SH-16 PE32+ and runtime gate is reproduced by:

```text
python scripts/verify_sh16_pe_runtime.py --compiler PATH/TO/openc.exe --output build-output/selfhost-sh16/sh16-verification.json
```

Evidence and the bounded direct-backend scope are recorded in
`release/SH16_PE32_PLUS_CRT_FREE_RUNTIME_EVIDENCE.md`.

The complete SH-17 metadata projection gate is reproduced by:

```text
python scripts/verify_sh17_winmd_projection.py --compiler PATH/TO/openc.exe --input PATH/TO/Windows.Win32.winmd --regenerate --repeat 2 --output build-output/selfhost-sh17/sh17-verification.json
```

The exact input is acquired and checked with `scripts/acquire_sh17_winmd.py`.
Evidence is recorded in `release/SH17_WINMD_RAW_PROJECTION_EVIDENCE.md`.
