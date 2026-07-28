# OpenC roadmap

The Windows x86-64 Hosted standalone self-hosted release candidate is
owner-authorized, tagged, and published as `v1.0.0-rc.9`. Its complete
13-artifact set plus release record is reproducible, verified, and available
as 14 GitHub release assets. Linux, freestanding, Native, and standalone
Native-provider verification remain optional future target work.

## Completed self-hosting path

SH-0 through SH-8 pass. The deterministic standalone package is relocatable,
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
2. **SH-9 native CLI and diagnostic usability — next engineering milestone**
   - add public native `openc check` and `openc run`;
   - provide concise human diagnostics beside stable machine records;
   - add version, target, and rule-explanation commands;
   - make the demo projects directly usable through the public native CLI.
3. **Seek independent review**
   - invite independent grammar, semantic, security, and usability reviews;
     this is additional assurance, not a Windows Hosted 1.0 release blocker.

Linux, freestanding, Native, and Native-provider target records remain optional
future work and begin only when those targets become active priorities.

Future language changes continue through the proposal and accepted-change
process. Provisional concurrency remains outside the Core 1.0 blocking path.
