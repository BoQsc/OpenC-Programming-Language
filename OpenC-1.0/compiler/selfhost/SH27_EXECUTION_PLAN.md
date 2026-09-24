# SH-27 execution plan: finish the compiler, then certify the release

Status: **active, not complete**. This is the ordered engineering checklist for
SH-27. `SH27_COMPLETION_ROADMAP.md` retains the detailed measurements and
decision history; `SH27_TYPED_EXPRESSION_CUTOVER.md` is the semantic design
contract. An isolated prototype, a green evidence-only workflow, or one lucky
comparator run does not complete a step below.

## Definition of done

The normal Windows x64 OpenC compiler, built to its byte-exact self-hosting
fixed point without D, TinyCC, Python, a C compiler, or a Microsoft CRT in its
normal compile path, must:

1. Compile and link the five versioned SH-27 corpus workloads at no more than
   **1.25x** each pinned MSVC, Clang, DMD, and LDC median on the same clean
   runner (20/20 checks). Aim for **1.20x** internally so a borderline pass is
   not mistaken for sustained parity. Require this on **two independent clean
   normal-default runs** of the *same final compiler source*, at least five
   samples per tool per workload. Compare within runs, never across runners.
2. Preserve all current language, diagnostic, executable, x64 substrate,
   self-host, deterministic-byte, and memory proofs. In particular, the
   20-generation self-build must obey 64 MiB child working set and 256 MiB
   child private bytes; the Windows Job/process tree stays within 512 MiB.
   Do not weaken checked arithmetic or safety semantics to win benchmarks.
3. Provide real, content-validated incremental object reuse and pass a
   separately versioned representative project suite, including cold, warm,
   no-op, implementation edit, public-interface edit, parallel batch, complete
   self-build, execution, and process-tree RAM lanes.
4. Preserve the immutable `v1.0.0` tag/assets, publish raw evidence and known
   limitations, route any release-critical findings, and use the ordinary
   owner-authorized process for a new release. Linux/freestanding/ARM64 and
   unsolicited external review responses are **not** SH-27 prerequisites.

The historical same-run deficit was not small. On the independent
[parallel-declaration repeat](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35916904066),
OpenC/DMD was 0.677/0.349 s on `large_functions` and 0.392/0.234 s on
`control_flow`: approximately **241/100 ms** must leave the OpenC wall time
to reach the public 1.25x ceilings on that runner, or **258/111 ms** for the
1.20x engineering margin. These are historical design budgets, not an
across-run speedup estimate. The unchanged current compiler source has now
passed two independent clean 20-sample normal-default runs on the pinned
hosted setup. See `SH27_NORMAL_DEFAULT_PARITY_REPEAT_EVIDENCE.md`. That
replicates the synthetic parity gate, but cannot certify the final source
until the incremental, representative-project, strict-memory, correctness,
and release work below is complete and any source changes are retested.

## Work order and stop/go decisions

| ID | Deliverable | Must pass before advancing |
| --- | --- | --- |
| 0. Freeze proof | Pin source, corpus, comparators, runner, commands, current compiler binaries, and raw baseline. | Reproduce the remaining gap and keep an immutable baseline for same-host A/B. |
| 1. Account for wall time | Instrument nonoverlapping critical-path phases and allocations; compare the relevant pinned DMD implementation. | Explain at least 80% of failing-lane wall time; give a falsifiable millisecond budget for the next architecture. |
| 2. Replace first-visit semantics | One dependency-aware typed-expression/assignment path, not a new memo cache. | Correct `check` and native artifact behavior; material end-to-end gain under RAM and self-build guards. |
| 3. Reuse semantic facts in lowering | Native lowerer consumes the same resolved symbols, children, values, and types. | Remove old duplicated scans/stores, prove exact behavior, rerun paired measurements. |
| 4. Remove the next largest serial cost | Based on the new profile, execute the backend value-location/compact-IR cut or another *measured* front-end architecture. | Close the remaining large/control wall budget without moving it to self-build or memory. |
| 5. Stabilize production policy | Recheck adaptive worker count, deterministic merging, fallback, and scratch ownership on small and large projects. | Normal default, not an opt-in mode, wins and stays within every declared memory cap. |
| 6. Implement true incremental builds | Dependency/interface fingerprints, deterministic COFF reuse, atomic cache, correct invalidation and relink. | Warm/no-op/edit outputs and diagnostics equal clean builds; demonstrated object reuse and speed. |
| 7. Validate real projects | Add versioned equivalent C/D/OpenC projects and compiler self-build scaling. | No hidden cold/warm/build/execution/RAM cliff; document any unavoidable semantic differences. |
| 8. Certify final source | Run complete correctness, 20/20 pinned parity twice, and all production/release-integrity checks. | All gates pass on the *same* final source; publish artifacts and then close SH-27. |

When a clean large/control deficit is open, Steps 2-4 take priority over
incremental caching, new platforms, or tiny parser/cache/peephole changes.
Two replicated current-source hosted parity passes now justify progressing
Steps 6-7 in parallel with the remaining architecture/RAM audit. If a later
source revision loses parity, the throughput track regains priority. Steps
6-7 are required for full SH-27 closure, not substitutes for throughput.
The isolated PreparedSource boundary has exact-output proof, but function
workers are still unsafe because first-visit caches and derived types are
source-global mutable state; see `SH27_FUNCTION_WORK_OWNERSHIP_GATE.md`.

## Broad candidate batch, not serial micro-optimizations

The first throughput cycle started three **independent architectural cuts**
from the same `6794d56` baseline. They are competing hypotheses, not three
changes to merge blindly:

| Candidate | Wall-time hypothesis | Decisive rejection test |
| --- | --- | --- |
| Normalized typed operations | Acceptance and native lowering repeat source-operator, child, symbol, and type discovery; one bounded handoff replaces both paths. | Exact fixed point/diagnostics/runtime/RAM, then paired large/control/self-build wall gain; mere cache-hit reduction is insufficient. |
| Call-heavy critical path | The first large-function source owns the call-heavy entry path and was critical in 11/11 local runs; restructure call resolution/lowering as a coherent path. | First-chunk and whole-project wall must both fall without moving cost to control or self-build. |
| Bounded function scheduling | Whole-source worker ownership leaves a measured critical tail; function work may be distributable after source-local semantic state is frozen. | If ownership, deterministic merge, or 64/256/512 MiB guards cannot be preserved, reject the split rather than adding another worker. |

Develop and correctness-check these in isolated worktrees. Heavy compiler
builds and timing runs stay **serial** on this host to avoid falsifying the
RAM result. A common `benchmark_sh27_candidate_matrix.py` accepts fixed-point
compiler executables, freezes one corpus, rotates candidate order, alternates
adjacent baseline/candidate samples, runs a baseline-vs-baseline null control
for host jitter, and writes raw guarded results for both failing workloads.
With `--require-gain`, a result must exceed that null median absolute paired
delta as well as win a majority of pairs. The matrix is a triage tool, not
the final parity gate. Codegen candidates may opt out of cross-revision PE
byte identity, but the matrix still requires each revision to be deterministic
and every executed program's exit/stdout/stderr to match exactly:
each surviving candidate also needs complete self-build, strict child/Job
RAM, conformance, and the pinned clean five-compiler run. Integrate survivors
one at a time and remeasure the combination; nonadditive wins or regressions
are grounds to discard or redesign a cut. If none closes enough of the DMD
gap, rerank architectural cuts against the measured critical path rather than
assuming a compact backend or another cache experiment will help.

The first broad batch is resolved in `SH27_CANDIDATE_PORTFOLIO.md`.
Indexed calls, packed/eager typed records, direct value/slot cuts, and
validator/lowering fusion were isolated, guarded, and compared; none survived
the clean two-lane throughput gate. The fused cut passed 278/278 conformance
and strict 20/20 self-build but saved only 2 ms on clean large functions and
regressed control flow by 10 ms. A compact child/name sidecar was rejected at
the design stage because existing node indexes/caches already serve the
lowerer. This is evidence against these *particular mechanisms*, not typed
semantic architecture as a whole. The next batch must change first-visit
representation/ownership rather than repackage another validator sweep.

The [DMD source map at `fb655c9`](https://github.com/dlang/dmd/blob/fb655c9ae95e7da8cc8ce8439b57f4e2c1ec2924/compiler/src/dmd/README.md)
is a useful architectural comparator, not a license to copy code or a proven
speed explanation: it distinguishes parser-produced AST, semantic expression
work, an AST ready for code generation, and expression-to-IR conversion.
OpenC currently keeps generic `syntax_data` records plus mutable side caches
in `source/ir.p`; `ir_node_type` in `source/ir_part3.p` can lazily discover a
type, and `source/ir_part3_uncached.p` repeatedly decodes source/operator
spans on first visits. The falsifiable next design is to produce compact
semantically resolved node facts *during required first visits* and let both
diagnostics and native lowering consume them. DMD's structure motivates the
comparison; only OpenC's guarded two-lane wall measurements can validate it.

## Current checkpoint (2026-09-24)

| Step | State | Next decisive evidence |
| --- | --- | --- |
| 0. Freeze proof | Partial | Keep the scalar-flow source `738bea3`, raw local pairs, and failed-parity clean run `35928451776` as one traceable candidate; do not compare its absolute times to a different runner. |
| 1. Account for wall time | Partial | The clean `6794d56` first-visit probe attributes the critical worker: acceptance 157/141 ms, lowering 62/32 ms, native emission 32/0 ms at timer resolution, indexing 31/15 ms. The rejected scalar-flow branch would need its own profile if revived. Compare the pinned DMD source architecture, not merely its timings. |
| 2-3. Fused semantics and lowering | Open, architectural redesign required | The isolated scalar-sweep fusion was correct (278/278, strict 20/20) but clean-speed flat/regressive. Build a typed *first-visit* representation that carries scope/type/operator facts into lowering; no eager extra pass or duplicate generic-record arena. |
| 4. Remaining architecture | Not implemented | After a first-visit cut, reprofile and attack the largest remaining serial phase. Native value cuts have so far changed code size more than compiler throughput. |
| 5. Production policy/RAM | Current source passed strict 20/20; final source pending | Normal adaptive mode passed exact-output current-source 20-generation 64/256 MiB child and 512 MiB Job guards. Repeat after any accepted compiler source change. |
| 6. Incremental objects | Architecture boundary mapped; not implemented | `SH27_INCREMENTAL_OBJECT_REUSE_ARCHITECTURE.md` identifies global IDs, fused validation, missing multi-COFF linker, and atomic cache as concrete prerequisites. Demonstrate content-validated COFF reuse and correct implementation/API invalidation, not merely a one-file rebuild timer. |
| 7. Representative projects | Versioned scaffold and one guarded proof; broad project gate open | `benchmarks/sh27/representative/SUITE.json` covers a CLI, four-module file-audit app, and the 222-source compiler with exact cold/warm/edit/runtime/RAM checks. Add a retained user project, repeated samples, and equivalent C/D cases before claiming representative parity. |
| 8. Final-source certification | Partial, current-source parity/memory/conformance/editor only | Two independent clean 20/20 normal-default runs, strict 20/20 self-build, native 278/278 conformance, old-release asset integrity, fresh VS Code clean-profile, and direct finalization 44/44 passed on `1b58d5e`. The daily aggregate remains 13/14 because it hardcodes the historical profile path; incremental, representative breadth, other final checks, and final-source reruns remain. |

The first broad batch rejected three partial source cuts and one scheduling
proposal. The independent function queue is a no-go before immutable typed
facts and bounded worker scratch; its zero-overhead local model is documented
in `SH27_FUNCTION_SCHEDULING_DECISION.md`. The indexed call-summary candidate
passed its fixed point and workload correctness/RAM checks, but not a speed
signal above same-run null noise, and control flow regressed; see
`SH27_CALL_PATH_BATCH_EVIDENCE.md`. The packed typed-record/validator-batch
candidate moved assignment timing without removing first-visit work; see
`SH27_TYPED_OPS_BATCH_CANDIDATE.md`. The direct native slot-layout cut reduced
one subphase but did not improve whole-compiler wall above host noise and has
an unproved strict working-set gate; see
`SH27_BACKEND_VALUE_LOCATION_EVIDENCE.md`. None of those source patches
belongs in the production branch. The next two source tracks must replace
the complete typed semantic-to-lowering path and the function-level compact
value path, respectively; a second narrow cache/slot cut is not an acceptable
substitute. The clean CI batch runner is a third, independent track because
this desktop's baseline-vs-baseline jitter often exceeds the remaining gap.
The first direct-value checkpoint (`SH27_DIRECT_VALUE_PATH_EVIDENCE.md`)
passed a local large-function timing threshold but removed only one stack
store/reload pair on that corpus; therefore its observed 121 ms wall delta
has no credible causal attribution. A successor must reach the immediate-
arithmetic chain that dominates the corpus, expose the number of eliminated
pairs there, and pass both target lanes before a clean CI parity claim.
`SH27_BRANCH_BATCH_CI.md` describes the commit/manual clean-runner workflow,
frozen branch-ref and source-hash checks, strict fixed-point bootstrap, and
serial matrix artifact contract; it screens candidates but cannot certify SH-27.
The full typed-operation prebuild subsequently specialized every generated
large/control source and preserved exact artifacts, yet remained flat on the
guarded 11-pair wall gate. `SH27_TYPED_PIPELINE_REJECTION.md` records that
the new eager expression traversal repeated old first-visit checks and moved
assignment/call time into a new counter. The next semantic cut must validate
inside the *already required* lowering traversal with bounded fallback for
invalid source; another eager operation arena is not the answer.
`SH27_ACCEPTANCE_FIRST_VISIT_PROFILE_EVIDENCE.md` now pins an opt-in,
correctness-preserving candidate-visit/allocation probe and the unprofiled
critical-worker budget. It observes 255,235/44,867 child-candidate visits and
58,391/13,009 name-candidate visits on large/control. An independent compact
index candidate must replace those visits across acceptance and lowering
without another full syntax arena; counters alone are not a speed result.

`SH27_WORKER_BALANCE_EVIDENCE.md` now records four-worker wall times from
eleven guarded local runs per large/control workload. The first chunk was
critical in 11/11 large and 8/11 control runs; its large/control acceptance
medians were 187/219 ms. The observed worker imbalance is not an available
125/94 ms speedup: control already has one file per worker, and a different
eight-file partition can create a three-file critical chunk. Step 1 still
needs first-visit and allocation attribution; the next semantic/lowering cut
must target **whole critical-path wall**, not only a summed rule counter.

The next implementation decision is **not** another isolated cache or rule
flag. Keep measured upper bounds on the remaining semantic, lowering, and
backend wall time of `738bea3` while independent architectural candidates
are built from the same baseline. If the semantic/lowering ceiling cannot
cover the same-run DMD deficit, design Step 4 concurrently rather than
waiting for a succession of small wins. A prototype advances only after
11 same-host paired large/control/self-build measurements, byte-exact
behavior, fixed point, and strict RAM; otherwise record and reject it.

The clean comparator for `738bea3` has now finished: [run
35928451776](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35928451776)
passed its pre-parity correctness, strict-memory, and historical speed
steps, but the enforced normal-default matrix failed **large functions
versus DMD** at 0.451/0.315 s (1.4317x) and **control flow versus DMD** at
0.272/0.211 s (1.2891x). The other 18 ratios passed. On that same runner,
the 1.25x public ceiling requires 57.25/8.25 ms less OpenC wall time;
the 1.20x internal margin requires 73.0/18.8 ms. These replace the earlier
parallel-declaration run's 241/100 ms as the **latest candidate's**
same-run planning budget, not as a cross-run speedup attribution. The
local 93/42 ms scalar-flow gain did not close clean parity.

### 0. Establish the comparison contract

- Preserve the current known-good parallel-declaration compiler and its
  failing/green clean reports. Record exact source hashes, corpus version,
  compiler versions/flags, selected chunk mode, CPU/runner image, OS cache
  state, executable hashes, and parent/whole-Job memory.
- Run 11 order-alternated same-host A/B pairs for `large_functions`,
  `control_flow`, and complete compiler self-build. The candidate and
  baseline must compile identical source and use identical checked semantics.
  Store raw samples, median paired deltas, p95, outputs, and Job peaks.
- Use the pinned five-compiler CI only for within-run parity. The comparator
  loop rotates tool order; retain all per-sample observations. A failure after
  a green run is a failure to reproduce, not a reason to discard the run.

### 1. Produce a critical-path budget alongside isolated architecture work

- Profile the normal default, explicit serial, and explicit worker modes on
  the three guarded workloads. Separate top-level declarations/indexing,
  resolution, flow/acceptance, worker launch/join, IR lowering, native emit,
  link/write. Worker subphases are nested; do **not** sum them into top-level
  wall time. Attribute the slowest worker, not summed CPU time.
- Within first semantic visits, count and time symbol/function selection,
  operand discovery, literal decoding, contextual typing, assignment and
  binary rules, and temporary allocations. Validate counters with an external
  profile. The existing zero-repeat uncached-type result means a larger type
  memo table is not the design.
- Compare pinned DMD's typed expression storage, bump allocation, and
  semantic-to-codegen handoff against OpenC's actual call graph. State which
  design difference applies to OpenC, what work it removes, and its maximum
  plausible wall-time saving. A source analogy alone does not qualify.
- Exit with an explicit budget: expected milliseconds removed by Steps 2-3,
  remaining milliseconds assigned to Step 4, and a <=5% regression limit on
  protected lanes. If the measured semantic ceiling is below the required
  gap, begin Step 4's architectural design immediately; do not wait for
  incremental tweaks to accumulate.

### 2. Cut over semantic evaluation as one coherent architecture

- Use the existing `IrContext` lifetime in `c_compile_project_source` to
  carry a bounded, normalized typed-expression IR from acceptance into
  native lowering. Each operation carries resolved child IDs, selected
  symbol/operator, type and contextual/literal state. It must *replace*
  syntax rediscovery and rule replay, not merely store their outputs in an
  extra cache. Do not allocate the five old full arrays alongside a second
  full per-syntax representation in production.
- Build dependency-aware evaluation: binary/assignment operands precede
  parents, but calls can precede their arguments. Use indexed call arguments
  or an explicit bounded dependency stack; never assume syntax ID order is
  globally topological. Freeze only expectation-independent success. Retry
  failed lookup and preserve expected-type-sensitive literals/aggregates.
- Reuse the repaired literal-value experiment only under exact return ABI
  and contextual-typing tests for integer widths, comparison, overflow,
  and null/aggregate expectations. Its later complete self-build regression
  rejects it as a standalone change. Fuse the high-volume
  assignment and binary rule families with the expression evaluation, while
  buffering/ordering diagnostics to match the old passes exactly.
- Preserve `check`, invalid inputs, error count/order/positions, source-order
  duplicate/cycle handling, and serial/parallel deterministic output. Use
  the old implementation only as a test comparator during cutover. Delete
  unused caches and rescans when equivalence is proved.

### 3. Make the lowerer consume the normalized typed operations

- Change name, literal, unary, binary, assignment, and call lowering to use
  accepted child/symbol/type/value facts. Keep explicit fallback for genuinely
  contextual or unsupported forms; count fallback visits and require their
  frequency to be explained on the failing lanes.
- Retain precise checked arithmetic, conversions, ownership and cleanup,
  calling convention, unwind data, and overflow traps. Compare generated
  binary bytes and runtime behavior; a smaller number of internal type calls
  without an end-to-end wall gain is not acceptance.
- Run the fixed point, 278 fixtures, 25 x64 checks, integer/aggregate edge
  cases, invalid diagnostic corpus, exact serial/parallel proof, strict RAM
  chain, and 11-pair speed series. Promote Steps 2-3 together only if the
  targeted lane removes at least 10% of its then-measured gap and no other
  protected lane regresses more than 5%. Otherwise record the failure and
  redesign this cut rather than merging a packed-cache micro-win.

### 4. Execute the second throughput architecture from the new profile

Parallel declaration parsing is already implemented and locally saved 108 ms
large / 16 ms control in 11-pair tests, but its clean repeat still failed
DMD parity. Reprofile *after* Steps 2-3. The default planned second cut is a
per-function compact IR/value-location backend, because the semantic cut's
locally measured assignment time alone cannot account for the 241 ms large
deficit. Override that choice only if the new critical-path evidence names a
larger serial front-end cost and shows the backend cannot close enough wall
time.

- Count per-function IR nodes, live ranges, spill/reload pairs, stack slots,
  emitted bytes, and lower/emit wall time. Define register ownership,
  liveness, call clobbers, flags, checked overflow, stack alignment, unwind,
  and aggregate fallback before modifying emission.
- Produce values in registers or final destinations for block-local chains;
  spill only for liveness, calls, address taking, or pressure. If the
  lowerer/emitter boundary remains dominant, replace repeated tree walks
  with a bounded compact typed per-function IR and one lower/emit traversal.
  Keep old emission as a test-only oracle until proof passes.
- Measure the combined *wall* delta with Steps 2-3 on all three workloads.
  If it is still short of the 1.20x margin, repeat Step 1 on the new source
  and attack the largest **measured** remaining architecture. The loop ends
  only at sustained comparator parity; it is not permission to ship a chain
  of unbudgeted micro-optimizations.

### 5. Lock default concurrency and RAM behavior

- Re-tune adaptive source workers using measured launch/merge cost, source
  size, available CPU, and predicted per-worker bytes. Preserve an explicit
  serial diagnostic switch and deterministic serial fallback on worker or
  allocation failure. Test invalid imports, duplicate declarations, cycles,
  multiple errors, one-file projects, and different CPU counts.
- Count temporary allocation calls, bytes, and lifetimes. Use bounded
  per-worker scratch only when allocator cost is measured; prove no pointer
  escapes a reset. The 256 MiB single-allocation, 512 MiB live-byte, strict
  child-process, and 512 MiB Job limits remain active. The harness and child
  tree must not retain unbounded Python/PowerShell memory.
- Re-run all speed and memory proofs with the production *default* after any
  policy or allocator change. A faster opt-in `--source-chunks` mode is not a
  pass for this step.

### 6. Build genuinely incremental native artifacts

- Define module dependency and public-interface fingerprints, including
  compiler revision, target ABI, flags, generated bindings, and cache schema.
  Implementation-only changes invalidate the edited module; public API
  changes invalidate dependent modules. Cycles and invalid inputs need
  deterministic treatment.
- Persist deterministic COFF objects and a manifest with atomic writes and
  corruption/staleness detection. Relink using existing native facilities;
  do not add an external linker or a Python normal-build dependency.
- Prove no-op, leaf implementation edit, public API edit, corrupt cache,
  cache-version change, and clean rebuild on 24-file and representative
  projects. Require identical executable behavior and diagnostics, actual
  object cache hits, bounded peak RAM, and measured warm-build advantage.

### 7. Test representative work, not only generated arithmetic

- Version a separate small CLI, medium multi-module app, and compiler
  self-build suite. Where comparing languages, check in equivalent C/D/OpenC
  inputs and verify output; list semantic differences explicitly. Keep
  `benchmarks/sh27/CORPUS.json` v1 unchanged as the 20-ratio contract.
- Test scaling by function size and file count, clean/warm/no-op/edit builds,
  four-project batches, runtime, binary size, diagnostics, and whole-Job RAM.
  A project cliff gets a named reproducer and a new measured work package;
  it cannot be hidden by the synthetic median.

### 8. Run the closure matrix on one final source revision

- Run byte-exact Stage 2/3, all conformance and x64/ABI tests, diagnostics,
  executable behavior, deterministic workers, strict 20-generation RAM,
  incremental/project gates, and the pinned five-compiler normal-default
  matrix. Then run the *same-source* clean matrix independently again.
- Keep raw JSON and failure artifacts. Require all 20 ratios <=1.25x on both
  runs; investigate any lane above the 1.20x engineering margin or a large
  within-run swing. Do not label an evidence-only success `PASS_PARITY`.
  Make commit-triggered parity blocking only after the final candidate passes.
- Re-verify the immutable `v1.0.0` release assets and tag, route any received
  critical review findings, publish a complete status and new-version assets
  through the owner-authorized release path, and update `ROADMAP.md` only
  from verified evidence. If any hard gate fails, SH-27 remains active.

## Present decision

The packed four-word typed-record prototype passed local correctness and
RAM, but its 11-pair complete self-build median regressed by 136 ms and it
does not fuse semantic evaluation. One clean branch workflow passed 20/20
pinned ratios; no independent same-source repeat establishes parity. Its
literal-value successor fixed an earlier self-bootstrap defect and passed
local correctness and strict RAM, but regressed self-build by a 326 ms
paired median against the packed source. Its clean workflow then failed
the enforced large-function DMD ratio at 2.0801x. These are isolated enabling
experiments, **not** the SH-27 solution. The next code cut must integrate
semantic/rule/lowering reuse (or a profile-backed second architecture) and
be judged by the whole-compiler gates above.

The separate source-evidence ownership flow gate in
`SH27_FLOW_FRONT_END_EVIDENCE.md` has a locally guarded -26 ms control-flow
paired median and no self-build regression. One clean workflow passed all
20 pinned ratios and the strict memory gate, but there is no independent
same-source repeat;
its -9 ms large-function paired median leaves most of that lane's gap open.
It cannot replace Steps 2-4 or the two final same-source parity runs.

The broader scalar-source proof at `738bea3` then removed the full flow
stage for error-free sources with only initialized scalar locals and no
applicable stateful rule. Eleven guarded local pairs saved 93 ms on large
functions (10/11 wins) and 42 ms on control flow (11/11), with a flat
self-build (-2 ms paired median). `SH27_SCALAR_FLOW_EVIDENCE.md` records the
proof and fallback boundary. This is a material architectural reduction,
but its first clean pinned comparator failed two DMD ratios; the remaining
architecture and all later completion gates remain open.
