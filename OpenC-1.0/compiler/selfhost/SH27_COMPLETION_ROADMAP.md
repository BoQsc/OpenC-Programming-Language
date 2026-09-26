# SH-27 completion roadmap

Status: **ACTIVE; current-source hosted synthetic parity replicated, but
SH-27 is not complete**. The ordered, falsifiable
implementation checklist is `SH27_EXECUTION_PLAN.md`; this file retains the
full measurement history and work-package rationale.
`SH27_CANDIDATE_PORTFOLIO.md` is the concise current decision index for
parallel candidates, rejected cuts, and the next architectural batch.
`SH27_POST_RELEASE_PERFORMANCE_PLAN.md`, `SH27_NATIVE_CHUNK_PROOF.md`, and
`../../release/SH27_PRODUCTION_CORPUS_EVIDENCE.md` retain the historical evidence.
Do not mistake a green evidence-only workflow for throughput parity.
`SH27_TYPED_EXPRESSION_CUTOVER.md` specifies the Gate C implementation and
cutover proof, including the current pass-order and call-node dependency traps.
`SH27_DEFAULT_AUTO_EVIDENCE.md` records the adaptive-default candidate and
its first successful clean production-policy run. That run does not close the
two-run parity or memory gates. The bounded-IR experiment is recorded below;
it is not a substitute for the semantic cutover.

Current checkpoint (2026-09-24): the unchanged production compiler source
`1b58d5e` passed two independent clean `--runs 20 --enforce-parity` normal-
default runs, [35941734238](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35941734238)
and [35942493151](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35942493151),
with all 20 ratios below 1.25x. See
`SH27_NORMAL_DEFAULT_PARITY_REPEAT_EVIDENCE.md` for the raw-artifact IDs and
limits. Earlier failed clean runners below remain valid historical evidence
of sensitivity; do not compare their absolute medians across hosts. The
remaining critical work is content-validated incremental COFF reuse from
saved objects, representative projects, current-final-source full strict memory and
correctness certification, and release integrity. Isolated typed/QPC cuts
did not produce a qualifying speed signal and were not merged.
The [isolated function semantic/IR Phase B2](https://github.com/BoQsc/OpenC-Programming-Language/blob/89dd8d4/OpenC-1.0/compiler/selfhost/SH27_FUNCTION_SEMANTIC_IR_B2_EVIDENCE.md)
removed the assignment/binary sweeps on all generated large/control sources,
but a guarded 11-pair/null matrix rejected it: large improved 16 ms while
control regressed 10 ms, and compiler self-build activated 0/223 sources.
No throughput candidate is promoted from that cut.
The [Phase B3 operator-census/builtin-type attempt](https://github.com/BoQsc/OpenC-Programming-Language/blob/4c96ee0/OpenC-1.0/compiler/selfhost/SH27_SEMANTIC_IR_B3_REJECTION.md)
was also a NO-GO: its critical control worker stayed 156 ms and the
whole-wall large/control results did not clear same-run null/wins gates.
An [isolated native workflow input](https://github.com/BoQsc/OpenC-Programming-Language/blob/e233fee/OpenC-1.0/compiler/selfhost/SH27_WORKFLOW_CLEAN_PROFILE_INPUT.md)
can now pass a current clean-profile report path without changing the
historical SH-25 record; its own new compiler correctly failed the two
identity checks against the earlier report, so final-source 14/14 is open.
`SH27_INCREMENTAL_OBJECT_REUSE_ARCHITECTURE.md` maps the current one-object,
global-ID pipeline and the safe implementation/proof sequence. Its newer
current delta records an isolated opt-in automatic cache; none is promoted
into the normal production build yet.
The versioned `benchmarks/sh27/representative/SUITE.json` and guarded
`benchmark_sh27_representative.py` now exercise a CLI, four-module file-audit
app, and actual compiler self-build with exact cold/warm/edit/runtime/RAM
checks. The medium app is benchmark-authored and small; retained user projects
and repeated project comparisons are still required. A [pinned hosted
C/D/OpenC medium-app proof](SH27_REPRESENTATIVE_HOSTED_PROOF.md) now passes
three cold/warm/edit repetitions with exact execution on the unchanged
production compiler source. The separate isolated [interface projection](https://github.com/BoQsc/OpenC-Programming-Language/blob/c0b2343/SH27_INTERFACE_FINGERPRINT_EVIDENCE.md),
[stable COFF symbol identity](https://github.com/BoQsc/OpenC-Programming-Language/blob/f68c65f/SH27_STABLE_COFF_IDENTITY_EVIDENCE.md),
the [opt-in per-module COFF-set slice](https://github.com/BoQsc/OpenC-Programming-Language/blob/bd0a497/SH27_MODULE_COFF_SET_EVIDENCE.md),
the [restricted OpenC-native multi-COFF link](https://github.com/BoQsc/OpenC-Programming-Language/blob/1561b71/SH27_NATIVE_MODULE_COFF_LINK_EVIDENCE.md),
and [function type-freeze probe](https://github.com/BoQsc/OpenC-Programming-Language/blob/c97e28e/OpenC-1.0/compiler/selfhost/SH27_FUNCTION_TYPE_FREEZE_PROBE.md)
passed focused fixed-point gates but do not yet create object reuse, safe
function workers, or a measured compiler speedup. They are not merged into
the production compiler. The COFF-set slice partitions already-lowered
whole-project output, rejects shared-data relocations, and exceeded the
strict Stage-2 64 MiB working-set gate; it is not independent module
compilation. The restricted native link first ran freshly emitted objects
and separately passed strict Stage 3→4 self-build under 64 MiB working set
and 256 MiB private bytes. The [project-free saved-object relink](https://github.com/BoQsc/OpenC-Programming-Language/blob/3205432/SH27_SAVED_OBJECT_RELINK_EVIDENCE.md)
then authenticated on-disk COFF bytes and reproduced the two-module PE with
the source project manifest hidden. This remains a manual relink, not a
cache hit or independently compiled module. The [pre-allocation COFF reader
guard](https://github.com/BoQsc/OpenC-Programming-Language/blob/ca37261/SH27_PREALLOCATION_COFF_READER_EVIDENCE.md)
subsequently rejected a 128 MiB input normally under a 64 MiB process budget,
preserved exact valid-link behavior, and passed strict Stage 3→4 self-build.
Its [clean hosted push/manual proof](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/36259781271)
then passed all 13 strict stability checks and 20/20 byte-exact chained
rebuilds. A separate paired batch found no speed gain; no compiler-throughput
promotion is claimed.
The [selected-module IR/native emission boundary](https://github.com/BoQsc/OpenC-Programming-Language/blob/2d693f4/SH27_SELECTED_MODULE_LOWERING_EVIDENCE.md)
then passed local exact COFF/PE, three-module changed-provider reuse,
multi-source module, full rejection diagnostics, fixed-point, and strict
Stage 3→4 gates. It still parses and validates the whole project and has no
automatic cache by itself; its [hosted strict chain](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/36260957581)
passed all 13 checks and 20/20 exact rebuilds. Its subsequent [automatic
cache source](https://github.com/BoQsc/OpenC-Programming-Language/blob/2ca15c1/SH27_AUTO_MODULE_CACHE_EVIDENCE.md)
now proves authenticated hits, atomic local publication, body/declaration
invalidation, corrupt/oversized input recovery, and concurrent writers.
The 24-file/1153-function proof repairs a discovered linker scratch ceiling
and reproduces clean objects/PE/runtime under strict RAM. No-op/edit local
medians are 0.335/0.456 s versus 1.223 s full COFF, but normal native compilation
is 0.325 s: no default speed promotion. Whole-project validation, conservative
all-module interface invalidation, opt-in restrictions, and the Stage-2 strict
RAM overrun remain. [Hosted cache-source proof](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/36263328048)
passed all cache/24-file checks and strict 20/20 exact rebuilds. Hosted no-op
versus normal medians 0.178/0.188 s produce only a 10 ms paired gain, opposite
the local 11 ms regression; the independent cold speed batch failed its
gain/noise gate. No default speed promotion or new C/D parity is proved. Semantic
snapshot skipping, selective dependency keys, general data/runtime support,
real-project/default speed and final certification are still required. The subsequent
[bounded project-cache ownership cut](https://github.com/BoQsc/OpenC-Programming-Language/blob/db54808/OpenC-1.0/compiler/selfhost/SH27_FUNCTION_PROJECT_CACHE_OWNERSHIP.md)
also passed strict opt-in self-build memory and exactness, reducing
source-borrowed scratch pointers from 25 to 21. The later [five-array index
freeze](https://github.com/BoQsc/OpenC-Programming-Language/blob/af44c6b/OpenC-1.0/compiler/selfhost/SH27_FUNCTION_INDEX_FREEZE.md)
reduced that count to 16 with exact guarded self-build and invalid-input
proof. The [seven-cache ownership lanes](https://github.com/BoQsc/OpenC-Programming-Language/blob/641ea1d/OpenC-1.0/compiler/selfhost/SH27_FUNCTION_CACHE_LANES.md)
reduced source-borrowed pointers again to nine and passed strict opt-in
self-build and exact large/control cases. All remain serial and isolated;
mutable derived type IDs, spelling cache, IR buffers and deterministic merge
still prohibit function workers.
The later [private type-registry probe](https://github.com/BoQsc/OpenC-Programming-Language/blob/220e325/OpenC-1.0/compiler/selfhost/SH27_PRIVATE_TYPE_REGISTRY.md)
reduced source-borrowed pointers to eight and passed strict opt-in self-build
with a 512 KiB live-plus-spare copy per active chunk. It fails closed on late
type creation rather than remapping IDs; spelling cache, local/IR buffers,
and deterministic merges remain open.
The [final bounded local/stack cut](https://github.com/BoQsc/OpenC-Programming-Language/blob/fa78d25/OpenC-1.0/compiler/selfhost/SH27_PRIVATE_FUNCTION_VALUES.md)
passed strict opt-in proof and left four dynamic IR-buffer aliases. Their
source-sized copy exceeds observed private-memory headroom, so independent
function scheduling is an explicit no-go until one integrated capped-buffer,
global-reservation, and deterministic-merge redesign is proven.

## Objective and boundary

Finish SH-27 as a Windows x64 Hosted, independently built OpenC compiler whose
**normal production mode** is competitive with the pinned C and D compilers
on a representative, checked-in corpus. Preserve OpenC language semantics,
the byte-exact self-hosting fixed point, native/CRT-free toolchain independence,
correct executable behavior, deterministic diagnostics, and bounded process-
tree memory. Keep the published `v1.0.0` tag and its 15 assets immutable.
Linux, freestanding, ARM64, and unsolicited external reviews are not hidden
prerequisites for this Windows milestone.

The canonical generated corpus has four compile workloads plus the runtime
fixture. Its current gate is OpenC median compile/link time at most **1.25x
each of MSVC 19.44, Clang 20.1.8, DMD64 2.112.0, and LDC 1.43.0**, on the
same clean Windows runner: 20 workload/comparator checks. Executable runtime
time is reported separately; one runtime fixture cannot prove broad runtime
speed. The one-source-edit lane, four-project batch, and complete compiler
self-build must also be measured and guarded, even though today's harness
does not assign them all a C/D ratio.

At `94bee1f` the opt-in adaptive compiler's latest clean-run DMD medians are
0.616/0.316 s on `large_functions` (1.949x) and 0.412/0.233 s on
`control_flow` (1.768x). On those *same-run* DMD observations, the 1.25x
ceilings are 0.395 s and 0.291 s: about 221 ms (36%) and 121 ms (29%) of
OpenC time must disappear, respectively. These are planning budgets, not
cross-run speed claims. The fastest comparator and the actual production
policy determine the final gate; an opt-in four-worker success alone is not
closure. Earlier code-size reductions and local paired wins are real, but
they did not close these time budgets.

Two independent **normal-default, five-sample, parity-enforcing** clean
Windows runs on the parser cut (`558734b`/`844dd5f`, same compiler source)
both passed **19/20** pinned ratios and failed only `large_functions` versus
DMD. The [first run](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35884325763)
measured OpenC/DMD 0.781/0.562 s (**1.390x**); the
[second](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35885052890)
measured 0.651/0.473 s (**1.376x**). Their same-run 1.25x ceilings require
about **79 ms** and **60 ms**, respectively, from the normal-mode large-
function wall time. The internal 1.20x margin requires about 107/83 ms.
`control_flow` passed at 1.138x/1.061x. These are planning ranges, not
permission to stop at a single borderline median; the representative
project, incremental, and production-policy gates remain open.

The later adaptive-default cut at `447353c` passed its first clean Windows
normal-default parity-enforcing [workflow run](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35895744348),
including the pinned five-compiler gate. This supersedes the *earlier policy's*
19/20 result, but it is only one independent run. Its four-worker self-build
also exceeded the older benchmark harness's 256 MiB private-byte child cap
(about 283 MiB); the workflow's larger Job limit did not expose that conflict.
Treat the speed result as a provisional pass, and the complete production
memory/repeatability gate as open. Do not combine its medians with the older
serial-mode runs to claim a particular speedup.

## Execution contract: what happens next

This is one program of work, not an open-ended series of small optimizations.
The order below is the decision sequence; the numbered work packages below
specify the implementation and proof for each decision. Re-profile and choose
the largest *remaining wall-clock* cost after each accepted architectural
change. Keep all failed prototypes and their measurements disclosed.

| Gate | Required deliverable | Exit decision |
| --- | --- | --- |
| A. Baseline and DMD comparison (Step 0) | One pinned five-compiler clean-run report, 11-pair OpenC baseline samples on large functions/control flow/self-build, nonoverlapping critical-path and allocation profiles, and a written comparison of DMD's relevant parser, semantic, allocation, and code-generation paths with OpenC's equivalents. | Identify the largest avoidable cost and a design able to remove a material part of the measured gap. Source-level resemblance to DMD is not a success criterion. |
| B. Resolve the parser experiment (Step 3.1) | The precedence-climbing cut passed adaptive/serial, self-build, conformance, diagnostic, memory, and clean paired-revision proofs and was promoted to the SH-27 working proof branch. | Closed as a bounded parser improvement, **not** as C/D parity. No further parser micro-tuning without a new critical-path profile. |
| C. Fused typed-expression and assignment pipeline (Step 1) | A design and implementation that resolves symbols/types/operands during the existing walk and reuses the result in acceptance and lowering, with first-visit work counted before/after. | Exact behavior, bounded RAM, and a material end-to-end reduction on the two failing lanes; otherwise redesign rather than add caches. |
| D. Remaining front-end or backend architecture (Steps 2-4) | Refresh the profile, then implement parallel/private declaration indexing if serial parse/index dominates, or a value-location/compact-IR backend if lowering and native emission dominate. Address allocation only if measured. | The combined normal-mode wall budget closes on large functions and control flow without a self-build cliff. No sum-of-worker-time or output-size proxy can substitute for this measurement. |
| E. Production behavior (Steps 5-7) | Keep the proved adaptive chunk policy as the default; reconcile the 64 MiB working-set/256 MiB private-byte benchmark caps with the 512 MiB Job proof without hiding peaks; add real per-module/object incremental reuse; verify a versioned representative project suite. | Normal `openc` use, not an opt-in benchmark setting, is fast, deterministic, correct, and within all declared memory budgets on cold, warm, small, and large builds. |
| F. Release gate (Steps 8-9) | Two independent clean Windows parity runs, all 20 pinned comparator checks, all correctness/RAM/release-integrity checks, raw artifacts, and an updated public status. | Close SH-27 only if every mandatory gate passes; otherwise publish the exact remaining deficit and continue at the new critical path. |

As of 2026-09-23: A is **in progress** (critical-worker, declaration,
and first-visit expression-kind profiles plus a pinned DMD source comparison
exist; nonoverlapping first-visit time and allocation attribution remain
incomplete), B is **clean-CI proved**, C has an **implementation contract but
no compiler cut or speed proof**, and D has **one clean-CI proved parallel
declaration-parse cut**, but no independent repeat or backend cut. The
bounded-IR and streaming-cache changes are memory architecture, not Gate C/D
throughput cuts. E has a **normal adaptive default and two clean strict-
memory passes**, but still lacks true incremental object reuse and the representative
suite. F has **one full clean normal-default 20/20 parity run** of the
streaming compiler source; its independent repeat failed the enforced DMD
ratios on large functions and control flow. The newer parallel-declaration
source also has one clean 20/20 pass in
[run 35913434471](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35913434471),
with large functions OpenC/DMD 0.666/0.608 s (1.0954x) and control flow
0.395/0.515 s (0.7670x). The DMD large-function median was 0.250 s in the
earlier failing run, so this cross-run ratio swing does not establish robust
parity or quantify the architecture's speedup; the same-host 11-pair local
gain is the direct compiler comparison. Neither the already published
Windows 1.0 release nor a single green run changes SH-27 completion state.

The isolated packed typed-expression storage branch later passed one clean
normal-default [run 35920825397](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35920825397),
including 20/20 ratios, strict memory, fixed point, and correctness. Its
same-run large/control OpenC/DMD medians were 0.504/0.537 s and
0.313/0.430 s. This does not reverse the failed repeat on the prior source
or prove a packed-record speedup: the comparator changed markedly, and the
storage branch's local complete self-build regressed. Its literal-value
successor passed local correctness and RAM but regressed self-build by a
326 ms paired median. Its clean
[run 35924359345](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35924359345)
passed the correctness/RAM steps but failed large-function DMD parity at
0.701/0.337 s (2.0801x), a same-run public-ceiling deficit of about
280 ms; see `SH27_TYPED_EXPRESSION_CUTOVER.md`. Both remain experimental
and SH-27 remains active.

An independent source-evidence flow cut at `884c1ef` gates the inapplicable
ownership analysis for scalar functions. It passed local fixed point,
278/278 conformance, exact worker/invalid diagnostics, strict 20/20 RAM,
and eleven-pair same-host comparisons. Paired medians were -9 ms large,
-26 ms control, and -47 ms complete self-build; see
`SH27_FLOW_FRONT_END_EVIDENCE.md`. This is a material partial reduction on
control flow, not large-function parity closure.

Its first clean [run 35926214112](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35926214112)
subsequently passed all correctness/RAM steps and 20/20 normal-default
ratios; same-run large/control OpenC/DMD medians were 0.490/0.570 s and
0.369/0.516 s. This is one clean pass of that source, not repeatable parity
or a cross-run measurement of the flow cut's speedup.

The follow-on scalar-source flow cut at `738bea3` conservatively skips the
entire flow validator when an error-free retained parse proves every local
initialized and scalar and no applicable stateful rule remains. It passed
local fixed point, 278/278 conformance, exact worker/invalid diagnostics,
strict 20/20 RAM, and eleven-pair same-host comparisons: -93 ms large
(10/11 wins), -42 ms control (11/11), and flat -2 ms self-build. This is a
material local wall-time reduction, **not** a cross-run C/D parity claim;
see `SH27_SCALAR_FLOW_EVIDENCE.md`. Its first clean
[run 35928451776](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35928451776)
passed fixed-point, conformance, strict memory, x64, worker/diagnostic,
and historical speed steps, but failed enforced normal-default DMD parity
on large functions at 0.451/0.315 s (1.4317x) and control flow at
0.272/0.211 s (1.2891x). The other 18 ratios passed. Its same-run public
1.25x deficits are 57.25/8.25 ms, with 73.0/18.8 ms required for the
internal 1.20x margin. This candidate has no clean 20/20 pass; final-source
repeatability and the remaining architecture stay open.

The parser cut in gate B has passed local and clean Windows proof. Locally, the fast
precedence-climbing version preserved parser output/diagnostics on 503
checked-in `.p` sources and fixtures and produced 11/11 same-host wins on
`large_functions` (median paired delta -46 ms) and 9/11 on `control_flow`
(-9 ms). Clean 11-pair Windows runs against its pre-change compiler measured
-39 ms (11/11 wins) and -4 ms (6/11 wins) in normal serial mode; the full
native proof also passed. This establishes a bounded parser improvement,
not a new normal-default C/D parity result. The cut must not displace gate
C's much larger semantic redesign.

For each gate, record four states: **not started**, **experimental**,
**locally proved**, or **clean-CI proved**. Never mark a gate done from a
green evidence-only workflow. A change earns production promotion only when
it either removes at least 10% of the *then-measured* failing-lane gap or is
an indispensable enabling step for the architectural design, while keeping
the other lanes within the 5% regression guard. One bounded experiment may
test a narrower idea; repeated sub-threshold instruction or cache tweaks are
not the SH-27 strategy. The final 1.25x gate, not this screening rule, decides
completion.

## Execution rules

1. Work from the critical-path profile, not from source-code aesthetics or
   executable size. Every performance change needs an explicit hypothesis,
   a phase budget, an order-alternated same-host A/B comparison, and a
   correctness/RAM proof. Reject candidates that merely move a counter or
   are within noise. Record rejected experiments.
2. Keep the baseline compiler and candidate on the same host, same source
   bytes, flags, safety semantics, cache state, and Windows Job limits.
   Publish commands, per-run samples, medians, p95, compiler hashes, output
   hashes, and peak parent/whole-Job memory. Do not add summed worker CPU
   times to wall-clock phases or compare medians from different CI runs.
3. Allow no silent safety-mode change to chase DMD's `-release` /
   `-boundscheck=off` timings. Preserve OpenC checked arithmetic, cleanup,
   ABI, and diagnostic behavior. Document unavoidable semantic differences
   beside each comparator result.
4. Keep each candidate on an isolated branch until all local gates pass.
   A real regression or an inconclusive speed result means revert/rework the
   candidate, not relax the corpus. Keep Python as an optional bounded test
   orchestrator; it must not become a normal compiler dependency.

## Ordered work packages and decision gates

### 0. Freeze an honest baseline and time budget

- Preserve a known-good commit and current-stage compiler binary; record
  compiler/toolchain identities, Windows runner image, CPU, source/corpus
  fingerprints, command lines, cache policy, and selected source-chunk mode.
- Run the five-compiler corpus and the three important OpenC workloads
  (`large_functions`, `control_flow`, complete self-build) with raw samples.
  Retain serial, explicit two/four-chunk, and adaptive results separately.
- Extend the existing `--timings` record with nonoverlapping *wall* critical-
  path attribution for project/load, declaration/indexing, resolution,
  acceptance/flow, IR lowering, native emission, PE/link/write, and worker
  launch/merge. Record instruction and allocation counts, temporary bytes,
  file I/O, and output-section sizes. Use a profiler to validate counters;
  keep profiling out of timed samples.
- Calculate required milliseconds against **each** comparator on the same
  run. Rank costs by wall time and scaling with source files, declarations,
  IR instructions, and output bytes. First gate: explain at least 80% of the
  target-lane wall time and identify the largest avoidable critical path.
- Inspect the pinned DMD implementation and capture a short source-linked
  comparison of its expression parsing, symbol/type resolution, memory
  allocation, IR/code-generation handoff, and object/link pipeline against
  OpenC's corresponding paths. Identify data-structure and pass-count
  differences, then test the strongest applicable hypothesis in OpenC.
  Do not assume that copying DMD's implementation or importing a D runtime
  is appropriate for OpenC's semantics and independent native toolchain.

The first critical-worker measurements are in
`SH27_CRITICAL_PATH_EVIDENCE.md`. They point to first-time semantic acceptance,
especially assignments, as the first redesign target. A follow-up distinct-node
profile found **zero repeated uncached type evaluations** in the three measured
workloads. The problem is not an unfilled memoization cache; it is the cost of
the first visit and the surrounding acceptance/index/lowering architecture.
Keep validating that result on clean runners; do not promote a local
three/five-sample profile to a universal performance claim.

### 1. Redesign first-time semantic acceptance and type inference

The slowest native chunk currently spends more time in semantic acceptance
than in native emission on both failing generated workloads. Treat the
assignment pass and its first-time recursive type inference as one
architectural problem, not a cache-tuning exercise:

1. Keep the diagnostic-only unique/repeated type-query counter and count
   first-visit work by expression kind, name/symbol probe, operand lookup,
   source-text parse, and expected-type-dependent fallback. Distinguish time
   within the first semantic visit from the number of visits; a high uncached
   count alone cannot justify memoization.
2. Build a compact per-source typed-expression record **during source
   acceptance**, using explicit dependency-aware evaluation rather than an
   extra full prepass. The current compiler has separate rule-family passes
   and mixed syntax creation order (calls precede their arguments); it does
   not already have a dependency-ordered semantic walk. Follow
   `SH27_TYPED_EXPRESSION_CUTOVER.md` for the required cutover.
   Carry direct child/operand and resolved-symbol references into that record,
   plus the expectation-independent type or a tagged contextual constraint.
   Preserve the exact fallback for expected-type-sensitive literals and
   aggregates. Do not cache a failed lookup across contexts that can resolve
   later. The target is fewer source rescans, repeated function-context
   selections, per-node dispatches, and transient allocations on first visit.
   Do not promote a parser-edge sidecar alone: the isolated 11-pair experiment
   in `SH27_CRITICAL_PATH_EVIDENCE.md` regressed large functions and did not
   reduce critical acceptance time. The record must replace work across
   acceptance and lowering, not merely retain two child indexes.
3. Validate assignment lvalue/mutability/conversion rules as typed records
   are produced, then let lowering consume those same records. Avoid a second
   parse, type scan, or full expression walk. Preserve diagnostic text and
   source order, including invalid input.
4. Prove equivalent `check`, serial and parallel `artifact`, self-build,
   overflow/aggregate behavior, and bounded memory. Run 11 same-host pairs
   on both failing lanes and self-build; require a material wall-time gain,
   not merely fewer internal type-query counters. Re-profile immediately.

If acceptance ceases to dominate but parity still fails, select the next
work package from the refreshed critical path. A narrow corpus-specific fast
path is not completion.

### 2. Choose and prove a backend redesign, not another peephole

The generated large/control workloads have many arithmetic and store/load
instructions; the current emitter often materializes SSA values in stack
slots. After Step 1, prototype a *per-basic-block value-location model* if
lowering/emission is a material remaining wall-time cost **and exceeds the
remaining declaration/index cost on the refreshed critical path**. Otherwise
execute Step 3 first. The Step 2/3 numbers are work-package labels, not a
mandate to optimize the backend before a larger serial front-end cost. The
value-location model keeps short-
lived values in registers, writes directly to final destinations where
legal, and spills only for liveness, calls, address-taking, or pressure.

1. Inventory IR use counts, value lifetimes, spill/reload pairs, emitted
   bytes, and time per function; identify the highest-volume patterns.
2. Define liveness, register ownership, call-clobber, flags/overflow, stack
   alignment, unwind, and fallback rules. Keep an explicit slow path for
   unsupported aggregates or control flow rather than guessing semantics.
3. Implement block-local allocation/coalescing first, then cross-block
   value transport only if the profile justifies it. Avoid generating
   redundant IR temporaries at the lowerer/emitter boundary.
4. Prove integer overflow traps, signed/unsigned widths, branches, calls,
   callbacks, aggregates, x64 unwind, and binary reproducibility. Compare
   emitted instruction counts and end-to-end times, not code size alone.

If this does not remove a substantial share of the measured large/control
gap, proceed to the already specified deeper redesign: a compact typed
per-function IR in bounded scratch storage, with one lowering traversal and
one native-emission traversal, replacing repeated tree walks and transient
stack-slot materialization. Prototype on the two failing workloads before
migrating the full compiler. Keep the old pipeline behind a test-only
comparison until exact output/behavior and speed gates pass.

### 3. Remove serial front-end work that remains on the critical path

The latest local 11-pair large-function baseline attributed a 297 ms median
to top-level declarations, versus 172 ms median acceptance on the critical
native worker. These are differently scoped wall observations, not additive
subphases, but declarations are too large to leave automatically behind the
backend. Treat this package as the immediate successor to Step 1 if a clean
profile confirms the serial declaration path remains dominant.

1. Profile declaration collection and first semantic inference by source
   file and pass. Check whether the same syntax, symbol, type, or export data
   is recomputed; eliminate repeated scans through stable indexed records.
   The first two opt-in subprofiles attribute roughly 200 ms of large-function
   declaration work to parsing and 78-94 ms to lex/alloc; source reread and
   type predeclaration are negligible at the millisecond clock resolution.
   Prototype a single precedence-climbing expression walk in place of the
   current ten-level recursive operator dispatch before adding declaration
   workers. Prove exact AST/diagnostic output and material paired wall gain;
   if it fails, retain the counterexample and choose the next measured cost.
2. Parse/index independent source declarations in private worker contexts;
   merge symbol records and diagnostics in source order, then perform the
   genuinely cross-file resolution once. Cross-file cycles, duplicate names,
   source-order diagnostics, and invalid input must match serial behavior.
3. Apply parallel acceptance/flow only where the dependency graph proves
   independence. Keep the deterministic serial fallback for thread launch,
   allocation, or unsupported-input failure.
4. Attribute the saved *wall* time and process-tree memory against the
   Step 0 budget. Do not call summed worker-time reductions a compiler win.

The assignment/inference redesign is first on current evidence. Parallel
declarations and backend work follow the refreshed critical path; their final
integration needs a fresh paired comparison because wins need not add linearly.

### 4. Make temporary allocation bounded and cheap

- Count allocation calls/bytes/lifetimes in the hot phases before changing
  the allocator. Test per-invocation or per-worker scratch arenas only if
  allocator overhead or fragmentation is material. In pinned DMD 2.112.0,
  [`main.d`](https://github.com/dlang/dmd/blob/v2.112.0/compiler/src/dmd/main.d)
  selects a bump-pointer path and disables its GC by default unless
  `-lowmem` is supplied; [`root/rmem.d`](https://github.com/dlang/dmd/blob/v2.112.0/compiler/src/dmd/root/rmem.d)
  implements that path in large malloc-backed chunks, while its separate
  `Mem.xmalloc` helpers may use GC or malloc. The DMD choice is an applicable
  architecture to measure against, **not** evidence that allocation explains
  OpenC's entire wall-time gap or a reason to trade away RAM safety.
- Reuse bounded buffers and pre-size IR/output structures from checked
  counts. Define overflow handling, arena reset points, and ownership when a
  worker fails. Retain the 256 MiB single-allocation, 512 MiB live-byte, and
  512 MiB Windows Job/process memory protections already used in proofs.
- Verify no long-lived references escape an arena and no hidden process (or
  PowerShell/Python harness) consumes unbounded memory. Promote only if
  measured wall time improves without a material RAM regression.

The experimental `codex/sh27-bounded-ir` cut replaced source-byte-derived
IR capacities with syntax-count estimates plus growing buffers. In local
probes, peak whole-Job private bytes fell from roughly 283-285 to 247-258
MiB on self-build, 306 to 164-171 MiB on large functions, and 162 to 81-86
MiB on control flow; the ranges are from different local verification
invocations, not paired medians. Exact fixed-point and native
serial/parallel output checks passed.
An 11-pair default-mode self-build comparison was flat (+19 ms candidate
median paired delta; 5 candidate wins). However, the 20-run legacy self-build
benchmark still intermittently exceeds its 64 MiB child working-set cap.
Forcing two workers passes that cap but regresses self-build by about 1.3 s
in paired measurement. Thus neither the IR cut alone nor a two-worker policy
closes the memory gate. The subsequent streaming parse-cache lifetime cut on
`codex/sh27-streaming-parse-cache` passed the strict 20-generation chain
locally with four workers (peak 251.1 MB private, 55.2 MB working set) and
preserved exact output/diagnostics; see `SH27_STREAMING_PARSE_CACHE_EVIDENCE.md`.
Its first paired self-build speed series was borderline, but a second was
flat. One full clean CI run has passed all gates including strict memory and
normal-default C/D parity; an earlier clean run had an intermittent worker-
proof failure. The memory gate is **clean-CI proved once, not yet promoted**.
Require an independent repeat and investigate any recurrence. Do not silently
raise or disable a guard to obtain a green result.

### 5. Turn adaptive parallelism into the measured production policy

- Re-run serial/two/four-worker comparisons on the generated corpus, complete
  self-build, and real projects after the architectural changes. Choose
  chunk counts from source bytes, file count, predicted live memory, and
  measured launch/merge cost; cap workers by the Job budget.
- Expand exact-output and exact-diagnostic proofs to invalid imports,
  duplicate declarations, cycles, multiple errors, thread-launch failure,
  low-memory failure, and one-file fallback. Test repeatability across
  multiple runner CPU counts.
- When the policy wins with bounded memory and no regression on small builds,
  make it the default for normal `openc build`/`artifact`; retain an explicit
  serial switch for diagnosis. The main production workflow must measure
  this default, not only an opt-in `--source-chunks` lane.

### 6. Deliver genuine one-source incremental reuse

Today's one-source-edit lane re-invokes the full compiler; it is not proof of
object reuse. Separate full rebuilds from warm incremental builds.

1. Build a source/import dependency and public-interface fingerprint graph.
   Define invalidation for changed implementation, changed exported API,
   compiler version, target/ABI, flags, generated bindings, and cache schema.
2. Persist deterministic per-module or per-chunk COFF objects plus the
   dependency manifest. Write cache entries atomically; detect corrupt or
   stale entries and fall back to full compilation.
3. Link reused objects through the existing native linker and prove warm
   output, diagnostics, imports, and execution equal a clean rebuild.
4. Benchmark no-op, leaf edit, public-interface edit, and clean rebuild for
   24-file and representative projects. Record cache hits, bytes read, wall
   time, and peak Job memory. Do not claim an incremental speedup from a
   comment-only edit without proving object reuse.

### 7. Expand beyond synthetic workloads without moving the goalposts

- Keep `benchmarks/sh27/CORPUS.json` v1 and its 20 ratios as a regression
  contract. Add a separately versioned bounded project suite: a small CLI,
  a multi-module medium build, and the compiler self-build, with real imports,
  generics/aggregates/control flow, diagnostics, and file/runtime behavior.
- For cross-language projects, check in equivalent C/D/OpenC source and
  verify functional outputs and comparable compilation/link work. Report
  language-specific projects separately if equivalence cannot be established.
- Add scaling points for function size and file count; report cold and warm
  builds, no-op/one-file edits, four-project throughput, executable runtime,
  output size, and parent/whole-Job peak memory. Avoid collapsing all these
  measurements into one flattering score.
- Require the representative suite to have no material unreported cliff.
  Any new deficit gets a named reproducer, owner work package, and gate before
  SH-27 closure; do not silently discard it.

### 8. Enforce parity and every safety gate on clean Windows CI

1. For candidate selection, use at least 11 order-alternated same-host pairs
   against the previous compiler on both failing workloads and self-build;
   require a meaningful gain on the targeted lane and at most 5% regression
   on the others. Keep raw data and failure cases.
2. Require byte-exact Stage 2/Stage 3 self-host fixed point, all 278 current
   conformance fixtures, 25/25 x64 substrate checks, integer-boundary and
   aggregate regressions, deterministic serial/parallel outputs and errors,
   successful execution, and the existing Job/RAM/disk guards.
3. Run the full pinned five-compiler matrix in the **normal default mode**
   with `--require-all --enforce-parity` on two independent clean Windows
   workflow runs, with at least five samples per compile lane (split jobs or
   increase the timeout if needed). Use an internal target of <=1.20x to
   leave noise margin, while
   1.25x remains the public pass/fail line. A single green median at 1.249x
   is not robust evidence; investigate borderline lanes.
4. Convert the automatic commit workflow from evidence-only to blocking
   parity only *after* the candidate actually passes. Keep full JSON artifacts
   on failure. Test the workflow's deliberate parity-failure path so a green
   job cannot mislabel `EVIDENCE_COMPLETE_DEFICIT` as completion.

### 9. Close SH-27 without rewriting release history

- Re-run `scripts/verify_sh27_post_release.py` against the immutable public
  tag/assets; publish its actual result. Keep external review invitations
  and five finding tracks active, route any received security/errata reports,
  and resolve release-critical findings. Do not require a reviewer response
  that has not arrived, and do not claim independent certification.
- Publish the final versioned corpus, commands, compiler/runner pins, raw
  artifacts, all 20 ratio checks, self-build/incremental/project results,
  memory and correctness checks, and known limitations. Update `ROADMAP.md`
  and the chronological SH-27 evidence only with verified results.
- Mark SH-27 complete only when Steps 5-8 pass in the shipped/default Windows
  compiler and the release-integrity/review-handling duties above pass. If a
  sustained >1.25x lane or a material real-project cliff remains, the honest
  state is **SH-27 active**, even if every other CI job is green. Publish a
  new version through the ordinary owner-authorized release process; never
  mutate `v1.0.0` or its artifacts.

## Immediate next decision

Stop parser/cache/peephole micro-tuning. The default adaptive policy now has
one full clean 20/20 comparator and strict-memory success for the streaming
compiler source, but the next clean run failed DMD parity. Execute these in
order:

1. **Freeze and repeat the current production baseline.** Preserve
   `codex/sh27-streaming-parse-cache` at `e21e6ea`. Its first full clean
   [run](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35903863226)
   passed the strict 20-generation memory chain and normal-default parity.
   The independent
   [repeat](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35906561161)
   completed its strict memory, fixed-point, conformance, x64, exact-worker,
   and historical speed steps, but failed normal-default DMD parity. Public
   check annotations give large functions 0.484/0.250 s = **1.936x** and
   control flow 0.276/0.200 s = **1.380x**. Their same-run 1.25x ceilings
   are 0.3125/0.250 s, requiring about **172/26 ms** respectively; 1.20x
   margin would require **184/36 ms**. Do not average these ratios with the
   previous green runner or retry until a favorable DMD sample appears.
   Treat this as a genuine architectural throughput deficit. The strict
   64 MiB working-set / 256 MiB child-private / 512 MiB Job guards stay.
2. **Finish critical-path attribution before editing the semantic core.**
   On that frozen compiler, capture same-run pinned comparator time budgets
   and nonoverlapping wall attribution for large functions, control flow,
   and self-build. Split first semantic visits into symbol lookup, operand
   discovery, contextual typing, assignment checks, and allocations. The
   local default profile already shows 235 ms serial declarations and 187 ms
   critical-worker acceptance on large functions; worker and top-level times
   are nested, not additive. The newer local eleven-pair baseline measured
   188 ms serial declarations and 312 ms worker-stage wall (medians), also
   with different host conditions. State the milliseconds each architecture
   can plausibly remove and the exact A/B acceptance threshold before
   implementation. Parallel declaration parsing and semantic fusion must be
   evaluated as *jointly necessary* for the observed 172 ms clean-run gap;
   neither should be declared sufficient from a local phase counter.
3. **Repeat the parallel-declaration architecture on clean Windows.** The
   isolated cut in `SH27_PARALLEL_DECLARATIONS_EVIDENCE.md` parses independent
   source files concurrently, then predeclares and merges in the old source
   order. Final local paired medians improved 108 ms on large functions and 16 ms
   on control flow, with exact outputs, conformance, and strict RAM proof.
   First clean pinned comparator, strict-memory, and self-build speed guards
   passed in run 35913434471, including 20/20 normal-default ratios.
   Require an independent same-source clean repeat before treating this as
   stable parity. The local result is not a cross-run C/D parity claim.
4. **Implement Gate C as one architectural cutover.** Build dependency-ordered
   typed-expression records *during* acceptance, validate assignments from
   those records, and lower from the same records. Follow
   `SH27_TYPED_EXPRESSION_CUTOVER.md`; it includes source-order, contextual
   typing, invalid-input, and rollback proof. Compare 11 order-alternated
   pairs on large/control/self-build, then re-profile. A counter-only or
   sub-threshold change is rejected. The selected-function cache experiment
   was rejected after -5 ms large-function and +10 ms control-flow paired
   medians; it is not part of the compiler.
5. **Choose the remaining architecture from the new profile.** After the
   declaration and semantic cuts, if lowering/emission dominates, do the
   value-location or compact-IR backend (Step 2). Otherwise target the
   largest newly measured front-end cost. Repeat until the 1.20x internal
   target is robust across the pinned corpus with no >5% protected-lane
   regression.
6. **Finish the production model.** Recheck the adaptive default after each
   architecture change; implement actual object-level incremental reuse with
   dependency invalidation, atomic cache entries, and clean-build-equivalent
   outputs. Add the separately versioned representative project suite and
   guard cold/warm/edit/self-build time, executable behavior, and whole-Job
   RAM. Synthetic 20/20 alone is not a substitute for these steps.
7. **Certify and ship only after all gates hold together.** Require two
   independent clean Windows normal-default 20/20 parity runs of the *final*
   compiler source, exact fixed point, all conformance/native/diagnostic and
   RAM gates, incremental/project checks, and immutable `v1.0.0` release
   integrity. Publish raw evidence, current limitations, and a new version
   through the authorized release path. Only then mark SH-27 complete.

Each numbered decision is independently falsifiable. If the observed critical
path or memory ownership contradicts its hypothesis, record the failed
prototype and redesign that package; do not replace the program with an
indefinite sequence of tiny threshold changes.
