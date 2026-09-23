# SH-27 function scheduling: bounded architectural decision

Status: **no-go for an independent scheduler patch**. This is a reproducible
cost bound and an integration design, not a measured compiler speedup. It does
not change the OpenC compiler or satisfy the SH-27 parity gate.

## Reproducible bound

Run `analyze_sh27_function_schedule.py` on the existing 11-pair
`large-balance-checkpoint.json` and `control-balance.json` under the ignored
`build-output/selfhost-sh27/sh27-worker-balance-profile-20260924/` directory.
The script reads the reported four worker walls and the critical worker's
IR-lowering/native-emission time, verifies the critical wall, and computes two
counterfactuals for each sample:

* `zero_cost_floor_ms`: all of that critical worker's lower+emit time disappears;
  no real scheduler can do better by moving only that work.
* `tail_ideal_ms`: lower+emit becomes infinitely divisible work available after
  the critical worker's other work, and the four workers execute it with **zero**
  task creation, cache cloning, synchronization, and output-merge cost. This is
  an illustrative optimistic model, not a rigorous timing prediction; actual
  function release times differ by source and function.

| Workload | Critical wall median | Movable lower+emit median | Zero-cost floor median | Tail ideal median | Modeled gain median |
| --- | ---: | ---: | ---: | ---: | ---: |
| Large functions | 328 ms | 94 ms | 249 ms | 262 ms | 70 ms |
| Control flow | 313 ms | 63 ms | 266 ms | 278 ms | 16 ms |

The independent clean comparator needed about 57 ms large-function and 8 ms
control-flow OpenC reduction to reach 1.25x DMD on that runner. These local
counterfactual milliseconds cannot be directly subtracted from the clean
runner's medians. The remaining room after realistic setup and memory costs
is particularly narrow for control flow. Scheduling may complement semantic
work, but the model does not justify treating it as a standalone parity fix.

## Why a direct function queue is unsafe in the current compiler

`backend_c_parallel_state.p` gives each of four native workers a disjoint
source range. `backend_c_project_source.p` parses and indexes a whole source,
allocates source-local caches, runs `acceptance_validate_context` for the whole
source, then lowers and emits its functions serially in syntax order. The
critical large/control workers spend roughly 187/219 ms in acceptance, which a
lowering-only queue cannot move.

The `IrContext` used by `c_lower_and_emit_function` mixes immutable project
indices and syntax with mutable local SSA values, IR buffers, expression/type
caches, derived type storage, native layout/export caches, and a project-wide
`next_value`. Sharing it across threads would introduce data races, changed
SSA numbering, possibly different emitted bytes, and memory growth. Repeating
parse/index/acceptance for every function batch would trade the observed tail
for duplicated front-end work. The current strict self-build measured a peak
255,336,448-byte child private allocation against a 268,435,456-byte cap;
blindly cloning four complete source contexts has only 13,099,008 bytes of
headroom. The working-set margin is 6,991,872 bytes against 64 MiB.

## Integration design after immutable typed handoff

1. Separate an immutable `PreparedSource` from a bounded per-worker
   `FunctionScratch`. The prepared source owns retained tokens/syntax,
   read-only source indices and fully computed typed-expression/operator facts.
   Acceptance must finish exactly once per source before any function is
   eligible. The semantic-to-lowering cut must define and test this freeze
   boundary; no worker may mutate prepared caches or shared type tables.
2. Make a deterministic function descriptor table in source-record/syntax
   order: source ID, function node, owner symbol, output ordinal, and a
   conservative scratch/output size bound. Use only the existing four workers.
   A bounded queue may distribute ready descriptors; source order is **not**
   changed by scheduling priority.
3. Give each worker one reusable scratch context with isolated local values,
   IR buffers, type/layout/export overlays and native-emission buffers.
   Normalize or preassign SSA value ranges so function code and relocation
   bytes do not depend on completion order. Reserve all scratch/output memory
   against the existing 256 MiB private and 64 MiB working-set guards before
   starting the queue. If a source or project exceeds the conservative budget,
   use the existing deterministic source-worker path.
4. Publish each result in its descriptor slot. Merge only after all workers
   join, in descriptor order, so PE sections, relocations, exports, and entry
   selection remain byte-identical. On any acceptance or lowering failure,
   discard speculative output, release worker arenas, and replay diagnostics
   serially in source/phase order exactly as the current rejected-build path
   does.
5. Verify Stage 2/3 fixed point; all conformance and invalid-diagnostic
   fixtures; exact serial/default output hashes; 20/20 strict self-build under
   both memory caps; and an order-alternated, guarded 11-pair comparison of
   the full candidate against its immediate baseline. Only then run the clean
   normal-default C/D comparator. No throughput claim follows from this model.

Decision: **defer implementation until the immutable semantic-to-lowering
handoff exists**. Preserve this model as the explicit scheduling budget. A
function queue added before that boundary would make the SH-27 correctness and
RAM requirements less true while offering, at best, an unmeasured gain.
