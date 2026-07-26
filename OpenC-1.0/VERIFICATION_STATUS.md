# OpenC 1.0.0-rc.8 verification status

Date: 2026-07-26
Host: Windows 10.0.19045, x86-64

## Verified scope

This evidence supports the owner-certified Windows x86-64 Hosted reference
implementation. Linux, freestanding, Native, script/live, and Concurrent work
are outside the supported 1.0 scope.

## Toolchain

- DMD 2.112.0
- DUB 1.41.0
- DMD-bundled `lld-link`
- Python 3.13.7
- Shipped TinyCC 0.9.27 Win64 (`tcc.exe` SHA-256
  `e9cb3e89e20a9efead83cc9e6b100314275634c2f705056da71f424ea9b0cdf0`)

## Executed evidence

- 9 of 9 canonical D targets build and link in debug mode.
- 9 of 9 canonical D targets build and link in release mode.
- 8 of 8 authored D test commands pass.
- 4 of 4 Python bootstrap tests pass; bytecode and CLI smoke checks pass.
- 278 of 278 conformance fixtures pass with zero infrastructure failures.
- All 35 runtime fixtures build and execute to their expected output/outcome.
- All 4 maintained programs check, build, and run to their authored contracts.
- All 281 pre-existing OpenC source files were migrated to `.p`. The expanded
  compiler-in-OpenC and conformance expansion brings the current tree to 383
  `.p` files,
  including 90 compiler source units. The migrated fixture corpus retains
  278/278 passes and zero infrastructure failures. SH-2 records the exact
  288-file corpus used for that milestone; SH-4A covers the complete current
  compiler project through byte-exact generated output.
- The compiler-in-OpenC frontend builds through stage 0 and passes SH-2A exact
  lexer parity plus SH-2B owned single-pass lexer state: 288 canonical `.p`
  sources plus 16 focused probes, 304/304. Outcomes, token kinds, byte spans,
  line/byte-column positions, diagnostic rules, source-encoding rejection,
  and totals match exactly; all 12 source/lexical diagnostic rules are
  observed.
- SH-2C exact parser parity passes on all 288 canonical sources plus 15 focused
  parser probes, 303/303. Syntax-node creation order, all 52 parser-produced
  kinds and final byte spans, 15 reachable parser/recovery rules, diagnostic
  positions, node totals, and error totals match exactly.
- SH-2D exact project/module parity passes on all 7 checked-in projects plus
  15 focused probes, 22/22. Sorted modules, ordered source units, resolved
  paths, imports, per-source parsing, missing imports, ambiguous short
  qualifiers, direct cycles, and totals match exactly. Together SH-2A through
  SH-2D promote full lexical/syntactic/project frontend SH-2.
- SH-3A exact declaration, symbol, and canonical type-table parity passes on
  the canonical compiler project plus 16 focused semantic projects, 17/17.
  The compared observations cover declaration/member order, visibility,
  parameter modes, ownership/resource state, canonical type IDs and
  constructors, source spans, and duplicate-declaration diagnostics.
- SH-3B exact name, constant, and overload resolution parity passes on the
  maintained computation project plus 9 focused projects, 10/10. The compared
  observations include 32 exact bindings, 10 constant results, 4 selected
  calls, and exact unknown-name, no-match, ambiguity, and divide-by-zero rules.
- SH-3C exact flow/safety parity covers 3 maintained projects and 263 authored
  source fixtures: 232 semantic comparisons plus 34 SH-2 frontend cases, with
  313 functions, 733 blocks, 464 edges, 34 cleanups, and 19 observed rules.
- SH-3D matches all 149 frontend/semantic rejection outcomes and exact
  canonical JSON IR for 117 accepted programs, covering 183 functions, 275
  blocks, 1,489 instructions, and all 33 reachable opcodes. Full SH-3 passes.
- SH-4A byte-exact D-backend parity passes across the canonical compiler and
  A/B/C projects: 4 project comparisons and 28 of 28 generated files match.
- SH-4B passes: Stage 1 invokes the configured DMD toolchain, writes a build
  record, and builds the standalone Stage-2 compiler from the canonical `.p`
  compiler project.
- SH-4C and full SH-4 pass: Stage 2 builds Stage 3; their 7 generated modules,
  lexer behavior, canonical IR, and normalized PE artifacts are equal. The
  normalized Stage-2/Stage-3 hash is
  `e1776ad8492ea4181dff91885ea45d371f1288abbdad8423cb2e4a16ef6c9e65`.
- SH-5 passes: OpenC emits deterministic single-file C11 and invokes the
  shipped TinyCC 0.9.27 Win64 compiler/linker. The public `openc build`
  command succeeds with DMD, DUB, and Python hidden from the child PATH.
- Native Stage 2 builds native Stage 3. Their generated C is byte-identical
  with SHA-256
  `ae3c4929bf874ae8c23416a9966c26788a8a294a53853628880fef848a28bbec`,
  and their raw Windows executables are byte-identical with SHA-256
  `b42892ed15f944049eefd6b91206dd283de5ce38fef97d6667a1131dc955be5f`.
  Lexer behavior, canonical IR, and public-build execution smoke checks pass.
- SH-6 passes. Two independently assembled standalone archives are
  byte-identical at SHA-256
  `6adf2254263cc11ae8a2f31ee883923021397942237ffb6fd64f0742a1b0eaac`.
  The extracted 1,140-entry package manifest validates, and public
  `openc build` works from a foreign working directory using paths relative to
  the packaged compiler.
- The packaged compiler builds Stage 2 and Stage 2 builds Stage 3 with DMD,
  DUB, and Python absent from the native build environment. The packaged
  compiler and both stages are byte-identical at
  `c2a26a1d286354f4e4b5ed2192e9008a5fffb2a667c4e4b9ba3f4a4afc76ed75`;
  generated C and normalized PE hashes are recorded in the SH-6 evidence.
- The packaged native compiler passes 117 exact canonical-IR comparisons and
  149 exact rejection outcomes across 263 authored fixtures. The extracted
  package passes 268/268 conformance and builds and executes all 4 maintained
  programs.
- The post-SH-6 native performance milestone passes. A closed Stage 3 rebuilds
  the compiler in 381.049 seconds versus 698.918 seconds before the changes,
  with 11.37 MiB peak working set and 161.55 MiB peak private memory. Optimized
  Stage 2 and Stage 3 are byte-identical, and exact native semantic/IR,
  flow/safety, and 4/4 maintained-program regressions pass. The retained seed
  passes 268/268 conformance and the informative Python suite passes 4/4.
  Public `openc build` also passes from a foreign working directory in a
  copied standalone layout. Full evidence is in
  `compiler/selfhost/PERFORMANCE.md`.
- The conformance-evidence granularity milestone passes. All 466 active Core
  rules name executed dedicated fixtures, all 174 grammar productions name
  executed accepting/rejecting fixture pairs, and the explicit authoring queue
  is empty. Native Stage 2 and Stage 3 remain byte-identical after the source
  changes; exact closure hashes and commands are in
  `conformance/COVERAGE_MILESTONE_EVIDENCE.md`.
- Structure, source-completeness, manifest, and archive verification pass.

Fixture execution now distinguishes normative rules from implementation
diagnostic codes. All rejection diagnostic expectations match exactly and the
historical edition-compatibility fallback is removed (zero compatibility
matches in the current run). The 93 matches previously accepted through that
fallback remain explicitly disclosed in the development changelog. Imported
fixtures retain their origin records while targeting OpenC Core 1.0 Current.

Dedicated executable fixtures name all 466 active Core rules, and the explicit
fixture-authoring queue has zero remaining required rules. The 174-production
grammar is structurally validated, and every production names an executed
accepting fixture and an executed rejecting fixture.

## Reproduction commands

```text
python build/build_all.py --build debug --tools --compiler dmd
python build/build_all.py --build release --tools --compiler dmd
python tests/run_all.py
PYTHONPATH=compiler/bootstrap/python python -m unittest discover -s tests/python
compiler/openc validate --manifest=conformance/fixtures/MANIFEST.json
python tests/run_maintained.py
python scripts/complete_conformance_coverage.py --check
python compiler/selfhost/bootstrap.py
python compiler/selfhost/bootstrap_d_parity.py --stage1 build-output/selfhost-sh4/closure-final/openc-stage1.exe --output build-output/selfhost-sh4/parity-final
python compiler/selfhost/bootstrap_closure.py --output build-output/selfhost-sh4/closure-final
python compiler/selfhost/bootstrap_windows_closure.py
python compiler/selfhost/benchmark_windows_rebuild.py --compiler build-output/selfhost-performance/closure/stage3/openc.exe
python release/verify_standalone_windows.py --archive build-output/release/OpenC-1.0.0-rc.8-windows-x86_64-standalone-a.zip --comparison-archive build-output/release/OpenC-1.0.0-rc.8-windows-x86_64-standalone-b.zip --output build-output/selfhost-sh6/final --force
python scripts/validate_structure.py
python scripts/source_completeness.py
```

## Release conclusion

HD-012 is ratified, the declared platform gate passes, and independent external
review is a recommended post-release assurance activity rather than an initial
owner-certified release prerequisite. The candidate is `RELEASE_READY` for its
declared Windows x86-64 Hosted scope. It remains unpublished and therefore is
not `RELEASED`. SH-2A through SH-2D and full lexical/syntactic/project SH-2 are
executed self-hosting milestones. SH-3A declaration/symbol/type-table and
SH-3B name/constant/overload parity, SH-3C flow/safety parity, and SH-3D exact
semantic-outcome/canonical-IR parity also pass, completing SH-3. SH-4 bootstrap
closure passes through the retained D bootstrap route. SH-5 also passes: the
native OpenC compiler uses its C11 backend and shipped TinyCC to build the next
native compiler with no DMD, DUB, or Python available to the build. SH-6
extends that result to a deterministic, relocatable standalone distribution
and passes the full packaged compiler, semantic/IR, conformance, and maintained
program gates. Self-hosting SH-0 through SH-6 is complete for the declared
Windows x86-64 Hosted scope.

The current coverage milestone is post-tag mainline evidence. The immutable
RC8 standalone record remains at 268 fixtures; an RC9 standalone refresh that
packages and executes the current 278-fixture corpus is the next engineering
milestone.
