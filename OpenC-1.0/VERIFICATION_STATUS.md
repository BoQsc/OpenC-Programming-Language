# OpenC 1.0.0-rc.9 verification status

Date: 2026-07-28
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

- 9 of 9 legacy D audit targets build and link in debug mode.
- 9 of 9 legacy D audit targets build and link in release mode.
- 8 of 8 authored D test commands pass.
- 29 of 29 Python source tests pass; bytecode checks pass.
- 278 of 278 conformance fixtures pass with zero infrastructure failures.
- All 35 runtime fixtures build and execute to their expected output/outcome.
- All 4 maintained programs check, build, and run to their authored contracts.
- All 281 pre-existing OpenC source files were migrated to `.p`. The expanded
  compiler-in-OpenC and SH-12 expansion brings the current tree to 395
  `.p` files,
  including 96 compiler source units. The migrated fixture corpus retains
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
- The immutable RC8 SH-6 record passes. Two independently assembled standalone
  archives are
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
- The RC8 packaged native compiler passes 117 exact canonical-IR comparisons and
  149 exact rejection outcomes across 263 authored fixtures. The extracted
  package passes its historical 268/268 conformance gate and builds and
  executes all 4 maintained programs. The published RC9 relocated package
  passes the expanded 278/278 corpus and all 4 maintained programs.
- The RC9 packaged compiler, Stage 2, and Stage 3 are byte-identical at
  `5924db13e20464d392dd563a086d35c95c61dafc6862ad7ba0fc767c0cdae4a6`.
  It passes 240 flow/safety comparisons, 123 exact canonical-IR comparisons,
  and 153 exact semantic rejections. Two standalone builds are byte-identical
  at `c215e8c5b0847657573204e19493f54c71d2c5ad8c3a95fe1523f21f1bc66344`.
- SH-7 native conformance passes. OpenC-authored `openc validate` executes all
  278 fixtures with zero failures and zero infrastructure failures. All 35
  runtime fixtures build and execute, and all 153 diagnostic contracts match;
  the report separates 81 directly observed native rules from 72 canonical
  fixture-contract matches. The required relocated-package gate invokes native
  Stage 3 and does not execute the retained D seed.
- SH-8 native developer and release workflow passes. The default
  compiler-under-test is the provenance-verified OpenC-native standalone
  compiler. Complete validation measures 35.489 seconds against a 50-second
  budget; the byte-identical self-rebuild measures 494.985 seconds against a
  620-second budget. An unchanged daily cache hit takes 0.001 seconds and
  executes zero fixtures. Full and release modes force fresh native
  validation. All 4 maintained programs and all 6 demos pass native build and
  execution, and the required workflow does not execute the retained D seed.
- SH-9 native CLI and diagnostic usability passes. The OpenC-authored compiler
  exposes public `check`, `run`, `version`, `target`, and `explain`; all 12
  command contracts pass. Human failures preserve stable native stage streams
  in `openc.check.v1`, all 466 active rules are explainable, the prior 93
  compatibility identities remain disclosed, all 6 demos execute through
  public `openc run`, and the required workflow does not execute the D seed.
- SH-10 native project workflow completeness passes. OpenC-authored
  `fmt --check`/`--write`, filtered `info` context views, and deterministic
  manifest/direct-project `test` execution pass all 21 native contracts.
  Stable format, context, and test-result records are verified against
  relocated Stage 3, including language/assertion failure classification,
  and the required workflow does not execute the D seed.
  Observed live-desktop validation ranges from 29.803 to 68.471 seconds and
  rebuild ranges from 574.050 to 744.926 seconds. Every validation passes
  278/278 and every completed rebuild is byte-identical. An authored SH-10
  variability review records 90/900-second elapsed ceilings while retaining
  the original memory ceilings.
- SH-11 native language-service completeness passes. OpenC-authored
  `openc lsp --stdio` implements JSON-RPC 2.0 `Content-Length` framing,
  initialization/capability negotiation, full-document open/change/close
  synchronization, shutdown/exit semantics, compiler rule-ID diagnostics, and
  SH-10 document formatting. All 19 native contracts pass. Independent
  sessions produce byte-identical `openc.lsp_transcript.v1` records at
  SHA-256
  `78cd47ec56903c7ade4dc90fb3e1b8a0892ea71468ebe1fd7a185f83e32e5dff`.
  The required workflow does not execute the retained D seed. The complete
  SH-11 workflow passes 12/12 tasks; fresh validation takes 39.664 seconds
  under its 90-second ceiling, and the byte-identical 95-source rebuild takes
  945.439 seconds under its reviewed 1,050-second ceiling. Peak private and
  working-set memory remain below the unchanged limits. Two independently
  assembled standalone archives are byte-identical at SHA-256
  `6c73a64de6c16d33e34b5e3162678e8d8cfb2f63cbc12f7d30323fd0c6ca29a0`;
  packaged compiler, Stage 2, and Stage 3 are byte-identical at
  `a0a53c463a157dc671a77de95c2f2e7aad8d82563a264e551e6af219ba8bb318`.
  Relocated Stage 3 passes SH-11 19/19, SH-10 21/21, SH-9 12/12, conformance
  278/278, runtime 35/35, diagnostic contracts 153/153, and maintained
  programs 4/4.
- SH-12 native semantic language intelligence passes. The OpenC-authored
  server synchronizes a bounded project workspace and provides document
  symbols, typed hover, cross-document definition and references, complete
  name-sorted completion, prepare-rename, and collision-checked safe rename.
  All 23 semantic contracts pass. Opposite document-open orders produce
  byte-identical `openc.semantic_lsp_transcript.v1` records at SHA-256
  `47467cb5d9cd6f0dcedcb3c94426bc10b480d05357f32d5c2adc3a061e39a454`.
  The same compiler passes the complete SH-11 19/19 regression contract and
  executes no retained D seed. The complete workflow passes 13/13 tasks;
  fresh native validation passes 278/278 in 28.872 seconds, and the
  byte-identical 96-source rebuild completes in 780.621 seconds. Peak private
  memory is 208,019,456 bytes and peak working set is 13,787,136 bytes, both
  within the unchanged SH-11 ceilings. Two independently assembled archives
  are byte-identical at SHA-256
  `038fc6a0e1566df93fed06cd806857df0b1894cd1ce82d01429daf66f60fc4f7`.
  Packaged compiler, relocated Stage 2, and relocated Stage 3 are
  byte-identical at
  `e5fd8b31cf5e2809d1a3ed564038dadf70f497cd05c357c7c02b5af2b13c9a76`;
  relocated Stage 3 passes SH-12 23/23 plus every retained SH-11/10/9,
  conformance, runtime, diagnostic, and maintained-program gate.
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
python -m unittest discover -s tests/python
python scripts/native_toolchain.py status
python scripts/windows_native_workflow.py daily
python scripts/windows_native_workflow.py full
python scripts/verify_sh10_project_workflow.py
python scripts/verify_sh11_lsp.py --force
python tests/run_maintained.py
python demos/run_all.py
python scripts/complete_conformance_coverage.py --check
python scripts/generate_native_conformance_plan.py --check
python compiler/selfhost/bootstrap.py
python compiler/selfhost/bootstrap_d_parity.py --stage1 build-output/selfhost-sh4/closure-final/openc-stage1.exe --output build-output/selfhost-sh4/parity-final
python compiler/selfhost/bootstrap_closure.py --output build-output/selfhost-sh4/closure-final
python compiler/selfhost/bootstrap_windows_closure.py
python compiler/selfhost/benchmark_windows_validate.py
python compiler/selfhost/benchmark_windows_rebuild.py
python release/windows_native_release.py --force
python scripts/validate_structure.py
python scripts/source_completeness.py
```

## Release conclusion

HD-012 is ratified, the declared platform gate passes, and independent external
review is a recommended post-release assurance activity rather than an initial
owner-certified release prerequisite. The candidate is `RELEASED` for its
declared Windows x86-64 Hosted scope as the published `v1.0.0-rc.9`
prerelease. SH-2A through SH-2D and full lexical/syntactic/project SH-2 are
executed self-hosting milestones. SH-3A declaration/symbol/type-table and
SH-3B name/constant/overload parity, SH-3C flow/safety parity, and SH-3D exact
semantic-outcome/canonical-IR parity also pass, completing SH-3. SH-4 bootstrap
closure passes through the retained D bootstrap route. SH-5 also passes: the
native OpenC compiler uses its C11 backend and shipped TinyCC to build the next
native compiler with no DMD, DUB, or Python available to the build. SH-6
extends that result to a deterministic, relocatable standalone distribution
and passes the full packaged compiler, semantic/IR, conformance, and maintained
program gates. SH-7 moves the required 278-fixture conformance execution into
the OpenC-authored native compiler and removes the D seed from the required
gate. SH-8 makes the native compiler the default Windows compiler-under-test,
adds validation/rebuild regression budgets, and removes redundant unchanged
daily corpus execution. SH-9 adds the public developer CLI and human/machine
diagnostic surface. SH-10 adds native formatting, project-context inspection,
and deterministic project testing. SH-11 adds the native language-service
lifecycle, synchronized diagnostics, formatting, and deterministic protocol
transcripts. SH-12 adds native project symbols, typed navigation,
deterministic completion, safe rename, and open-order-independent semantic
transcripts. SH-13 adds native build-phase measurements and indexed lowering,
preserves byte-identical closure, establishes OpenC `.p` as the sole canonical
compiler authority, and excludes D/Python source and DUB manifests from the
standalone compiler. Self-hosting SH-0 through SH-13 is complete for the
declared Windows x86-64 Hosted scope.

The immutable RC8 standalone record remains at 268 fixtures. RC9 packages and
executes the current 278-fixture corpus, reaches byte-identical native closure,
and publishes the verified artifact set. SH-13 is the verified post-RC9
mainline successor. The next engineering milestone is SH-14 native editor
integration and language-service resilience: a first-party editor client,
incremental/versioned synchronization, cancellation/workspace lifecycle, and
bounded stress. Linux and freestanding remain optional future targets.
