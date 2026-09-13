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
seconds. Run 34778904952 then verifies a conservative stateless-source flow
fast path: seven of eight large-corpus sources avoid private flow syntax
construction, and the median reaches 2.223 seconds. Remaining ratios are
4.482x MSVC, 2.171x Clang, and 7.080x DMD64. Runs 34779762154 and 34780027346
then verify bounded prefix-type lookup at the same exact fixed point. The
confirmation run reduces large resolution from 703–718 to 265–282 milliseconds
and the total median to 1.808 seconds; remaining ratios are 3.660x MSVC, 1.762x
Clang, and 5.776x DMD64. Run 34781697232 then verifies exact parsed-source
reuse between resolution and native lowering. Lowering reparsing reaches 0
milliseconds, the large median reaches 1.550 seconds, and remaining ratios are
3.119x MSVC, 1.542x Clang, and 5.132x DMD64. Moving cache construction to
declaration collection so resolution can reuse it is next. Run 34782327317
verifies that one-parse frontend: resolution reaches 0 milliseconds, the large
median reaches 0.931 seconds, and small plus many-file lanes pass every 1.25x
gate. Large ratios remain open at 1.896x MSVC, 1.317x Clang, and 3.313x DMD64.
Run 34783166021 then verifies flow reuse of the same parsed-source cache and
records 0 milliseconds of flow parsing in all three large samples. Absolute
times vary upward across the runner observation, but the same-run large ratio
reaches 1.235x Clang and passes that 1.25x gate. Large MSVC and DMD64 ratios
remain open at 2.453x and 3.850x. Remaining acceptance/index/lowering/emission
costs, the runtime/build-system corpus, and measured compiler fixes are still
open. Broad production-comparator parity is correctly OPEN, not assumed from
SH-20.

Run 34783983035 then replaces seven to ten independent flow feature searches
with one exact-equivalent source pass. Flow falls to 31–47 milliseconds and the
large OpenC median reaches a new low of 0.805 seconds. The same runner also
makes all comparators materially faster: latest large ratios remain open at
1.949x MSVC, 1.342x Clang, and 3.073x DMD64. The earlier 1.235x Clang
observation is therefore retained as evidence but not described as sustained
parity. Expression acceptance and native index/lower/emit work are next.

Run 34784470942 then candidate-gates empty expression rule families and records
a 1.218x large Clang ratio. Run 34784845146 adds an identity path when IR
instructions are already in final block order, avoiding per-function counting
sort allocations and passes while retaining the stable fallback. Its large
Clang ratio is 1.213x, the second consecutive pass. Latest large MSVC and DMD64
ratios remain open at 2.501x and 3.975x; continued compiler-owned
validation/lowering/emission reduction remains the highest priority.
