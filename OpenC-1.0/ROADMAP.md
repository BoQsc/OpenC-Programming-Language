# OpenC roadmap

The Windows x86-64 Hosted standalone self-hosted release candidate is
owner-authorized, tagged, and published as `v1.0.0-rc.9`. Its complete
13-artifact set plus release record is reproducible, verified, and available
as 14 GitHub release assets. Linux, freestanding, Native, and standalone
Native-provider verification remain optional future target work.

## Critical-path priority

SH-14 closed the compiler-throughput gap: the five-run OpenC-native clean
median is 4.137 seconds versus 12.731 seconds for the pinned same-host D
reference, with small/incremental, proportional-scaling, bounded-memory,
deterministic closure, and 20-run stability gates all passing. Those limits
remain enforced as regression budgets.

SH-16 now passes its 34/34 PE32+, imports, relocation, TLS, unwind, CRT-free
runtime, execution, deterministic-closure, and performance-regression checks.
It produces the first complete OpenC-owned Windows executable without C
headers, a Microsoft CRT, an assembler, or an external linker. SH-17's
purpose-built Win32 Metadata reader and raw projection is the active
engineering priority. Windows concepts remain outside Core, and
Linux/freestanding remain nonblocking targets. The architecture is in
`compiler/design/WINDOWS_NATIVE_INDEPENDENCE.md`.

## Completed self-hosting path

SH-0 through SH-16 pass. The deterministic standalone package is relocatable,
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

SH-13 is complete. Native build phase records attribute 98.2% of the closed
compiler rebuild to OpenC-owned lowering/C emission and only 0.2% to TinyCC.
Indexed syntax, expression, declaration, and symbol lookups reduce the
96-source closed rebuild from 780.621 to 557.985 seconds while preserving
byte-identical generated C and compiler executables. OpenC `.p` is the sole
canonical compiler authority; standalone archives contain no D/Python source,
Python bytecode, or DUB manifests. TinyCC remains an explicit backend
dependency. The SH-13 result was the profiling and algorithmic foundation for
SH-14, not permission to treat multi-minute builds as done.

SH-14 is complete. Deterministic parallel source lowering, byte-addressed
compiler slicing, native hot paths, bounded memory, and direct resolution-owner
indexing reduce the five-run clean median to 4.137 seconds, with a 4.854-second
maximum and a 0.325 ratio to the pinned D median. Small and exact-dependency
one-source builds both reach 0.158-second medians; the worst scaling doubling
is 2.112x; 20 chained closures retain identical compiler/generated-source
hashes; conformance remains 278/278 and maintained programs remain 4/4.

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
6. **SH-13 native compiler throughput and implementation independence — complete**
   - keep canonical compiler authority exclusively in OpenC `.p` source;
   - publish native phase timings and enforce materially lower rebuild budgets;
   - replace repeated semantic/IR scans with indexed lookups while preserving
     byte-identical self-host closure;
   - exclude D and Python source from the standalone compiler distribution;
   - keep Python only as an external release-evidence orchestrator, never a
     runtime or compiler requirement;
   - measure the TinyCC phase separately and disclose it as the remaining
     temporary native-code backend dependency.
7. **SH-14 compiler throughput convergence and stability — complete**
   - replace the preliminary comparison with a reproducible same-host OpenC,
     D-reference, and generated-C benchmark suite;
   - reduce the five-run clean self-rebuild median to at most 30 seconds and
     every clean run to at most 45 seconds;
   - require the clean median to be no more than 1.25x the pinned D-reference
     build, small builds to complete within 250 ms median, and one-source
     rebuilds within 1 second median;
   - remove remaining superlinear scans, repeated parsing/validation, transient
     allocation, copying, and generated-compiler execution penalties;
   - enforce near-linear input scaling, exact dependency fingerprints, full
     conformance, byte-identical closure, memory ceilings, and 20 consecutive
     stable clean rebuilds;
   - freeze typed Core IR, target, runtime, ownership, and build-record
     contracts before first-party native backend implementation begins.
8. **SH-15 Windows x64 ABI and machine-code substrate — complete**
   - implement the Microsoft x64 register/stack convention, LLP64 layout,
     aggregates, callbacks, variadics, nonvolatile registers, and unwind rules;
   - add a typed x64 instruction encoder, register/stack assignment, and
     relocations without requiring an external assembler;
   - keep Windows names and types in libraries, not the Core language.
9. **SH-16 minimal PE32+ executable and CRT-free OpenC runtime — complete**
   - emit a complete deterministic PE32+ image, imports, relocations, sections,
     subsystem fields, and x64 `.pdata`/`.xdata` directly;
   - own entry, initialization, command line, environment, exit, allocation,
     cleanup, TLS contract, and panic reporting without the Microsoft CRT;
   - pass the first independent executable proof: UTF-8 output, memory, and
     files using only documented Windows system DLLs, with no C headers,
     compiler, runtime, assembler, or linker.
10. **SH-17 OpenC Win32 Metadata reader and raw projection — complete**
    - read the required ECMA-335 metadata tables and custom attributes from a
      pinned `Windows.Win32.winmd` using purpose-built OpenC code;
    - generate deterministic `windows.raw.*` `.p` modules for exact functions,
      constants, types, layouts, cleanup contracts, and documentation IDs;
    - never require the compiler to parse Windows C headers or regenerate
      bindings during ordinary builds.
11. **SH-18 idiomatic Windows modules — complete**
    - layer `windows.*` over `windows.raw.*` with typed handles, ownership and
      exact cleanup, slices, optionals, OpenC errors, and safer defaults;
    - keep OpenC text UTF-8 and convert to UTF-16 for Unicode `W` APIs at the
      Windows boundary;
    - cover files, memory, processes, threads, console, windowing, graphics,
      resources, networking, registry, and shell incrementally.
12. **SH-19 compiler-capable first-party backend and TinyCC exit — complete**
    - the 116-source OpenC compiler reaches a byte-identical 4,712,960-byte
      fixed point through direct x64/PE32+ emission;
    - the relocated package passes 278/278 conformance, 4/4 maintained
      programs, public CLI/project/LSP gates, and imports only `KERNEL32.dll`;
    - the default `openc build` and packaged compiler require no generated C,
      TinyCC, C headers/runtime, D, Python, assembler, or external linker;
    - allocation, validation, child-output, and process guards remain active;
      see [SH-19 evidence](release/SH19_COMPILER_CAPABLE_NATIVE_BACKEND_EVIDENCE.md).
13. **SH-20 native public throughput convergence — complete**
    - the fully validating public self-build has a 17.064-second five-run
      median and 11.352-second validation median without weakening checks;
    - OpenC beats the same-host 22.732-second optimized ISO C and 17.504-second
      D reference medians, while 20/20 builds close byte-identically;
    - 278/278 conformance, 4/4 maintained programs, and the 256 MiB private /
      64 MiB working-set guards remain green; see
      [SH-20 evidence](release/SH20_NATIVE_PUBLIC_THROUGHPUT_EVIDENCE.md).
14. **SH-21 OpenC-native build/test/release and bootstrap boundary — complete**
    - required workflow, benchmark, audit, deterministic packaging, and
      relocated release verification are OpenC-native;
    - the 13/13 full workflow passes 278/278 conformance, 5/5 programs,
      20/20 exact rebuilds, 380-file repository audit, 16/16 PE audit,
      42/42 LSP audit, and 29/29 residual contract audit;
    - standalone/source ZIP pairs are byte-identical and the standalone omits
      C, D, Python, TinyCC, CRTs, assemblers, and external linkers; see
      [SH-21 completion evidence](compiler/selfhost/SH21_COMPLETION_EVIDENCE.md).
15. **SH-22 PE/COFF ecosystem completeness — active next**
    - add COFF objects, DLL imports/exports, OpenC DLLs, static/import
      libraries, resources, manifests, console/GUI subsystems, and secure
      run-time linking;
    - support optional C-ABI libraries in both directions without making C an
      OpenC language or toolchain dependency;
    - add a standalone assembler only if evidence shows the shared x64 encoder
      and runtime/intrinsic facilities are insufficient.
16. **SH-23 optional COM and WinRT projections**
    - add GUIDs, vtables, `IUnknown`, `QueryInterface`, reference counting,
      `HRESULT`, apartment initialization, metadata projection, and ABI tests;
    - keep COM and WinRT outside the Core language and earlier backend gates.
17. **SH-24 native editor integration and language-service resilience — deferred**
    - ship a first-party editor client that launches the packaged native server;
    - add incremental monotonic-version synchronization, cancellation,
      workspace lifecycle, bounded resource handling, and protocol stress;
    - begin only after throughput and required Windows independence milestones.
18. **Seek independent review**
   - invite independent grammar, semantic, security, and usability reviews;
     this is additional assurance, not a Windows Hosted 1.0 release blocker.

ARM64 begins only after the Windows x64 backend and independent release loop
are stable. Linux, freestanding, Native, and Native-provider target records
remain optional future work and begin only when those targets become active
priorities.

Future language changes continue through the proposal and accepted-change
process. Provisional concurrency remains outside the Core 1.0 blocking path.
