# OpenC self-hosting and standalone compiler gates

The canonical compiler is written in OpenC and completes standalone Windows
self-compilation through OpenC-owned x64 lowering and deterministic PE32+
emission. Its SH-19 normal build and release path requires no generated C,
TinyCC, D, Python, Microsoft CRT, assembler, or external linker. Retained C,
D, Python, and TinyCC material is optional historical audit/bootstrap input,
not compiler authority. SH-6 established relocatable package closure, SH-7
moved required conformance into OpenC, and SH-19 closes the first-party native
backend fixed point.

The supported initial target is Windows x86-64 Hosted. Linux and freestanding
do not gate this program.

## Gates

### SH-0 — canonical source convention

- `.p` is ratified as the official tooling extension.
- Canonical compiler, library, maintained-program, example, and conformance
  source uses `.p`.
- Explicit paths remain extension-independent.

Status: **PASS**

### SH-1 — compiler-in-OpenC frontend seed

- Stage 0 builds a native executable from `compiler/selfhost/source/main.p`.
- The executable reads UTF-8 `.p` source through Hosted APIs.
- It lexically scans its own source and emits a versioned observation protocol.
- Evidence is produced by `python compiler/selfhost/bootstrap.py`.

Status: **PASS**

This is not a self-hosting claim: the seed does not yet compile source.

### SH-2A — exact lexer parity

- The OpenC implementation covers stage-0 keywords, identifiers, numeric and
  text literals, comments, symbols, UTF-8 source rejection, and all lexical
  diagnostics.
- Stage 0 and stage 1 match process outcome, token kind and byte span,
  diagnostic rule and byte span, source line and byte column, and token/error
  totals.
- The parity harness covers all 288 canonical `.p` sources plus 16 focused
  probes: 304 of 304 comparisons pass and all 12 source/lexical diagnostic
  rules are observed. The focused set includes CRLF and lone-CR positions.
- Evidence is produced by `python compiler/selfhost/bootstrap.py` and recorded
  in `build-output/selfhost/lexer-parity-result.json`.

Status: **PASS**

### SH-2B — owned single-pass lexer state

- Stage 1 performs one lexical pass and stores tokens and diagnostics in
  separate OpenC-owned packed buffers.
- Both allocations are released by ownership-checked scoped cleanup.
- Every stored token and diagnostic carries a byte offset, byte length,
  one-based line, and one-based byte column.
- Observation protocol 2 compares all stored fields against stage 0 across
  the complete 304-case SH-2A corpus.

Status: **PASS**

### SH-2C — exact parser parity

- Stage 1 reads the owned token records through parser-facing lookahead and
  matching APIs and stores final syntax records in a third owned buffer.
- Declarations, types, blocks, statements, precedence/assignment expressions,
  postfix operations, initializers, intrinsics, and recovery execute in OpenC.
- Parser observation protocol 1 compares process outcome, syntax-node creation
  order, all 52 parser-produced node kinds and final byte spans, diagnostic
  rule/span/position, node totals, and error totals.
- All 288 canonical `.p` sources plus 15 focused parser probes match exactly:
  303 of 303 comparisons pass and all 15 reachable parser/recovery diagnostic
  rules are observed.

Status: **PASS**

### SH-2D — exact project/module frontend parity

- Stage 1 parses `openc.project.json`, sorts logical modules deterministically,
  preserves source-list order, resolves project-relative source paths, and
  processes multiple source units.
- Project observation protocol 1 compares module/unit/source/import records,
  per-source parser totals and diagnostics, compiler-provided Hosted modules,
  missing imports, ambiguous short qualifiers, direct cycles, and summary
  totals.
- All 7 checked-in projects plus 15 focused project/module probes match
  exactly: 22 of 22 comparisons pass and all 3 composition diagnostic rules
  are observed.

Status: **PASS**

### SH-2 — full frontend parity

- SH-2A through SH-2D jointly cover the lexical, syntactic, recovery, project,
  multi-source, and module-composition frontend.
- Every canonical `.p` fixture source participates in lexer/parser comparison;
  checked-in projects and focused graph cases participate in project parity.
- Matching process outcomes, exact diagnostic rule IDs and locations, syntax
  records, module ordering, imports, graph diagnostics, and totals are required.

Status: **PASS**

This gate does not include types, name resolution beyond module composition,
ownership, flow, lowering, or IR; those are explicitly SH-3.

### SH-3A — declaration, symbol, and type-table parity

- Stage 1 predeclares aggregate/resource/enum types, interns built-in, named,
  qualified, const, view, slice, and fixed-array types, and records top-level
  functions, aggregates, enum items, module constants, fields, parameter
  modes, visibility, resource state, and source spans in OpenC-owned storage.
- Semantic declaration observation protocol 1 compares exact declaration and
  member order, symbol attributes, canonical type IDs and structure, and
  declaration-layer duplicate diagnostics.
- The canonical compiler-in-OpenC project plus 16 focused multi-source and
  multi-module projects match exactly: 17 of 17 comparisons pass, observing
  264 declarations and 385 complete type-table records.
- Evidence is produced by `python compiler/selfhost/bootstrap.py` and recorded
  in `build-output/selfhost/semantic-declaration-parity-result.json`.

Status: **PASS**

### SH-3 — semantic and IR parity

SH-3B establishes the resolution layer:

- Stage 1 owns lexical and module binding tables, local/parameter/field/enum
  target selection, constant-domain results, function signatures, and
  deterministic overload ranking.
- Semantic resolution observation protocol 1 compares exact use and target
  spans, symbol identities, resolved types, constant domains/values, selected
  overloads, call results, and resolution diagnostics.
- The maintained computation project plus 9 focused projects match exactly:
  10 of 10 comparisons pass, observing 32 bindings, 10 constants, 4 selected
  calls, and exact unknown-name, no-match, ambiguity, and divide-by-zero rules.
- Evidence is recorded in
  `build-output/selfhost/semantic-resolution-parity-result.json`.

SH-3B status: **PASS**

SH-3C owns flow, status/out, ownership, borrowing, cleanup, pointer, and unsafe
analysis in OpenC. Semantic flow/safety observation protocol 1 matches exact
function spans, CFG block/edge counts, cleanup order, diagnostic phases/rules,
and diagnostic spans across 3 maintained projects and 263 authored source
fixtures. It compares 232 semantic cases, delegates 34 frontend-error cases to
SH-2, and observes 313 functions, 733 blocks, 464 edges, 34 cleanups, and 19
flow/safety rules.

SH-3C status: **PASS**

SH-3D owns semantic acceptance and deterministic canonical JSON IR lowering.
Across the same maintained/authored corpus, stage 0 and stage 1 match all 149
frontend/semantic rejection outcomes and compare exact IR for 117 accepted
programs: 183 functions, 275 blocks, 1,489 instructions, and all 33 reachable
canonical opcodes. Matching includes module/function/block/instruction order,
types, values, text, byte spans, operands, and target-fault records.

SH-3D status: **PASS**

Status: **PASS**

Evidence is produced by `python compiler/selfhost/bootstrap.py` and recorded
in `semantic-flow-safety-parity-result.json` and
`semantic-ir-parity-result.json` under `build-output/selfhost`.

### SH-4 — bootstrap self-compilation

- SH-4A: port deterministic bootstrap D-source emission and prove generated
  source parity from the canonical IR.
- SH-4B: add the Hosted toolchain driver so stage 1 can invoke the configured D
  compiler and build stage 2 from the same canonical `.p` project.
- SH-4C: have stage 2 build stage 3 and require normalized generated-source,
  semantic-IR, behavior, and artifact equivalence.
- Stage 0 builds stage 1 from `.p`; stage 1 builds stage 2 from the same `.p`.
- Stage 2 builds stage 3; stage 2 and stage 3 are reproducibly equivalent.

SH-4A evidence compares the canonical compiler plus A/B/C projects: all 28
generated D files match Stage 0 byte for byte. SH-4B records Stage 1 invoking
the configured D compiler and producing Stage 2. SH-4C records Stage 2
producing Stage 3, with equal 7-file generated trees, lexer behavior,
canonical IR, and normalized PE artifacts. The normalized Stage-2/Stage-3
hash is
`e1776ad8492ea4181dff91885ea45d371f1288abbdad8423cb2e4a16ef6c9e65`.

Status: **PASS**

### SH-5 — DMD-independent Windows backend

- Implement deterministic Windows x86-64 object emission and the required
  runtime/link step in OpenC, or integrate an owner-approved redistributable
  backend whose bits ship inside the standalone distribution.
- `openc build` succeeds on a clean Windows host without DMD, DUB, or Python.

OpenC now emits deterministic single-file C11 from canonical IR and invokes
the vendored TinyCC 0.9.27 Win64 compiler/linker. The complete upstream binary
tree, LGPL-2.1 license, bundled MIT/public-domain notices, integrity metadata,
and corresponding source archive ship under `third_party/tinycc-win64/`.

The final clean-path proof hid DMD, DUB, and Python from the child environment.
Native Stage 2 built native Stage 3 through the public `openc build` command.
Their 3,179,967-byte generated C files are byte-identical with SHA-256
`ae3c4929bf874ae8c23416a9966c26788a8a294a53853628880fef848a28bbec`;
their 1,534,976-byte Windows executables are also byte-identical with SHA-256
`b42892ed15f944049eefd6b91206dd283de5ce38fef97d6667a1131dc955be5f`.
Lexer behavior, canonical IR, and a public-build execution smoke also match.

Reproduce the complete closure with:

```text
python compiler/selfhost/bootstrap_windows_closure.py
```

The Python program is an external evidence harness. Neither `openc build` nor
its child backend invokes Python.

Status: **PASS**

### SH-6 — standalone self-hosted release

- The standalone compiler rebuilds itself and all supported runtime/library
  inputs.
- It passes the full conformance and maintained-program gates.
- The source, bootstrap seed, stage artifacts, normalized comparison, and
  checksums are recorded in the release evidence.

Two independently assembled archives are byte-identical at SHA-256
`6adf2254263cc11ae8a2f31ee883923021397942237ffb6fd64f0742a1b0eaac`.
After extraction, the package manifest validates 1,140 entries and the
packaged compiler runs from a foreign working directory. The packaged compiler
builds Stage 2 and Stage 2 builds Stage 3 with DMD, DUB, and Python unavailable
to those native builds.

The packaged compiler, Stage 2, and Stage 3 are byte-identical at SHA-256
`c2a26a1d286354f4e4b5ed2192e9008a5fffb2a667c4e4b9ba3f4a4afc76ed75`.
Their generated C is byte-identical at
`5851bde4caebb5cb4142966ce650db51ccf55983e1a3888e15ff0cd573c3a966`;
the normalized PE hash is
`cb8c75fc9e364608d61cdb062c58180f8899b99c7f1fb9396b9c8f2c1ff4b8e8`.
Native semantic/IR parity passes across 263 authored source fixtures, including
117 exact IR comparisons and 149 exact rejection outcomes. The extracted
package passes 268/268 conformance fixtures and all 4 maintained programs.

Reproduce the distribution and proof with
`release/build_standalone_windows.py` and
`release/verify_standalone_windows.py`; the exact final command and hashes are
recorded in `release/SH6_STANDALONE_EVIDENCE.md`.

## RC9 standalone successor

The published `v1.0.0-rc.9` package preserves the RC8 historical evidence and
refreshes the required Windows Hosted standalone gate to the 278-fixture
corpus. Two independent archives are byte-identical at SHA-256
`c215e8c5b0847657573204e19493f54c71d2c5ad8c3a95fe1523f21f1bc66344`.
The packaged compiler, Stage 2, and Stage 3 are byte-identical at SHA-256
`5924db13e20464d392dd563a086d35c95c61dafc6862ad7ba0fc767c0cdae4a6`.

The relocated package passes 240 flow/safety comparisons, 123 exact
canonical-IR comparisons, 153 exact semantic rejections, 278/278 conformance,
and all 4 maintained programs. Full hashes, commands, authorization, and
publication evidence are in `release/RC9_STANDALONE_EVIDENCE.md`.

## SH-7 — native conformance and tooling independence

The OpenC-authored compiler now exposes
`openc validate --manifest=MANIFEST --output=REPORT`. A deterministic generated
plan materializes the canonical 278-fixture manifest into 273 project records
plus command/record inputs consumable without a JSON parser in the runtime
gate. Native execution passes 278/278 with zero infrastructure failures,
including 35/35 built and executed runtime fixtures and 153/153 exact
diagnostic contracts.

The result distinguishes 81 expected rules observed directly in native
frontend/semantic diagnostics from 72 canonical fixture-contract rule matches
paired with a native rejection. This distinction is explicit in every result;
neither path uses the historical edition-compatibility fallback. The 93
historical compatibility matches remain disclosed in `CHANGELOG.md`.

The supported library mode is the six compiler-provided
`system.file`/`io`/`memory`/`path`/`process`/`text` modules backed by the
packaged Windows C runtime and native shim. Authored Native-provider `.p`
sources are included but remain outside this gate. The required standalone
verifier invokes native Stage 3 for conformance. The retained D seed is an
optional comparison oracle selected only with `--audit-seed`; Python
orchestrates evidence and is not a native build dependency.

Linux and freestanding are not SH-7 gates and remain optional future targets.
Complete commands and immutable hashes are recorded in
`release/SH7_NATIVE_CONFORMANCE_EVIDENCE.md`.

Status: **PASS**

## SH-8 — native developer and release workflow

The provenance-verified standalone OpenC compiler is now the default
compiler-under-test for Windows Hosted daily, full, maintained-program, demo,
benchmark, packaging, and relocated-release workflows. Its source fingerprint
must match the exact current 91-source compiler, native library, runtime, and
backend inputs.

Complete native conformance measures 35.489 seconds against a 50-second
budget. A byte-identical full self-rebuild measures 494.985 seconds against a
620-second budget. Time, peak private memory, and peak working set are enforced
by `WINDOWS_NATIVE_BUDGETS.json`.

Ordinary unchanged daily validation may reuse a report only when the compiler,
fixture tree, Windows runtime, native shim, and TinyCC fingerprint is exact.
The reference hit takes 0.001 seconds and executes zero fixtures. Full and
release workflows force all 278 fixtures. All 4 maintained programs and all 6
demos build and execute with the native compiler.

The retained D seed is absent from required execution and is available only
through the explicit `audit-seed` mode. Linux and freestanding are not SH-8
gates.

Complete commands and measurements are in
`release/SH8_NATIVE_WORKFLOW_EVIDENCE.md`.

Status: **PASS**

## SH-9 — native CLI and diagnostic usability

The OpenC-authored compiler now exposes public native `check`, `run`,
`version`, `target`, and `explain` commands. `check` composes the existing
native project, flow-safety, and semantic-IR stages, renders concise human
diagnostics, and optionally writes a stable `openc.check.v1` record containing
the underlying observation streams. `run` checks, builds with the packaged
C11/TinyCC backend, forwards arguments after `--`, executes, and returns the
program exit code without adding compiler progress to successful output.

All 466 active rules are explainable from the canonical packaged rule index.
The 93 historical diagnostic matches remain explicitly marked as
compatibility identities. The 12/12 CLI contract and all 6/6 demos through
public `openc run` pass. The direct demo gate also repaired a semantic false
positive where a parameter named `file` was mistaken for a missing
`system.file` import alias.

The compiler contains 92 canonical `.p` source units. Required daily, full,
and relocated release verification executes no retained D seed. Linux and
freestanding remain outside the required gate.

Complete commands and hashes are in
`release/SH9_NATIVE_CLI_EVIDENCE.md`.

Status: **PASS**

## SH-10 — native project workflow completeness

The OpenC-authored compiler now exposes deterministic `fmt --check` and
`fmt --write`, resolved project-context `info` views, and manifest or
direct-project `test`. The formatter validates syntax before mutation and
normalizes UTF-8, LF, four-space indentation, comments, and terminal newlines.
Inspection resolves normalized project, target, source/module, dependency,
limit, and type context without consulting ambient environment inputs.

Tests are discovered in name-sorted order, checked before execution, built to
isolated outputs, and record target, implementation, source hash, command,
stdout, diagnostics, and distinct language/assertion/infrastructure outcomes.
The requested jobs value is recorded; execution remains deliberately
name-sorted and deterministic. All 21 native contracts pass against relocated
Stage 3 using `openc.format.v1`, `openc.tool_context.v1`, and
`openc.test_result.v1`.

The compiler contains 94 canonical `.p` source units. Required daily, full,
and relocated release verification executes no retained D seed. Linux and
freestanding remain outside the required gate. Complete commands and hashes
are in `release/SH10_NATIVE_PROJECT_WORKFLOW_EVIDENCE.md`.

Status: **PASS**

## SH-11 — native language-service completeness

The OpenC-authored compiler now exposes `openc lsp --stdio` with JSON-RPC 2.0
`Content-Length` framing. The OpenC layer owns protocol parsing, lifecycle
state, deterministic serialization, full-document synchronization,
diagnostics, and formatting; the Windows Hosted runtime supplies only bounded
framed UTF-8 input/output transport.

Initialization advertises UTF-8 positions, full synchronization, and document
formatting. Opening or changing a document runs the native compiler frontend
and publishes stable rule IDs, severity, ranges, messages, and byte-span data.
Closing clears diagnostics. Formatting calls the SH-10 formatter and refuses
invalid or unopened source.

All 19 lifecycle, capability, diagnostic, formatting, error-state, exit,
framing, and deterministic-transcript contracts pass. Independent sessions
produce byte-identical `openc.lsp_transcript.v1` records at SHA-256
`78cd47ec56903c7ade4dc90fb3e1b8a0892ea71468ebe1fd7a185f83e32e5dff`.

The compiler contains 95 canonical `.p` source units. Required daily, full,
and relocated release verification executes no retained D seed. Linux and
freestanding remain outside the required gate. Complete commands and hashes
are in `release/SH11_NATIVE_LANGUAGE_SERVICE_EVIDENCE.md`.

Status: **PASS**

## SH-12 — native semantic language intelligence

The OpenC-authored server now owns a bounded synchronized project workspace
and a deterministic declaration-semantic index over its native token stream.
It publishes document symbols and typed hover, resolves definitions and
references across open project documents, returns complete name-sorted
completion, validates prepare-rename, and rejects keyword or
declaration-colliding rename operations.

All 23 semantic capability, multi-document, symbol, type, navigation,
completion, safe-rename, lifecycle, standalone-provenance, schema, and
open-order determinism contracts pass. Opposite document-open orders produce
byte-identical `openc.semantic_lsp_transcript.v1` records. Closing a document
immediately removes its declarations from synchronized project context, and
documents outside `initialize.rootUri` do not contribute symbols.

The compiler contains 96 canonical `.p` source units. Required daily, full,
and relocated release verification executes no retained D seed. Linux and
freestanding remain outside the required gate. Complete commands and hashes
are in `release/SH12_NATIVE_SEMANTIC_LANGUAGE_EVIDENCE.md`.

Status: **PASS**

## SH-13 — native throughput and implementation independence

The OpenC `.p` compiler is the sole canonical authored implementation. Native
builds, checks, conformance, CLI commands, project tooling, and language
services invoke neither D nor Python. The standalone package excludes D and
Python source, Python bytecode, and DUB manifests. A previous OpenC-native
binary remains as the optional bootstrap seed.

The public build command accepts `--timings=RECORD.json` and writes
`openc.native_build_timings.v1`. The closed 96-source rebuild measures 557.985
seconds versus the SH-12 780.621-second baseline, with byte-identical compiler
and generated-C closure. TinyCC accounts for 0.938 seconds; the dominant
548.172 seconds remains OpenC-owned lowering and C emission.

The vendored TinyCC backend is still a required, separately licensed
dependency. SH-13 therefore establishes D/Python implementation independence
but does not claim a first-party native-code backend or D/C-class compilation
speed. Both remain explicit future engineering work.

Status: **PASS**

## SH-14 through SH-18 — native substrate and Windows surface

SH-14 closes the former generated-C throughput/stability gate with five clean
builds, bounded small/incremental scaling, and 20 consecutive byte-identical
rebuilds. SH-15 passes 25/25 Windows x64 ABI, LLP64, typed encoder, relocation,
callback, variadic, and unwind checks. SH-16 passes 34/34 deterministic PE32+
and CRT-free runtime checks. SH-17 passes the real Win32 Metadata reader and
seven-module raw projection gate. SH-18 passes 27/27 checks across twelve
idiomatic UTF-8 Windows modules.

Status: **PASS**

## SH-19 — compiler-capable native backend and TinyCC exit

The normal public compiler now lowers the complete 116-source compiler project
directly to x64 machine code and writes its own PE32+ executable. Two closed
stages are byte-identical at SHA-256
`277e5ee71bc7f366cfb921c8525a42fe9228221b9955a5fa099326c55fb994c4`.
The gate passes 63/63 lowering/runtime probes, 6/6 memory guards, 278/278
conformance fixtures, 4/4 maintained programs, all CLI/project/LSP checks, and
20/20 relocated standalone-release checks.

The standalone compiler contains no C, C headers, TinyCC, D, or Python and
imports no Microsoft CRT. A trusted already-validated self-rebuild takes
10.378 seconds within the 256 MiB private and 64 MiB working-set ceilings.
Complete evidence is in
`release/SH19_COMPILER_CAPABLE_NATIVE_BACKEND_EVIDENCE.md`.

Status: **PASS**

## SH-20 — native public throughput convergence

The fully validating public self-build now has a 17.064-second five-run median
and an 11.352-second validation median. The pinned same-host optimized ISO C
and D references measure 22.732 and 17.504 seconds, so OpenC is faster than
both measured medians. All 20 chained public builds produce the identical
4,941,312-byte compiler at SHA-256
`b82b228989c915db04370ed9463ac722375c610bbc15c497830b1c39ed707de3`.
Conformance remains 278/278, maintained programs 4/4, and compiler memory stays
inside the 256 MiB private / 64 MiB working-set guards. See
`SH20_NATIVE_PUBLIC_THROUGHPUT_PLAN.md` and
`../../release/SH20_NATIVE_PUBLIC_THROUGHPUT_EVIDENCE.md`.

Status: **PASS**

## SH-21 — OpenC-native workflows and bootstrap boundary

Required Python build/test/release orchestration is the remaining independence
boundary. SH-21 moves those workflows into OpenC, isolates D/Python/C/TinyCC to
a separately named optional historical bootstrap/audit kit, and proves the
normal release using only a previous OpenC compiler plus canonical source. See
`SH21_OPENC_NATIVE_WORKFLOWS_PLAN.md`.

Tranche 4 passes from a 119-source fixed-point compiler: the OpenC-authored
workflow owns 10/10 full tasks, 278/278 conformance, 5/5
program checks, exact SHA-256 closure, and a 4/4 adversarial process guard. The
native supervisor assigns suspended children to a kill-on-close Windows Job,
enforces 256 MiB process/tree commit, polls a 64 MiB working-set ceiling, caps
output at 4 MiB, and applies a default five-minute timeout. The native
repository audit passes 365 required files, 39 pinned hashes, 278 paired
fixture identities, 466 active/covered rules, and 174 grammar/coverage pairs.
The native PE audit additionally passes all 16 PE32+, section, import,
relocation, TLS, x64 unwind, and CRT-absence checks across the exact closed
compiler images. The `out ptr`
output-address defect and hard-coded `openc.exe` self-location defect retain
their maintained regressions. LSP audits, benchmarking, and release/archive
ownership remain open; see `SH21_NATIVE_PE_AUDIT_TRANCHE4_EVIDENCE.md`.

Status: **ACTIVE**

## Post-SH-6 — native self-rebuild performance

The closed OpenC-native compiler rebuilds its complete 90-source compiler
project in 381.049 seconds on the recorded Windows host, down from 698.918
seconds. Peak working set is 11.37 MiB and peak private memory is 161.55 MiB,
reductions of at least 99.4% and 92.5% respectively from the last observed
pre-change values.

Stage 2 and Stage 3 are byte-identical at
`9c74209ddfc8c865ae9be66586c2b18d8318be6b01617b4d84db37c6232639dd`.
Generated C is equal at
`33a8bff3281b988925407a152430f65b37619cb58e91e0aa5d7adb5a53751d3d`,
and normalized PE is equal at
`bca85705c132a265d9e308f148eb83bc3eeb2d89e7f5ae9f0387404adf73989b`.
The exact semantic/IR, flow/safety, conformance, Python, and maintained-program
regressions pass. See `PERFORMANCE.md` for method and reproduction commands.

Status: **PASS**

## Required enabling libraries

SH-4 supplies the retained deterministic D bootstrap path. SH-5 supplies
deterministic C11 writing, Hosted process invocation, the shipped Windows
compiler/linker backend, build records, and DMD-independent closure. SH-6
packages these pieces into a relocatable distribution and verifies that
distribution against the compiler, runtime/library, conformance, and
maintained-program gates. SH-7 moves the required conformance execution into
that OpenC-native compiler and demotes the retained D seed to an optional audit
oracle. SH-8 makes the native compiler the default compiler-under-test and
enforces exact-cache and performance-budget policy. SH-9 supplies the public
native developer CLI and preserves machine diagnostic evidence beside its
human output. SH-10 supplies deterministic native formatting, project-context
inspection, and project test execution with stable records. SH-11 supplies the
native stdio language-service lifecycle, compiler diagnostics, SH-10 document
formatting, and deterministic transcript records. SH-12 supplies native
project symbols, typed navigation, deterministic completion, safe rename, and
open-order-independent project-semantic transcript records. SH-13 makes OpenC
the sole implementation authority, publishes native phase timings, tightens
the rebuild budget, and removes D/Python source from the standalone compiler.
SH-14 closes the former throughput/stability gate. SH-15 through SH-18 supply
the x64 ABI/encoder, direct PE32+ runtime, WinMD projection, and friendly
Windows modules. SH-19 makes that backend compiler-capable and removes
generated C, TinyCC, D, Python, the Microsoft CRT, assemblers, and external
linkers from the required compiler and standalone-release path. External
Python evidence orchestration remains until SH-21; it is not a compiler or
packaged-runtime dependency.

No gate advances from `PENDING` based only on authored source. Each gate names
an executable command and evidence result before it becomes `PASS`.
