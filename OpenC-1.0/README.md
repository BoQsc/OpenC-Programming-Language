# OpenC

OpenC is a new open systems language: C-shaped, not C-compatible; safe by
default; explicit about unsafe memory; and designed around referenceable rules,
strong diagnostics, deterministic tooling, and executable conformance.

This directory is the single canonical development tree for the 1.0 release
candidate.

Canonical OpenC source files use `.p`, derived from the word "open" in OpenC.
The extension is an official tooling convention; explicit source paths and
logical module identity remain extension-independent.

## 1.0 release scope

The supported reference-implementation target is Windows x86-64 Hosted. Linux,
freestanding, Native, script/live, and Concurrent sources remain available as
experimental future work and do not block or enlarge the 1.0 claim. See
`release/RELEASE_SCOPE_1.0.md`.

## Verified state

- the canonical compiler is authored in OpenC `.p`; the 9 legacy D targets
  and Python bootstrap tests remain optional historical audit material;
- the OpenC-authored `openc validate` passes all 278 fixtures, including 35
  runtime fixtures, without executing the retained D audit seed;
- all 4 maintained programs check, build, and run successfully;
- all 281 migrated OpenC library, program, and fixture sources use `.p`; with
  the expanded compiler-in-OpenC and conformance source, the current tree has
  437 `.p` files;
- the compiler-in-OpenC frontend builds and passes SH-2A/SH-2B exact owned
  lexer parity on 288 canonical `.p` sources plus 16 probes (304/304), SH-2C
  exact parser parity on those sources plus 15 parser probes (303/303), and
  SH-2D exact project/module parity on 7 checked-in projects plus 15 probes
  (22/22); full SH-2 passes, and SH-3A declaration/symbol/type-table parity
  passes on the canonical compiler project plus 16 focused projects (17/17),
  SH-3B name/constant/overload parity passes on one maintained canonical
  project plus 9 probes (10/10), SH-3C exact flow/safety parity covers 232
  semantic comparisons, and SH-3D matches 149 rejection outcomes plus exact
  canonical IR for 117 accepted programs and all 33 reachable opcodes at the
  original SH-3 gate; the current RC9 corpus passes 240 flow/safety
  comparisons, 123 canonical-IR comparisons, and 153 exact semantic
  rejections; full
  SH-3 passes; SH-4A matches 28 generated D files across 4 projects byte for
  byte, SH-4B has Stage 1 build Stage 2, and SH-4C proves Stage-2/Stage-3
  generated-source, lexer, canonical-IR, and normalized-PE closure; full SH-4
  passes; SH-5 adds deterministic C11 emission and the shipped TinyCC 0.9.27
  Win64 backend, proves byte-exact native compiler source/executable closure
  with DMD, DUB, and Python hidden, and exposes public `openc build`; SH-6
  packages that compiler and complete source in a relocatable deterministic
  archive; RC9 proves packaged Stage-2/Stage-3 byte closure, passes 278/278
  conformance fixtures plus all 4 maintained programs from the package, and
  is published as `v1.0.0-rc.9`; post-RC9 SH-7 moves that complete gate into
  the OpenC-native compiler and makes the D seed an optional audit oracle;
  SH-8 makes that native compiler the default Windows compiler-under-test,
  enforces validation and self-rebuild budgets, and
  reuses unchanged daily conformance evidence without re-executing fixtures;
  SH-9 adds OpenC-authored public `check`/`run`, human diagnostics with stable
  machine records, version/target/rule explanation, and direct public-CLI
  execution of all six demos; SH-10 adds native deterministic `fmt`,
  project-context `info`, and manifest/direct-project `test` workflows with
  stable machine records and relocated standalone verification; SH-11 adds
  native `openc lsp --stdio`, JSON-RPC lifecycle and capability negotiation,
  synchronized-document rule-ID diagnostics, SH-10 formatting, and
  deterministic 19/19 transcript verification; SH-12 adds a bounded
  synchronized project workspace, document symbols, typed hover,
  definition/reference navigation, sorted completion, collision-checked safe
  rename, and deterministic 23/23 project-semantic transcript verification;
  SH-13 adds native phase timing, indexed lowering lookups, byte-identical
  557.985-second self-rebuild closure, canonical OpenC-only implementation
  authority, and standalone distributions without D/Python source or DUB
  manifests; SH-19 then replaces the default generated-C/TinyCC path with the
  first-party x64/PE32+ backend, reaches byte-identical compiler closure, and
  passes the complete relocated release gate without C, TinyCC, D, Python, a
  CRT, an assembler, or an external linker in the package;
- all diagnostic expectations use exact current matches; the historical
  compatibility fallback has been removed from current execution, while its
  prior 93 rule-ID matches remain explicitly disclosed in `CHANGELOG.md`;
- all 466 active Core rules have executed dedicated fixture coverage, and all
  174 grammar productions name executed accepting/rejecting fixture pairs;
- licensing and governance are resolved: 0BSD for software and CC0-1.0 for
  specifications, documentation, metadata, diagrams, and artwork. Vendored
  TinyCC is a separate LGPL-2.1 component with notice and corresponding source
  retained only as an optional LGPL-2.1 differential-audit component in the
  repository; it and bundled headers are excluded from the SH-19 standalone
  package while their public-domain and MIT notices remain preserved.

The owner-certified Windows x86-64 Hosted `v1.0.0-rc.9` release candidate is
`RELEASED` as a GitHub prerelease. Independent third-party review remains
welcome and may produce errata; it is not a prerequisite for the
owner-maintained initial release.

The public RC8 package evidence remains the immutable 268-fixture historical
record described above. RC9 is the published 278-fixture successor. Mainline
now passes the SH-14 throughput gates, SH-15 Windows x64 ABI/machine-code,
SH-16 deterministic PE32+ plus CRT-free runtime, and SH-17 Win32 Metadata raw
projection, plus SH-18's twelve friendly Windows modules (27/27 checks).
The current 112-source compiler rebuild median is 10.103 seconds,
0.481x the pinned same-host D median;
the direct proof executable passes 34/34 checks, and the real metadata
projection passes 30/30 checks.

SH-19 Windows independence is complete. The first-party backend compiles the
whole 116-source compiler to a CRT-free PE32+ executable, reaches a
byte-identical 4,712,960-byte fixed point, and passes 278/278 conformance plus
4/4 maintained programs from a reproducible relocated package. Normal builds
no longer require generated C, TinyCC, C headers/runtime, D, Python, an
assembler, or an external linker.
The initial friendly module API is documented in `standard_library/WINDOWS_MODULES.md`.
SH-20 public throughput is complete. The fully validating 116-source
self-build now has a 17.064-second five-run median and 11.352-second validation
median; 20/20 chained builds are byte-identical. On the same host, the pinned
optimized ISO C and D references measure 22.732 and 17.504 seconds. Peak
compiler memory remains inside the 256 MiB private / 64 MiB working-set guards.
SH-21 is now active and replaces required Python build/test/release
orchestration with OpenC-native workflows while isolating D/Python/C/TinyCC to
an optional historical bootstrap/audit kit. Its second native workflow tranche
passes 8/8 full tasks, 278/278 conformance, 5/5 program checks, exact compiler
closure, renamed-executable self-location, and four adversarial child-process
guards. Native execution now contains descendants in a 256 MiB Job, enforces a
64 MiB working-set ceiling, caps captured output at 4 MiB, and applies bounded
timeouts. The remaining audit/release replacements are still active. Native
editor integration is deferred to SH-24. See
`compiler/selfhost/SH21_OPENC_NATIVE_WORKFLOWS_PLAN.md` and
`compiler/design/WINDOWS_NATIVE_INDEPENDENCE.md`.

Start with `AUTHORITY.md`, `STATUS.md`, `VERIFICATION_STATUS.md`,
`LICENSE_POLICY.md`, `standard/core/OpenC_Core_Current.md`, and
`release/LOCAL_BUILD_TEST_RELEASE_RUNBOOK.md`.
