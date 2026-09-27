# SH-27 selective source-partition semantic validation

Status: **local fixed-point, correctness, strict RAM, and paired edited-build
speed PASS; hosted and normal-default certification pending** (2026-09-27).
This is an opt-in 32-object compiler-project cache improvement, not SH-27
completion or a new C/D parity claim.

## Architectural cut

The source-partition COFF cache previously reused native objects after a body
edit but still flow-validated and acceptance-checked every source. On the
228-source compiler project, that left the edited build at about five seconds.
The compiler now authenticates the source-partition hit set after ordered
declaration/resolution and before flow validation. Flow and native acceptance
skip only sources in authenticated unchanged partitions; changed partitions
still take the complete semantic path. The same prepared hit set is carried
through native emission and the later object read reauthenticates saved bytes.
If preparation fails, the compiler falls back to full validation.

The cache schema is v2. Its project-wide key includes the resolved pointer
and unsafe-function flow flags, because body-local symbols can change those
conservative gates without changing the declaration projection. The source
hash still covers full bytes within each partition. Public declaration
changes invalidate all partitions. Native build timings report separately the
number of flow- and acceptance-validation sources skipped.

## Local evidence

The candidate is the checked-out-source, three-stage self-hosted compiler
SHA-256 `e6b4e31c3db74494364f65dbd511b2c10532f5e3d852449e758873cb69603c63`.
After the final source comment edit, a second three-stage bootstrap reproduced
that exact binary SHA-256 and bytes.
The immediately preceding frozen-type baseline is
`53ce21e774c1e28614e1175707240ff1f094f9e8aabf1978955722a09f985364`.
Both were measured on the same Windows host under 64 MiB child working-set
and 256 MiB child private-byte guards.

`test_source_partition_cache.py --flow4 --partitions 32` passed on the
candidate. The real compiler body edit reused 31/32 objects, skipped flow and
acceptance for 221 unchanged sources, and produced the exact fresh linked
executable and all 32 exact COFF objects. A malformed body retained byte-exact
fresh diagnostics despite 31 hits. A genuine added function declaration
invalidated all 32 partitions. A corrupted object record rebuilt exactly one
partition. A four-source negative matrix showed 3/4 hits after an ordinary
body edit, but 0/4 after a body-local pointer changed the project-wide flow
flag. No cached source was skipped in that invalidated case.

The new `benchmark_sh27_selective_semantic_cache.py` cold-seeded separate
revision caches on one copied compiler project, then made 11 distinct body
edits. The order alternated within pairs; every edited build had 31 hits,
one miss, exact cross-revision PE bytes, and enforced RAM bounds. Baseline
and candidate medians were **4.952 s and 2.872 s** (11/11 candidate wins;
median reduction 2.080 s, about 42%). This result is for the *opt-in edited
COFF build*, not normal-default cold compilation. The new source also passed
an 11-pair normal self-build non-regression check: baseline/candidate medians
4.444/4.317 s, paired median delta -0.020 s, 7 wins/4 losses.

The candidate passed strict 20/20 chained byte-exact self-builds. Peak
sampled child private bytes were 226,881,536 and working set 54,083,584,
under the 256/64 MiB caps. It also passed 278/278 native conformance
fixtures, exact 2/4-source-chunk and invalid-diagnostic comparison, and
2/8/32-partition COFF plus seeded fixed-point proof. The versioned
representative suite passed 3/3 small CLI, 3/3 four-module medium audit,
and 3/3 compiler self-build runs locally after generated-output disk
headroom was restored. This was an OpenC correctness/RAM run, not a new
C/D comparator run. The local reports are
in ignored `OpenC-1.0/build-output/ss-final/`: `strict20.json`,
`conformance.json`, `chunk-equivalence.json`, `source-partition-coff.json`,
`cache-flow4-interface.json`, `selective-pairs11.json`, and
`default-pairs11.json`; the representative report is ignored
`OpenC-1.0/build-output/r4.json`.

## Remaining boundary

The cold 32-object cache build is still much more expensive than ordinary
direct-PE compilation, and the source-partition cache remains restricted to
the opt-in module-COFF-set mode. The current one-source edit proof does not
establish a robust default cold/warm/edit policy on representative real user
projects. Complete hosted module/COFF, representative-project, two independent
final-source 20/20 pinned C/D runs, clean editor, and release-integrity gates
remain required. No source-partition result substitutes for them.
