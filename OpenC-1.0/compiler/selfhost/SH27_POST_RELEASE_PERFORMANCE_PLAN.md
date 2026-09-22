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

Run 34785359915 then bounds each call-free native constant pool from its IR
literal spans instead of reserving against the complete project source for
every function. Local paired evidence reduces native-emission median from 763
to 516 milliseconds with byte-identical output. Clean large emission samples
are 204–292 milliseconds, while same-run total ratios are 2.305x MSVC, 1.302x
Clang, and 4.115x DMD64. Because the latest Clang sample follows two gate
passes but falls just outside 1.25x, Clang parity remains intermittent and
broad parity remains open. Large validation, indexing, lowering, emission,
and DMD-relative many-file work remain the highest priority.

Run 34786288051 then replaces quadratic duplicate-function comparison with
lookups in the already initialized module/name buckets, retaining exact name
and signature checks plus the original non-indexed fallback. Clean large
acceptance falls to 187–204 milliseconds and the total median reaches 1.173
seconds. The latest Clang ratio passes at 1.120x; large MSVC and DMD64 remain
open at 2.360x and 3.736x. Seven of nine gates pass, with many-file DMD64 only
narrowly open at 1.255x. Large native pipeline work remains the primary target.

Run 34786895725 then replaces per-byte native object/image copies with one
capacity-checked bulk operation implemented by OpenC's own runtime. The clean
large median reaches 1.045 seconds and passes Clang at 0.991x; every small and
many-file comparator gate passes. Large MSVC and DMD64 remain open at 2.053x
and 3.339x. Native per-function setup and the remaining frontend passes stay
on the critical path.

Run 34787176733 then directly encodes the one stack-allocation unwind record
used by each native function, removing two generic heap arenas per function
while preserving the exact Windows x64 bytes. The clean large median reaches
0.869 seconds and passes Clang at 1.060x. Large MSVC and DMD64 remain open at
1.735x and 2.776x; parsing, semantic validation, and remaining native setup are
the measured critical path.

Run 34787810925 then replaces field-by-field transfer of retained five-word
token and syntax records with one bounded OpenC-runtime copy. The exact-size
cache and its low retained-memory behavior remain unchanged. Local paired
large-corpus evidence moves declaration collection from a 344-millisecond
median to 328 milliseconds and preserves byte-identical output. The clean run
rebuilds current source to the byte-exact 7,173,120-byte `ee158767...19a313`
fixed point and passes every correctness, execution, output, and memory check.
Its host observation records small OpenC/MSVC/Clang/DMD medians of
0.097/0.119/0.128/0.138 seconds, many-file medians of
0.191/0.362/0.867/0.159 seconds, and large medians of
1.096/0.507/0.955/0.313 seconds. Large ratios are therefore 2.162x MSVC,
1.148x Clang, and 3.502x DMD64. All small and many-file gates pass; large MSVC
and DMD64 parity and broad production parity remain explicitly open. The
retained artifact ZIP is 13,808,067 bytes with SHA-256
`1ce2add2e6babd1686741e634af4d52b195a599d2532d46459605d1fe1afd828`.

Run 34809511246 then bounds native code and relocation scratch for call-free,
scope-free functions by the IR work that can reach those lowering paths. The
relocation bound explicitly covers the densest checked float-to-integer cast
and the mandatory malformed-fallthrough trap. Seven paired local large-corpus
builds reduce the total median from 1.500 to 1.453 seconds and the combined
lowering/emission median from 643 to 595 milliseconds while preserving the
exact `54fe73ad...90746b` program output and effectively unchanged peak memory.
The clean run rebuilds current source to the byte-exact 7,173,632-byte
`7cc72649...4472501f` fixed point and passes every compiler, execution, output,
and memory check. Its small OpenC/MSVC/Clang/DMD medians are
0.097/0.118/0.128/0.148 seconds, many-file medians are
0.190/0.357/0.919/0.160 seconds, and large medians are
1.091/0.515/0.977/0.340 seconds. Large ratios are 2.118x MSVC, 1.117x Clang,
and 3.209x DMD64. Large MSVC/DMD and broad production parity remain open. The
retained artifact ZIP is 13,808,921 bytes with SHA-256
`d3a83451763e826e5c34ba018d53d9c69f983beccabbd14e699045342f33e2b0`.

Run 34810131926 then narrows the ordinary call-free relocation reserve to the
audited four-edge non-cast maximum while preserving the six-edge bound for any
function containing a cast. Eleven order-alternated local pairs produce 8
candidate wins, 1 tie, and 2 losses, a -78-millisecond median paired delta,
and a native-emission median reduction from 234 to 219 milliseconds. Every
program remains byte-identical at `54fe73ad...90746b`, 278/278 native fixtures
pass, and the process guard remains below 512 MiB. The clean run rebuilds to
the byte-exact 7,174,144-byte `eeecf5dd...4b350901` fixed point and records
small OpenC/MSVC/Clang/DMD medians of 0.087/0.107/0.118/0.138 seconds,
many-file medians of 0.191/0.343/0.852/0.160 seconds, and large medians of
1.075/0.506/0.963/0.312 seconds. Large ratios are 2.125x MSVC, 1.116x Clang,
and 3.446x DMD64. The retained artifact ZIP is 13,809,470 bytes with SHA-256
`05a71ebf2c8b88a5d04fb37a46159366cbe3662917ddf1e6300d18bac6a373ba`.

Run 34811322028 then uses the existing top-level symbol index to prove when a
source has no enum declaration and skips the otherwise unconditional enum
syntax pass. Enum-bearing sources retain the exact validator, and contexts
without the index retain a source-symbol fallback. Eleven order-alternated
local pairs reduce the `functions_scopes_enums` median from 31 to 16
milliseconds and acceptance from 282 to 269 milliseconds; the paired deltas
are -15 and -14 milliseconds respectively, while the whole-build paired
median is flat. Every output remains byte-identical at
`54fe73ad...90746b`, 278/278 native fixtures pass, and median process memory is
effectively unchanged. The clean run rebuilds checked-out source to the
byte-exact 7,175,680-byte `53394df7...dbde83e6` fixed point and passes every
compiler-version, correctness, execution, output, and memory check. Its small
OpenC/MSVC/Clang/DMD medians are 0.098/0.119/0.129/0.137 seconds, many-file
medians are 0.190/0.361/0.929/0.170 seconds, and large medians are
1.058/0.514/1.059/0.342 seconds. Large ratios are therefore 2.058x MSVC,
0.999x Clang, and 3.094x DMD64. The clean large internal phase medians are 282
milliseconds for declarations, 280 for validation, and 407 for combined
lowering/emission; expression acceptance at 139 milliseconds is the next
frontend target. Large MSVC/DMD and broad production parity remain open. The
retained artifact ZIP is 13,811,055 bytes with SHA-256
`d7a9110ef7542c71af36d89c1175d95504f05702d60ca69aaa274b8876f7150c`.

Runs 34834928956 and 34835402812 then optimize the assignment/type-inference
hot path identified by temporary per-rule profiling. Plain-name assignments
resolve their left symbol once for lvalue, mutability, and expected type while
complex member/index/pointer destinations retain the original path. Type
inference and IR lowering also defer evaluation of the right integer until the
left operand is actually an integer literal, which avoids reparsing tens of
thousands of right literals in variable-left arithmetic. The temporary
profiling instrumentation and two candidates without a targeted win were
discarded before commit. Eleven order-alternated local pairs for the direct
assignment path record a -14-millisecond expression-acceptance delta. Eleven
more pairs for lazy integer evaluation record a -31-millisecond IR-lowering
delta and -15-millisecond whole-build delta. Both preserve the exact
`54fe73ad...90746b` large program output, effectively unchanged memory, and
278/278 native conformance. The combined clean run rebuilds to the byte-exact
7,178,240-byte `d681b6fd...74ba3cee` fixed point and passes every version,
correctness, execution, output, and RAM check. Its small
OpenC/MSVC/Clang/DMD medians are 0.096/0.129/0.117/0.138 seconds, many-file
medians are 0.179/0.339/0.862/0.159 seconds, and large medians are
1.014/0.503/1.022/0.324 seconds. Large ratios are therefore 2.016x MSVC,
0.992x Clang, and 3.130x DMD64. Clean large internal medians are 250
milliseconds declarations, 236 validation, 110 expression acceptance, 125 IR
lowering, and 188 native emission. Large MSVC/DMD and broad parity remain
open. The retained artifact ZIP is 13,812,790 bytes with SHA-256
`b307c968a9eeed277c8c231b4d2722a8073a2eca41af2238b5d302eae3e69c9c`.

Runs 34839072231 and 34863528233 then test and correct native source-cache
initialization. Removing the explicit 10 MiB clear reduces local memory and
project-load time, but the first workflow correctly rejects it because the
seed-to-stage-one generation is not byte exact. The retained implementation
keeps deterministic initialization and bounds the direct-mapped cache from
262,144 to 16,384 entries, reducing its storage from 10 MiB to 640 KiB.
Eleven alternating local pairs preserve exact output, reduce private bytes by
9,748,480 and working set by 9,830,400 in every pair, and leave total time
flat. Generated-runtime changes require one transition compiler, so the
production harness now builds three stages and requires stage two and stage
three to be byte identical. Run 34863528233 passes that stronger check at
`0787d816...32059`; 278/278 native fixtures also pass locally. Its retained
artifact ZIP is 15,176,896 bytes with SHA-256
`29e8b12c2a89cd9b630900529138a9e0cef4936a4a8b874342c2c536f3d004c0`.

Run 34864294052 then verifies the same bounded design for path joins. The
direct-mapped cache falls from 65,536 to 16,384 entries, or 3 MiB to 768 KiB,
while collisions still recompute and replace the entry. Eleven alternating
local pairs produce eight wins, a -31-millisecond median paired total, and
reductions of 2,355,200 private bytes and 2,363,392 working-set bytes in every
pair. The clean run proves the stage-two/stage-three `6c1baf87...d87e9` fixed
point and passes all version, correctness, execution, output, and RAM checks.
Small OpenC/MSVC/Clang/DMD medians are 0.086/0.108/0.128/0.160 seconds,
many-file medians are 0.200/0.352/0.861/0.168 seconds, and large medians are
1.056/0.500/0.961/0.322 seconds. Large ratios are 2.112x MSVC, 1.099x Clang,
and 3.280x DMD64. The full guarded self-build median is 6.116 seconds, with
183,390,208 private and 68,718,592 working-set bytes. Shared-runner large phase
medians are 266 milliseconds declarations, 249 validation, and 439 combined
lowering/emission. Temporary local phase instrumentation was removed after it
showed that parsing itself dominates declaration time; file reads are below
the clock tick, lexing is materially smaller, and retained-record copying is
not the bottleneck. Parser call overhead is the next measured target. The
retained artifact ZIP is 15,176,831 bytes with SHA-256
`0b5153c81c9ffaf3dff45370d854888700b60fe03bbe192b5b5093bdc636d42b`.

Runs 34865726703 and 34866286255 then remove measured parser call overhead.
Token kind/start/length access reads the packed record directly, and token
matching reads start and length once instead of traversing the generic wrapper
twice. Eleven order-alternated local pairs reduce declarations by a
94-millisecond paired median in all eleven pairs and reduce total time by 109
milliseconds with ten wins. Parser check and match then dispatch directly to
the token matcher instead of adding current-token and check call frames.
Eleven further pairs reduce declarations by another 31 milliseconds with ten
wins and total time by 47 milliseconds with eight wins. Both changes preserve
the exact `54fe73ad...90746b` large output, effectively unchanged RAM, exact
three-stage compiler closure, structure validation, and 278/278 conformance.
A direct cursor-advance follow-up has no declaration win and loses seven of
eleven total pairs, so it is discarded before commit.

Clean run 34866286255 proves the 7,178,240-byte `ec395588...e73a0` stage-two/
stage-three fixed point and passes every version, correctness, execution,
output, and memory check. Small OpenC/MSVC/Clang/DMD medians are
0.087/0.119/0.139/0.152 seconds, many-file medians are
0.179/0.370/0.969/0.170 seconds, and large medians are
1.002/0.516/0.984/0.326 seconds. Large ratios are therefore 1.942x MSVC,
1.018x Clang, and 3.074x DMD64. The guarded complete self-build median is
6.000 seconds with 183,554,048 private bytes and 68,730,880 working-set bytes.
Large phase medians are 188 milliseconds declarations, 266 validation, and
469 combined lowering/emission; compiler-owned subphase medians are 79
milliseconds indexing, 125 IR lowering, and 220 native emission. Native
emission is the next measured target. The retained artifact ZIP is 15,176,688
bytes with SHA-256
`43b92abfce95783db7b9b0455fd1d5b9f7a52df779fb07dc217d08d8105d630a`.

Integer constants within the signed parser range are now lowered to numeric
IR immediates. Native emission consumes their bits directly, avoiding a
temporary text buffer and second integer parse. Existing source-text handling
remains for large unsigned and negative literals. Eleven alternating local
pairs against the previous accepted compiler show 9 total-time wins, 1 tie,
and 1 loss; the median paired total improves by 46 milliseconds, with paired
IR lowering improving 30 milliseconds and native emission 12 milliseconds.
All pairs preserve the `54fe73ad...90746b` production output and essentially
flat peak memory. The 7,179,776-byte stage-two/stage-three compiler matches
byte-for-byte at `ebf1c4f4...fddcd45`; 278/278 conformance fixtures pass under
the process memory guard. A dedicated executable covers signed and unsigned
64-bit boundaries, decimal separators, binary/hex radix, negative literals,
and enum constants; candidate and prior-compiler PE hashes are identical at
`8fa53c4c...fa3d990a`, and both exit zero. Clean shared-runner evidence is
now available from run 35774378673. Its complete 15,178,548-byte artifact ZIP
has SHA-256 `63086a2b93f5807cfd2bc424b2fbff16282bddad3dc7b6fa2ea4dd679f31da90`.
All version, correctness, output, execution, bootstrap, and memory checks pass;
stage two and three match at `ebf1c4f4...fddcd45`. Small OpenC/MSVC/Clang/DMD
medians are 0.087/0.117/0.118/0.149 seconds; many-file medians are
0.169/0.349/0.905/0.159 seconds; and large medians are
0.914/0.509/1.027/0.324 seconds. Large ratios are 1.796x MSVC, 0.890x
Clang, and 2.821x DMD64. The guarded complete self-build median is 5.752
seconds with 182,751,232 private and 68,882,432 working-set bytes. Clean large
phase medians are 172 milliseconds declarations, 265 validation, and 376
combined lowering/emission; compiler-owned subphases are 63 indexing, 125 IR
lowering, and 141 native emission. Validation is now the largest phase, with
186 milliseconds acceptance (108 expression acceptance in the first clean
sample) and 79 flow. Expression acceptance is next; broad MSVC/DMD parity
remains open. The workflow reports `EVIDENCE_COMPLETE_DEFICIT`, not parity.

The next local profile isolates assignment validation within expression
acceptance using one clock boundary per source and an additive timing JSON
field. It consumes about 172–188 of 219 expression milliseconds on the large
corpus. Operator byte classification, repeated function-selection bypass,
identical-type assignment bypass, binary-result reuse, and lazy right-side
typing were explored; the paired evidence did not justify retaining any of
them. The common name hash was then changed to reduce its modulo-16,777,213
polynomial once per four bytes rather than after each byte. Four steps stay
below 4,941,000,000,000,000 on the 64-bit target, and 6,425 generated cases,
including empty strings and owner-boundary values, match the former hash
exactly. Twenty-one alternating local build pairs for the exact final revision
against the trace-only compiler preserve the `54fe73ad...90746b` executable,
keep RAM flat, and improve median paired compiler-owned total by 16
milliseconds, assignment validation by 3, and wall time by 5. The
7,182,848-byte compiler stage-two/stage-three SHA is `3dc01bc0...480067`; the native
conformance suite passes 278/278.

Clean Windows run 35782427590 passes every version, correctness, output,
execution, fixed-point, and memory check. Its 15,183,173-byte retained
artifact ZIP has SHA-256
`fdfed423d417e2aeca2232982822a4ccaa75e8ebc6ab2566186b39d54765cd29`.
Small OpenC/MSVC/Clang/DMD medians are 0.066/0.107/0.095/0.188 seconds;
many-file medians are 0.137/0.276/0.735/0.138 seconds; large medians are
0.747/0.409/0.847/0.251 seconds. Large ratios are 1.826x MSVC, 0.882x
Clang, and 2.976x DMD64. All small and many-file gates pass, but large
MSVC/DMD and broad parity remain open. The guarded self-build median is
4.611 seconds with 182,247,424 private and 65,400,832 working-set bytes.
Clean large phase medians are 141 milliseconds declarations, 249 validation,
and 282 combined lowering/emission; compiler-owned subphases are 31 indexing,
62 IR lowering, and 155 native emission. The new assignment trace measures
93 of 108 expression-validation milliseconds. Comparators were faster than
in the prior clean run too, so the lower absolute OpenC median is not treated
as a same-host relative parity gain. Assignment resolution and right-side
type inference remain the next measured targets.

The next corpus expansion adds a checked-in startup/file-I/O/allocation
fixture in OpenC, C, and D. Each executable performs 64 rounds of 4 KiB
allocation, typed writes, file write/read, value verification, and cleanup.
The harness now guards executable private bytes and working set as well as
compiler processes, enforces a 30-second executable timeout, and requires an
exact final 4 KiB payload digest and one success line. A local three-sample
OpenC/DMD comparison passes every correctness and RAM check; its runtime-lane
compile medians are 0.256/0.198 seconds and its executable medians are
0.414/0.770 seconds. This is a partial comparator set, not a clean-run or
broad runtime-parity claim. Clean Windows workflow run 35785619912 then
executes that fixture with pinned MSVC and Clang as well as DMD. It passes
every compiler-version, correctness, payload, execution, fixed-point, and
memory check; all three runtime-lane compilation ratios pass the 1.25x gate
(OpenC/MSVC 0.347x, Clang 0.554x, DMD 0.517x). Runtime-lane compiler medians
are 0.077/0.222/0.139/0.149 seconds and executable medians are
0.016/0.016/0.016/0.027 seconds, respectively. This small fixture does not
establish broad runtime parity. The clean large-function medians are
0.687/0.432/0.738/0.274 seconds, leaving 1.590x MSVC and 2.507x DMD
compilation deficits while Clang passes at 0.931x. The stage-two/stage-three
SHA-256 is exactly `3dc01bc0...480067`; the 16,366,949-byte retained evidence
ZIP has SHA-256
`f6a2492f65bce83f9bacadb17df7781a9fde5624e7ab40294f6ff7341d5e2596`.
Large OpenC phase medians are 109 milliseconds declarations, 126 validation,
and 358 combined lowering/emission. The next optimization should target
measured lowering/IR and native emission, then remeasure large MSVC/DMD
ratios. Incremental object reuse, LDC, and broader real-project programs
remain explicit corpus-expansion work. Public 15/15 release-asset integrity
was reverified before this change; the five external review tracks remain open
with no reviews received.

The next compiler-owned profile separates syntax indexing into node,
parent-position, statement, and function-position work and records native
code/relocation/constant reservation versus actual use. In the local large
corpus, parent-position indexing takes 93 of 124 indexed milliseconds, while
the native emitter reserves 40,711,424 code bytes and uses 2,723,115. Three
candidate shortcuts are rejected before publication: bypassing two node-kind
helpers, skipping empty control-position construction, and replacing indexed
word helpers directly have no credible paired gain. A bounded grow-on-demand
code buffer reduces reservation to 11,220,224 bytes but loses 49 milliseconds
in median paired wall time and 78 milliseconds in native emission, so it too
is discarded. The retained candidate instead eliminates the extra `d_put_byte`
call from each x64 byte emission while preserving overflow/error semantics.
Eleven order-alternated local large-corpus pairs against an equally
instrumented baseline give eight wins and a -22-millisecond median paired
wall-time delta; native emission improves by a -31-millisecond paired median
with nine wins. Every output is byte-identical at `54fe73ad...90746b`, peak
private memory is flat, the three-stage compiler reaches the byte-exact
`6fb216ec...679b04a` fixed point, the SH-15 substrate passes 25/25, and
native conformance passes 278/278. Clean MSVC/Clang/DMD comparator evidence
for this change arrives in successful Windows workflow run 35790749519. Its
16,387,708-byte retained evidence ZIP has SHA-256
`463f9ff0fcc3ebc8583f1c86b61d696bd1cdccc085ccb641258f11918308b863`.
Every compiler-version, executable, output, memory, and three-stage fixed-point
check passes; stage two and three match at `6fb216ec...679b04a`. Small,
many-file, and runtime lanes pass every 1.25x compile ratio. Large
OpenC/MSVC/Clang/DMD medians are 0.756/0.413/0.789/0.282 seconds, leaving
1.831x MSVC and 2.681x DMD deficits while Clang passes at 0.958x. Clean
large internal medians are 141 milliseconds declarations, 187 validation,
and 329 combined lowering/emission, including 47 indexing, 63 IR lowering,
and 172 native emission. Parent-position indexing accounts for 31 of the 47
indexed milliseconds; native code reservation remains 40,711,424 bytes for
2,723,115 used. These cross-run medians do not prove the local paired gain
survives a clean host because the comparator baselines changed too. A
same-host baseline/candidate pair is required before promoting the x64 byte
change as a clean-run speedup. Broad C/D parity, incremental object reuse,
LDC, and broader real-project programs remain open.

The dedicated manual `openc-performance-paired.yml` workflow now supplies that
attribution gate. Successful clean Windows run 35791958727 rebuilds both
`ab7dde464e43b4749beafa5e3cc40603dbea6f81` and the byte-emitter revision
`a67dda9e` from the retained seed, verifies each stage-two/stage-three fixed
point, then alternates eleven guarded builds of one identical source tree.
The candidate wins ten pairs, ties one, loses none, and improves median paired
wall time by 12 milliseconds (0.754 to 0.741 seconds in the run medians).
All 22 programs have the exact `54fe73ad...90746b` SHA-256, all checks pass,
and both revisions peak at 133,337,088 private bytes. The paired artifact ZIP
is 14,132,215 bytes with SHA-256
`f78daf369fa304ac3434906c668874e4f0813330baa0330c2545f08221ee205d`.
Native emission improves by a 31-millisecond median paired delta, though
other phase timings fluctuate. The change is now supported by same-host clean
evidence, but the 1.831x MSVC and 2.681x DMD large-compilation deficits remain
material. Further compiler-owned optimization and broader corpus expansion
are still SH-27 work.

The next corpus expansion adds a deterministic `control_flow` lane: four
source files, 256 total functions, nine operations per function, and matched
OpenC/C/D programs that exercise branches, local variables, loops, arithmetic,
semantic validation, native code generation, and executable behavior. The
existing 512 MiB process limits and 1.25x ratio gate apply unchanged. Local
guarded OpenC and DMD64 builds both compile and execute the first-source
oracle successfully. Clean Windows run 35794199084 then passes every pinned
comparator, compiler/executable correctness, exact-output, memory, and
three-stage fixed-point check. The fixed-point compiler is unchanged at
`6fb216ec...679b04a`; every control-flow OpenC executable hashes to
`4494ddc0...5330d`. The 17,775,179-byte retained artifact ZIP has SHA-256
`823a0b5a98c142868f946a52364409171b0c48aa122b615269ab9f6aaa48b42b`.
Control-flow OpenC/MSVC/Clang/DMD medians are 0.553/0.562/0.637/0.211
seconds: OpenC meets the 1.25x MSVC and Clang gate (0.984x and 0.868x), but
misses DMD by 2.621x. Clean control-flow validation is about 282 ms, with
140–141 ms in assignment checks; that is a measured next optimization target.
The local host's earlier 814 ms validation on the same 206,637-byte OpenC
tree reflects different host conditions and is not used as the comparator.
Large-function medians on this run are 0.902/0.524/1.042/0.326 seconds,
leaving 1.721x MSVC and 2.767x DMD deficits. Broad C/D parity remains open.
Record-access, function-selection, operator-dispatch, and binary type-reuse
candidates were discarded after guarded same-host pairs failed to show a
credible wall-time gain. The next compiler change should address measured
right-hand type inference in assignment validation without trading away
control-flow correctness or memory stability.

The paired-revision workflow now accepts either the large-function or the
control-flow workload, so both can be measured against a previous compiler
on the same clean Windows runner. A temporary type-query trace on the new
control-flow source counted about 4,416 assignment-pass type queries per
source: 1,152 cache hits, 1,152 first-time binary resolutions, 1,152
first-time name resolutions, and 960 first-time integer resolutions. This
showed that the hotspot is largely initial inference rather than repeated
cache misses. A trial replacing fixed built-in type-name scans with their
canonical IDs passed an exact three-stage bootstrap, 25/25 x64 substrate,
278/278 native conformance, and byte-identical output, but clean paired
large-function run 35796488055 lost eight of eleven pairs (median +10 ms).
Clean paired control-flow run 35796491694 was flat (median 0 ms, four wins,
two ties, five losses). The candidate is not promoted to master. A separate
clean full-corpus run 35796531597 completed, but its cross-run absolute
medians are not evidence of an improvement because the comparator host also
changed. The next speed work needs a larger architectural reduction in
first-time semantic inference and/or pass count, not another unproven lookup
micro-optimization.
