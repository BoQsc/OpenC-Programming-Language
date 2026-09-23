# SH-27 completion roadmap

Status: **ACTIVE; not performance-complete**. This is the forward execution
plan. `SH27_POST_RELEASE_PERFORMANCE_PLAN.md`, `SH27_NATIVE_CHUNK_PROOF.md`,
and `../../release/SH27_PRODUCTION_CORPUS_EVIDENCE.md` retain the historical evidence.
Do not mistake a green evidence-only workflow for throughput parity.

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
2. Build a compact per-source typed-expression record **during the existing
   dependency-ordered syntax/semantic walk**, not as an extra full prepass.
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
  allocator overhead or fragmentation is material; the DMD bump-allocation
  design is a hypothesis, not evidence that allocation is OpenC's bottleneck.
- Reuse bounded buffers and pre-size IR/output structures from checked
  counts. Define overflow handling, arena reset points, and ownership when a
  worker fails. Retain the 256 MiB single-allocation, 512 MiB live-byte, and
  512 MiB Windows Job/process memory protections already used in proofs.
- Verify no long-lived references escape an arena and no hidden process (or
  PowerShell/Python harness) consumes unbounded memory. Promote only if
  measured wall time improves without a material RAM regression.

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

Finish Step 0's first-visit cost/allocation attribution and clean-runner
confirmation, then start Step 1's fused typed-expression/assignment redesign.
The distinct-node counter has already ruled out repeated uncached evaluation
as the explanation for the large assignment count. Native emission is not the
first bet. Do **not** spend another cycle on cache-threshold nudges, isolated
instruction peepholes, or output-size-only changes unless a refreshed profile
shows they can close a material fraction of the ~221 ms/~121 ms same-run
deficits.
