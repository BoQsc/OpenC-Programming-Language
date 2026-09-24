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

## Next decisive batch

The unchanged production compiler now has **two** independent clean hosted
20/20 normal-default parity passes, a local strict 20-generation chain, and
278/278 conformance. A [pinned hosted three-language medium-app proof](SH27_REPRESENTATIVE_HOSTED_PROOF.md)
also passed 3/3 cold, warm, and edit repetitions with exact executed output.
That permits three independent engineering tracks to
advance concurrently, without treating a noisy local micro-gain as progress:

1. **Real incremental native artifacts:** promote only a conservative
   canonical interface projection that catches same-length renames and ABI
   edits; then establish stable symbol/type IDs, split acceptance from native
   emission, add atomic content-validated per-module reuse, and finally a
   deterministic multi-COFF linker. A full-source hash or warm timer with no
   actual module hits fails this track.
2. **Safe function ownership:** the opt-in serial PreparedSource boundary is
   exact, but 25 pointer fields and derived type IDs are still mutable and
   shared. Freeze the lowering type closure and give each function worker
   bounded independent scratch before attempting deterministic scheduling.
   Require strict 64/256 MiB child and 512 MiB Job proof and a same-run
   end-to-end speed signal; an opt-in flag alone is no throughput result.
3. **Representative projects:** keep the 20-ratio generated corpus unchanged;
   use the new guarded CLI/file-audit/compiler suite for cold/warm/edit and
   exact execution. The D fixture passes locally; the pinned MSVC C lane and
   repeated project-level comparisons need a hosted runner. Add a retained
   user project before claiming real-world representativeness.

After any compiler source promotion, rerun complete diagnostics/runtime/ABI,
the strict 20-chain, and **two new independent** normal-default hosted 20/20
runs on that final source. The current clean-profile editor check and direct
44/44 finalization pass are current-source evidence, not a new release.
