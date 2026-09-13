# SH-27 post-release integrity and production-performance plan

Status: **ACTIVE — PUBLIC INTEGRITY BASELINE PASS; PERFORMANCE EXPANSION OPEN**

SH-27 begins after the immutable Windows x86-64 Hosted 1.0.0 publication. It
does not modify or relabel the released artifacts and does not add Linux or
freestanding work to the supported 1.0 scope.

## A. Public artifact integrity — blocking and automated

`scripts/verify_sh27_post_release.py` must resolve the annotated tag to the
exact release commit, read the authorized release record, stream-download all
15 public assets in bounded 1 MiB blocks, and verify names, sizes, GitHub API
digests, downloaded SHA-256 digests, and the mandatory checksum list. This
gate currently passes.

## B. Independent review and errata — continuously open

The five grammar, semantics, security, editor, and release/reproducibility
tracks remain open. Received reviews must retain reviewer provenance and route
findings through `release/ERRATA_POLICY.md` or `SECURITY.md`. Zero reviews have
been received, so no independent certification is claimed.

## C. Production C/D throughput expansion — highest engineering priority

The existing SH-20 result remains a valid fixed-workload regression baseline,
but it is not enough to claim broad parity with optimized production C and D
toolchains. SH-27 expands measurement to pinned MSVC, LLVM/Clang, and DMD/LDC
versions on the same Windows host and records cold and warm results for:

1. small single-file command-line builds;
2. the complete OpenC compiler self-build;
3. multi-module incremental rebuilds with one changed source;
4. parallel independent-project batches;
5. generated large functions and many-small-function scaling;
6. executable startup, file I/O, allocation, and representative runtime work;
7. peak private bytes, peak working set, output size, and deterministic hash.

Every language must perform comparable parsing, semantic checking, code
generation, and linking work. Setup, cache policy, antivirus state, compiler
version, command line, source bytes, and run order must be recorded. Medians,
percentiles, and individual samples are published; selectively favorable
cases cannot be promoted as the overall result.

SH-27 performance closes only when the representative corpus and harness are
checked in, MSVC plus Clang and at least one D compiler have executed it on a
clean Windows runner, OpenC has no correctness or memory regression, and every
remaining material deficit has either been fixed or is explicitly quantified.
The first deterministic corpus and bounded harness are now checked in at
`benchmarks/sh27/CORPUS.json` and
`compiler/selfhost/benchmark_sh27_production.py`. The automatic/manual
`.github/workflows/openc-performance.yml` gate requires OpenC, MSVC, Clang, and
pinned DMD 2.112.0 on a clean Windows runner. The local OpenC/DMD validation
passes correctness and memory checks. Clean Windows run 34773764974 then
passes pinned MSVC 19.44, Clang 20.1.8, and DMD64 2.112.0 version selection and
every correctness, execution, output, and memory check. It exposes large OpenC
median ratios of 51.047x MSVC, 27.351x Clang, and 86.036x DMD64. Run
34775393808 then rebuilds the checked-out source twice under the same RAM
guards, proves a byte-exact fixed point, and verifies the first fix. Semantic
gating reduces pointer-arithmetic validation on pointer-free input from 13.138
seconds to 0 milliseconds and the large median from 25.983 to 10.003 seconds.
Run 34776722018 verifies indexed expression, block, call, control, and return
traversal at another exact fixed point. The large median falls to 4.039 seconds
and expression plus function/scope/enum acceptance falls from about 6.78
seconds to about 0.12 seconds. Run 34778351292 then verifies project/source
candidate gates that reduce absent pointer-fact, unsafe-primitive, scope-action,
and unsafe-call groups to 0 milliseconds. The large median reaches 2.797
seconds; remaining ratios are 5.583x MSVC, 2.721x Clang, and 8.879x DMD64.
Repeated parse/syntax construction across declaration collection, resolution,
flow validation, fused acceptance/lowering, and emission is next. The remaining
runtime/build-system corpus and measured validation fixes are still open. Broad
production-comparator parity is correctly OPEN, not assumed from SH-20.
