# SH-27 throughput candidate portfolio

Status: **no compiler-speed candidate promoted; SH-27 remains open**.
This file is the short decision index for broad experiments. Detailed raw
samples are in ignored `build-output/selfhost-sh27/` locally or the linked
GitHub Actions artifact. A local result is a triage result, not the clean
20-ratio C/D parity certificate.

## Shared decision contract

All executable candidates start from compiler source `6794d56` (same compiler
source as the `e4e4e9a` worker-profile baseline), keep their source in
isolated branches, and use guarded Stage 2/3 fixed point before comparison.
The [matrix runner](benchmark_sh27_candidate_matrix.py) freezes the SH-27
corpus, runs 11 adjacent baseline/candidate pairs per large/control workload,
rotates order, runs a baseline-vs-baseline null control, and keeps compiler
jobs serial under the process-tree memory/time guards. It requires exact
executed exit/stdout/stderr and deterministic candidate artifacts; only an
explicit codegen policy allows cross-revision PE bytes to differ. Selection
also requires a median gain beyond the null absolute paired delta and a
majority of wins. The [clean batch workflow](../../../.github/workflows/openc-performance-batch.yml)
can reproduce a frozen branch batch on one Windows runner; it is not the
final five-compiler parity gate.

| Independent candidate | Large paired median / wins / null floor | Control paired median / wins / null floor | Decision |
| --- | --- | --- | --- |
| Indexed call summary | -138 ms / 7 of 11 / 249 ms | +21 ms / 5 of 11 / 110 ms | Reject: no signal; call subphase did not shrink. |
| Function-level lowering scheduler | Optimistic zero-overhead model: at most 70 ms | Optimistic model: at most 16 ms | Defer: no immutable source facts or RAM-safe scratch ownership. |
| Packed typed record + batched old validators | 0 ms / 5 of 11 / 154 ms | +7 ms / 5 of 11 / 80 ms | Reject: displaced timers; first-visit work unchanged. |
| Direct native slot layout | -46 ms / 6 of 11 / 136 ms | +11 ms / 4 of 11 / 34 ms | Reject: no whole-compile signal; strict RAM unproved. |
| Adjacent direct-value handoff | -121 ms / 7 of 11 / 80 ms | -29 ms / 8 of 11 / 38 ms | Reject as speed proof: large corpus removes only one pair; apparent win lacks causation. |
| RAX through immediate arithmetic | +7 ms / 5 of 11 / 79 ms | +14 ms / 4 of 11 / 23 ms | Reject for compile throughput despite 31% less large native code. |
| Eager typed-operation pipeline | +2 ms / 5 of 11 / 50 ms | -6 ms / 7 of 11 / 11 ms | Reject: extra traversal repeats semantic work. |
| Scalar validation fused into lowering | Local -98 ms / 7 of 11 / 84 ms; hosted -2 ms / 6 of 11 / 10 ms | Local -15 ms / 6 of 11 / 43 ms; hosted +10 ms / 3 of 11 / 10 ms | Reject speed claim: real scans removed, 278/278 and strict 20/20 pass, clean gain fails. |
| Compact child/name sidecar | Existing indexed/cached paths already serve lowering; no source speed run | Same structural no-go | Reject before implementation: duplicate indexes add memory, not a demonstrated critical-path cut. |
| Per-source scratch arena/reuse | Optimistic heap proxy suggests roughly 6–12 ms critical-worker opportunity | Roughly 1–3 ms critical-worker opportunity | Reject before compiler build: control opportunity below clean 10 ms null; zeroed payload and RAM risk remain. |
| Same-type scalar binary fast path | Local -29 ms / 7 of 11 / 70 ms; hosted -1 ms / 7 of 11 / 5 ms | Local -14 ms / 8 of 11 / 38 ms; hosted -1 ms / 7 of 11 / 2 ms | Reject: clean effect below null on both lanes; no first-visit type work removed. |
| Lazy tagged typed-operation tranche | -30 ms / 7 of 11 / 65 ms | +9 ms / 4 of 11 / 40 ms | Reject speed claim: 142k/27k old resolver calls bypassed, but equivalent first-visit work and source-lifetime caches remain. |
| Typed literal/operator handoff | -7 ms / 6 of 11 / 60 ms | -3 ms / 6 of 11 / 71 ms | Reject: 18,613 literal and 15,061 operator reuses in self-build, exact outputs, but whole-wall gain below null on both lanes. |

The table records *candidate minus baseline*, so negative is faster. The null
floor is same-run baseline-vs-baseline median absolute paired jitter. A
subphase counter or native code-size reduction is not interchangeable with
whole compiler wall time. Detailed evidence is in
`SH27_CALL_PATH_BATCH_EVIDENCE.md`,
`SH27_FUNCTION_SCHEDULING_DECISION.md`,
`SH27_FUNCTION_PIPELINE_BLOCKER.md`,
`SH27_TYPED_OPS_BATCH_CANDIDATE.md`,
`SH27_BACKEND_VALUE_LOCATION_EVIDENCE.md`,
`SH27_DIRECT_VALUE_PATH_EVIDENCE.md`, and
`SH27_TYPED_PIPELINE_REJECTION.md`,
`SH27_LOWERING_FUSION_EVIDENCE.md`, and
`SH27_COMPACT_CHILD_NAME_SIDECAR_NO_GO.md`, and
`SH27_SCRATCH_OWNERSHIP_NO_GO.md`, and
`SH27_SCALAR_FAST_PATH_NO_GO.md`, and
`SH27_LAZY_TYPED_TRANCHE_EVIDENCE.md`. The opt-in first-visit probe and
its bounded hypotheses are in `SH27_ACCEPTANCE_FIRST_VISIT_PROFILE_EVIDENCE.md`.
The later [typed-handoff rejection](https://github.com/BoQsc/OpenC-Programming-Language/blob/b1d0b26/OpenC-1.0/compiler/selfhost/SH27_TYPED_HANDOFF_REJECTION.md)
shows why cheap fact reuse does not replace the full semantic/IR traversal.
The later high-resolution worker probe is diagnostic-only because it
perturbed measured wall and missed the strict 64 MiB self-build working-set
proof; see `SH27_QPC_CRITICAL_WORKER_PROFILE_EVIDENCE.md`.
The isolated [interface-fingerprint candidate](https://github.com/BoQsc/OpenC-Programming-Language/blob/c0b2343/SH27_INTERFACE_FINGERPRINT_EVIDENCE.md)
passed 11 falsification checks and guarded Stage 2/3 byte identity. It is an
opt-in public-interface projection only: no cache hit, independent COFF
object, or incremental throughput claim is made. It remains off the
production compiler branch until the artifact/relink architecture is ready.
The follow-on [stable COFF identity candidate](https://github.com/BoQsc/OpenC-Programming-Language/blob/f68c65f/SH27_STABLE_COFF_IDENTITY_EVIDENCE.md)
passed guarded fixed point and ten identity/default-parity checks. Its opt-in
COFF names are independent of unrelated insertion and body edits, but the
writer still emits one whole-project object with numeric internal relocation
targets. It is not module reuse or a clean-build speedup.
The [opt-in per-module COFF-set slice](https://github.com/BoQsc/OpenC-Programming-Language/blob/bd0a497/SH27_MODULE_COFF_SET_EVIDENCE.md)
now emits stable cross-module externs and one object per function-bearing
module after whole-project acceptance/lowering. A two-object executable,
body-edit isolation, deterministic bytes, incomplete-manifest failure
recovery, and guarded Stage 2/3 fixed point passed. It still has no
independent module compilation, native multi-object relink, atomic validated
cache, or measured reuse; shared `.data` relocations fail closed. Stage 2
exceeded the strict 64 MiB working-set gate, so this remains isolated.
An isolated opt-in `PreparedSource`/`WorkerScratch` boundary passed guarded
fixed point and focused exact artifacts, but it is serial and has no speed
claim; see `SH27_PREPARED_SOURCE_BOUNDARY.md`. The next function-worker audit
found 25 still-aliased source-owned pointers, late type-registry appends, and
unmerged diagnostic/value-ID state, so no unsafe scheduler was launched; see
`SH27_FUNCTION_WORK_OWNERSHIP_GATE.md`. The concrete next cut is immutable
type closure and bounded per-worker cache ownership, not a worker-count flag.
An isolated [function type-freeze probe](https://github.com/BoQsc/OpenC-Programming-Language/blob/c97e28e/OpenC-1.0/compiler/selfhost/SH27_FUNCTION_TYPE_FREEZE_PROBE.md)
removed the two observed late pointer types in the nested fixture and passed
guarded fixed point and generated large/control exactness. It remains an
opt-in, post-function fail-closed assertion, not an immutable registry or
parallel scheduler; other source-wide caches and result merging still block
workers.
The follow-on [bounded four-cache ownership cut](https://github.com/BoQsc/OpenC-Programming-Language/blob/db54808/OpenC-1.0/compiler/selfhost/SH27_FUNCTION_PROJECT_CACHE_OWNERSHIP.md)
passed guarded fixed point, exact self-build, generated/invalid checks, and
strict 256/64 MiB self-build memory. It reduced the source-borrowed scratch
pointer count from 25 to 21, with a maximum 120,520-byte live cache copy per
source. It is still serial and has no speed claim; type/first-visit caches,
IR, SSA, output, and diagnostics remain shared.
The next [five-array index freeze](https://github.com/BoQsc/OpenC-Programming-Language/blob/af44c6b/OpenC-1.0/compiler/selfhost/SH27_FUNCTION_INDEX_FREEZE.md)
passed guarded fixed point, strict opt-in self-build, exact large/control,
and focused calls/duplicate/cycle/invalid diagnostics. It reduced remaining
source-borrowed scratch pointers from 21 to 16. Its readiness and writer-path
audit are the safety argument; the post-lowering checksum is diagnostic, not
collision-free proof. Function workers are still prohibited.
The [seven-cache ownership lanes](https://github.com/BoQsc/OpenC-Programming-Language/blob/641ea1d/OpenC-1.0/compiler/selfhost/SH27_FUNCTION_CACHE_LANES.md)
then cut source-borrowed pointers from 16 to 9 with fixed disjoint function
spans, pre-write guards, isolated reads, byte-exact fixed point, focused and
large/control correctness, and strict opt-in self-build at 260,612,096 bytes
private / 60,579,840 bytes working set. The mutable type registry, spelling
cache, seven local/IR buffers, and deterministic merge still block workers;
only about 7.8 MiB of strict private-byte headroom remained in that proof.
The subsequent [private type-registry probe](https://github.com/BoQsc/OpenC-Programming-Language/blob/220e325/OpenC-1.0/compiler/selfhost/SH27_PRIVATE_TYPE_REGISTRY.md)
copies only live type records plus one spare into at most 512 KiB per active
source chunk and fails closed on a late derived type. It passed byte-exact
fixed point, strict opt-in self-build (261,132,288 private / 60,792,832
working-set bytes), focused cases, and large/control equivalence. This cuts
source-borrowed pointers from nine to eight. It is not a general type-ID
remapper; spelling cache, seven local/IR buffers, and deterministic merge
still forbid function workers, with about 7.3 MiB private headroom observed.

## Next decisive batch

The unchanged production compiler now has **two** independent clean hosted
20/20 normal-default parity passes, a local strict 20-generation chain, and
278/278 conformance. A [pinned hosted three-language medium-app proof](SH27_REPRESENTATIVE_HOSTED_PROOF.md)
also passed 3/3 cold, warm, and edit repetitions with exact executed output.
That permits four independent engineering tracks to
advance concurrently, without treating a noisy local micro-gain as progress:

1. **Whole semantic/IR cut:** the literal/operator handoff proved reuse but
   not elapsed-time savings. Replace a substantial first-visit
   assignment/binary acceptance traversal with a typed function-local IR
   handoff that lowering consumes, while preserving exact invalid-diagnostic
   order. Measure removed passes and end-to-end guarded wall time against a
   baseline-vs-baseline null; no new full-size cache or eager extra pass.
   The [isolated implementation contract](https://github.com/BoQsc/OpenC-Programming-Language/blob/fc04d72/OpenC-1.0/compiler/selfhost/SH27_FUNCTION_SEMANTIC_IR_DESIGN.md)
   specifies the all-or-nothing source barrier, expected-type/call ordering,
   legacy diagnostic replay, and kill criteria before code is judged.
   The [Phase B1 proof](https://github.com/BoQsc/OpenC-Programming-Language/blob/8489962/OpenC-1.0/compiler/selfhost/SH27_FUNCTION_SEMANTIC_IR_DESIGN.md)
   removes both legacy sweeps for 7/8 generated large-function sources
   (21,504 assignments and 28,672 binaries), with exact PE/runtime and
   guarded fixed point. The excluded source 0 was the historical critical
   call-heavy worker; control/self-build coverage, strict final RAM, and
   whole-wall speed remain unproved. Widen the visitor before timing.
   The [Phase B2 falsification](https://github.com/BoQsc/OpenC-Programming-Language/blob/89dd8d4/OpenC-1.0/compiler/selfhost/SH27_FUNCTION_SEMANTIC_IR_B2_EVIDENCE.md)
   achieved exact 8/8 large and 4/4 control source coverage but was a
   **two-lane NO-GO**: 11-pair/null large improved 16 ms (10/11 wins;
   9 ms null), while control regressed 10 ms (2/11 wins; 11 ms null).
   Pointer acceptance and IR lowering absorbed first-visit work; self-build
   remained 0/223 fast sources. Its 512 MiB matrix guard is not the strict
   64/256 MiB self-build gate. The next batch must remove migrated work and
   categorize self-build exclusions, not promote the removed-sweep counter.
2. **Real incremental native artifacts:** the isolated interface projection,
   stable COFF names, and post-lowering module COFF set are prerequisites.
   Make acceptance/lowering truly independent by module, handle shared data,
   implement native multi-COFF relink and atomic content-validated reuse.
   A full-source hash or warm timer with no actual module hits fails this track.
3. **Safe function ownership:** opt-in serial PreparedSource, type-registry
   probe, four bounded project-cache copies, five frozen source indexes, and
   seven guarded function cache lanes, and the bounded private type copy are
   exact, but eight source-borrowed scratch pointer fields plus
   IR/output/diagnostic state remain mutable and shared. Give
   each function worker bounded independent scratch before attempting
   deterministic scheduling.
   Require strict 64/256 MiB child and 512 MiB Job proof and a same-run
   end-to-end speed signal; an opt-in flag alone is no throughput result.
4. **Representative projects:** keep the 20-ratio generated corpus unchanged;
   use the new guarded CLI/file-audit/compiler suite for cold/warm/edit and
   exact execution. Pinned hosted C/D/OpenC medium-app equivalence now passes
   twice, but the fixture is small and benchmark-authored. Add a retained
   user project and larger multi-module cases before claiming real-world
   representativeness.

After any compiler source promotion, rerun complete diagnostics/runtime/ABI,
the strict 20-chain, and **two new independent** normal-default hosted 20/20
runs on that final source. The current clean-profile editor check and direct
44/44 finalization pass are current-source evidence, not a new release.
