# OpenC roadmap

The Windows x86-64 Hosted standalone self-hosted release candidate is
owner-authorized, tagged, and published as `v1.0.0-rc.9`. Its complete
13-artifact set plus release record is reproducible, verified, and available
as 14 GitHub release assets. Linux, freestanding, Native, and standalone
Native-provider verification remain optional future target work.

## Completed self-hosting path

SH-0 through SH-12 pass. The deterministic standalone package is relocatable,
rebuilds the OpenC-native compiler through byte-identical Stage 2 and Stage 3,
validates its internal manifest, passes all 278 current conformance fixtures,
and builds and executes all 4 maintained programs. The immutable RC8 baseline
is recorded in `release/SH6_STANDALONE_EVIDENCE.md`; the published RC9 refresh
is recorded in `release/RC9_STANDALONE_EVIDENCE.md`.

SH-4 is complete. SH-4A matches all 28 generated D files across the canonical
compiler and A/B/C projects byte for byte. SH-4B has Stage 1 invoke the
configured D compiler and build Stage 2 from the canonical `.p` compiler.
SH-4C has Stage 2 build Stage 3 and proves equal generated source, lexer
behavior, canonical IR, and normalized Windows PE artifacts. The compiler is
self-hosted through the retained bootstrap D backend.

SH-5 is complete. The compiler emits deterministic C11 and uses the shipped
TinyCC 0.9.27 Win64 backend. With DMD, DUB, and Python hidden from the build
environment, native Stage 2 builds native Stage 3 through `openc build`.
Generated C, raw Windows executables, lexer behavior, and canonical IR reach
closure; a compiled smoke program executes successfully.

SH-6 is complete. Two independently assembled archives are byte-identical.
The extracted compiler locates its runtime and backend relative to its own
executable, rebuilds from a foreign working directory, and reaches exact
packaged/Stage-2/Stage-3 executable closure. The supported package mode is
Windows x86-64 Hosted with the six compiler-provided system modules.

SH-7 is complete. The OpenC-authored compiler exposes native `openc validate`
and executes the complete 278-fixture plan: 278 pass, all 35 runtime fixtures
build and execute, all 153 diagnostic contracts match, and infrastructure
failures are zero. The required relocated-package gate calls native Stage 3;
the retained D seed is packaged only as an optional comparison oracle.

SH-8 is complete. The provenance-verified OpenC-native compiler is the default
Windows compiler-under-test. Complete validation and byte-identical
self-rebuild paths have enforced time/memory budgets; unchanged daily inputs
reuse exact conformance evidence without executing fixtures, while full and
release workflows force all 278 fixtures. The retained D seed remains a
separate optional audit.

SH-9 is complete. The OpenC-authored public CLI exposes `check`, `run`,
`version`, `target`, and `explain`. Human diagnostics retain stable machine
observation streams in `openc.check.v1`; all 466 active rules are explainable,
the 93 historical compatibility identities remain disclosed, and all six
demos execute directly through public `openc run`.

SH-10 is complete. The OpenC-authored compiler exposes deterministic
`fmt --check` and `fmt --write`, resolved project-context `info` views, and
name-sorted manifest/direct-project `test` execution. Stable
`openc.format.v1`, `openc.tool_context.v1`, and `openc.test_result.v1`
records are enforced by the relocated standalone release gate.

SH-11 is complete. The OpenC-authored compiler exposes `openc lsp --stdio`
with JSON-RPC 2.0 `Content-Length` framing, initialization/capability and
shutdown/exit lifecycle, full-document synchronization, compiler rule-ID
diagnostics, and SH-10 document formatting. All 19 native contracts pass,
including byte-identical independent transcripts and relocated standalone
verification.

SH-12 is complete. The native server synchronizes a bounded project document
set and publishes document symbols, typed hover, definition and reference
navigation, complete name-sorted completion, prepare-rename, and
collision-checked project rename. All 23 semantic contracts pass, including
opposite document-open orders producing byte-identical project-semantic
transcripts from the relocated standalone package.

SH-2A through SH-2D and full SH-2 pass. Lexer evidence covers 288 canonical
`.p` sources plus 16 probes (304/304). Parser evidence covers those canonical
sources plus 15 parser probes (303/303), all 52 parser-produced syntax kinds,
and all 15 reachable parser/recovery rules. Project/module evidence covers 7
checked-in projects plus 15 focused probes (22/22), including all 3 observed
composition diagnostic rules.
SH-3A evidence covers the canonical compiler project plus 16 focused semantic
projects (17/17), with exact declaration, symbol, type-table, and duplicate
diagnostic parity.
SH-3B evidence covers one maintained canonical project plus 9 focused
projects (10/10), with 32 exact bindings, 10 constant results, 4 overload
selections, and 4 exact diagnostic rules.
SH-3C flow/safety evidence covers 3 maintained projects and 263 authored
source fixtures: 232 semantic comparisons plus 34 SH-2 frontend cases, with
313 functions, 733 blocks, 464 edges, 34 cleanups, and 19 observed rules.
SH-3D matches all 149 rejection outcomes and exact canonical IR for 117
accepted programs: 183 functions, 275 blocks, 1,489 instructions, and all 33
reachable opcodes. Full SH-3 passes.
SH-4 closure produces 7 stable generated modules and identical normalized
Stage-2/Stage-3 PE hash
`e1776ad8492ea4181dff91885ea45d371f1288abbdad8423cb2e4a16ef6c9e65`.

## Completed post-SH-6 performance milestone

The native compiler now completes a full compiler self-rebuild in 381.049
seconds instead of 698.918 seconds on the recorded Windows host, a 45.5%
reduction. Peak working set is 11.37 MiB instead of an observed lower bound of
1,947.0 MiB, and peak private memory is 161.55 MiB instead of an observed lower
bound of 2,144.9 MiB.

Optimized Stage 2 and Stage 3 remain byte-identical, and generated C, normalized
PE, lexer behavior, canonical IR, semantic/flow parity, 268/268 conformance,
and all 4 maintained-program gates pass. Exact measurements and reproduction
commands are in `compiler/selfhost/PERFORMANCE.md`.

## Completed conformance-evidence granularity milestone

All 466 active Core rules now name at least one executed dedicated fixture,
and all 174 grammar productions now name both an accepting fixture and a
rejecting fixture. The Windows x86-64 Hosted reference run passes all 278
fixtures with zero failures and zero infrastructure failures.

The milestone also corrected initial UTF-8 BOM handling in the D, Python, and
OpenC-owned source loaders. Native Stage 2 and Stage 3 remain byte-identical;
their generated C, normalized PE artifacts, lexer observations, and canonical
IR reach closure. Exact evidence and reproduction commands are in
`conformance/COVERAGE_MILESTONE_EVIDENCE.md`.

## What comes next

1. **SH-8 native developer and release workflow hardening — complete**
   - the OpenC-native compiler is the default compiler-under-test for Windows
     Hosted development and release gates;
   - validation and self-rebuild paths have enforced elapsed-time and memory
     budgets;
   - exact-input daily caching removes unchanged 278-fixture re-execution,
     while full and release gates force fresh evidence;
   - the optional D oracle is separately invocable and absent from required
     daily, full, and release execution.
2. **SH-9 native CLI and diagnostic usability — complete**
   - public native `openc check` and `openc run` pass;
   - concise human diagnostics preserve stable machine records;
   - version, target, and rule-explanation commands pass;
   - all six demos execute directly through the public native CLI.
3. **SH-10 native project workflow completeness — complete**
   - native `openc fmt --check` and `openc fmt --write` pass;
   - native `openc info` project, target, and dependency inspection passes;
   - native `openc test` deterministic discovery and exit records pass;
   - all commands pass relocated standalone release verification.
4. **SH-11 native language-service completeness — complete**
   - native `openc lsp --stdio` lifecycle and capability negotiation pass;
   - synchronized document diagnostics use stable compiler rule IDs;
   - document formatting routes through the SH-10 native formatter;
   - deterministic protocol transcripts pass from the relocated standalone
     package.
5. **SH-12 native semantic language intelligence — complete**
   - publish native document symbols and typed hover information;
   - add definition and reference navigation over synchronized project
     context;
   - add deterministic completion and validated safe rename;
   - verify multi-document/project-aware semantic transcripts from the
     relocated standalone package.
6. **SH-13 native editor integration and language-service resilience — next**
   - ship a first-party editor client that launches the packaged native server;
   - add incremental, monotonic-version document synchronization;
   - add cancellation, workspace lifecycle, and bounded resource handling;
   - verify editor launch plus protocol stress from the relocated standalone
     package.
7. **Seek independent review**
   - invite independent grammar, semantic, security, and usability reviews;
     this is additional assurance, not a Windows Hosted 1.0 release blocker.

Linux, freestanding, Native, and Native-provider target records remain optional
future work and begin only when those targets become active priorities.

Future language changes continue through the proposal and accepted-change
process. Provisional concurrency remains outside the Core 1.0 blocking path.
