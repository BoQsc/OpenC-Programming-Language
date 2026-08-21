# SH-14 compiler throughput convergence and stability

Status: **PASS (2026-08-10); SH-17 REGRESSION PASS, SH-18 ACTIVE**

SH-14 is complete. The final five-run clean compiler median is 4.137 seconds
against a 12.731-second pinned same-host D median (0.325x). The small-build
median is 0.158 seconds, the exact-fingerprint one-source median is 0.158
seconds, the worst 0.25/0.5/1/2 MiB doubling ratio is 2.112x, and 20 chained
clean rebuilds preserve identical compiler and generated-source hashes. Peak
private memory is 250,437,632 bytes and peak working set is 26,804,224 bytes.
Native conformance passes 278/278, maintained programs pass 4/4, and the full
native workflow passes 13/13 without executing the retained D seed.

The decisive throughput correction was a compiler-private byte-slice path for
byte-addressed source spans. It removed repeated scalar UTF-8 rescans. Static
eight-way deterministic source lowering and a linear source-position owner
index removed the remaining clean-build and scaling bottlenecks. Complete
evidence is in `release/SH14_COMPILER_THROUGHPUT_CONVERGENCE_EVIDENCE.md`.

SH-13 proved where the time is spent, but it did not make the compiler fast.
The 96-source, 972,368-byte compiler rebuild took 500.311 seconds in the
monitored run and 557.985 seconds in the phase-timed run. Of the latter,
548.172 seconds was OpenC-owned lowering and C emission; TinyCC took only
0.938 seconds. Treating that result as acceptable would hide the project's
largest engineering problem.

During SH-14, no editor, GUI, COM, WinRT, ARM64, Linux, freestanding, or broad
Windows API work was allowed to displace the blocking throughput work. SH-15
subsequently passed the ABI/encoder milestone while retaining every throughput
budget. SH-16 also passes after adding the direct PE32+ and CRT-free runtime
proof: its 107-source compiler has a 6.665-second five-run median,
7.302-second maximum, and 0.364x same-host D ratio. SH-17 Win32 Metadata and raw
projection now passes without entering ordinary compiler builds; the 112-source
compiler closes byte-identically with a 6.111-second median, 6.170-second
maximum, and 0.338x same-host D ratio. SH-18 friendly Windows modules are now
active while deferred targets retain their sequence.

## Meaning of D/C-class throughput

The phrase is a measured gate, not an aspiration. The SH-14 harness must build
equivalent pinned inputs on the same otherwise-idle host, record tool versions,
use clean output directories, and preserve raw samples. A preliminary forced
release build of the retained D reference compiler on 2026-08-04 completed in
25.462 seconds; this observation must be replaced by the reproducible
cross-compiler benchmark before it is treated as release evidence.

SH-14 passes only when all of these conditions hold:

| Gate | Required result |
| --- | --- |
| Clean compiler self-rebuild | five-run median <= 30 seconds; every run <= 45 seconds |
| Relative D-class result | median <= 1.25x the pinned same-host D reference build |
| User-facing small build | median <= 250 ms; every run <= 500 ms |
| One-source rebuild | median <= 1 second with an exact dependency fingerprint |
| Scaling | doubling 0.25/0.5/1/2 MiB workloads costs no more than 2.4x at each step |
| Backend attribution | OpenC frontend, semantics, lowering, and emission each have separate records |
| Correctness | 278/278 conformance, 4/4 maintained programs, and all workflow contracts pass |
| Closure | input, Stage 2, and Stage 3 compiler executables and generated source are byte-identical |
| Stability | 20 consecutive clean self-rebuilds pass without hash, memory, or result drift |
| Memory | peak private <= 256 MiB and peak working set <= 32 MiB |

The absolute and relative clean-build limits are both required. A faster
reference compiler cannot silently weaken the absolute gate, and a slower host
cannot be used to excuse a regression. Budgets may be tightened after faster
evidence; they may not be raised merely to declare SH-14 complete.

## Required evidence

The OpenC compiler must emit a stable `openc.throughput_trace.v1` record with:

- source count and byte count;
- project load, lex, parse, declaration, resolution, validation, IR lowering,
  target lowering, serialization, backend, and total time;
- stable counters for syntax nodes, symbols, types, IR blocks/instructions,
  table probes, cache hits/misses, allocations, bytes copied, and source reads;
- the slowest compiler functions and operations by inclusive time and work
  count;
- compiler, project, runtime, target, and backend fingerprints.

The benchmark suite must emit `openc.throughput_suite.v1`, retain every raw
sample, reject background-contended or fingerprint-mismatched comparisons,
and report median, minimum, maximum, and scaling ratios. Python may orchestrate
the initial evidence while it remains external to the compiler package, but an
OpenC-native replacement is required by SH-20.

`benchmark_throughput_suite.py` is the authoritative clean OpenC/D comparator.
It accepts `--enforce` for the release gate and may run without that option to
retain a failed optimization baseline. Small, incremental, scaling, and
contention-rejection lanes passed and remain required regression gates.

## 2026-08-09 indexed-lowering checkpoint

The current 96-source, 1,085,893-byte compiler closes byte-for-byte at stage
101. The closed rebuild completed in 80.149 seconds (80.047 seconds in the
compiler timing record), with 67.718 seconds in IR lowering, 9.747 seconds in
C emission, and 0.328 seconds in TinyCC. Peak private memory was 262,389,760
bytes and peak working set was 19,030,016 bytes, both inside the existing
ceilings. Native validation passes 278/278 and all 4 maintained programs pass.

This checkpoint is a large improvement over SH-13 but is **not SH-14 PASS**:
it is 50.149 seconds over the clean-rebuild median target and no five-run,
D-relative, scaling, incremental, or 20-build soak evidence has passed yet.

The indexed tranche now provides source-ordered statement, control, block,
initializer-field, array-element, expression-start, call-argument, declaration,
local/parameter, aggregate-field, and enum-value lookup. Compared with the
stage-74 trace, counted statement/parent/expression/syntax/symbol candidates
fell from 4,293,471 to 349,741 (91.9%). Compiler-private C primitives also
remove generated call layers from packed-buffer access, checked arithmetic,
IR construction, type derivation, span comparison, and C-output buffering.

That work exposes the next blocker: even after lookup convergence, IR lowering
alone still takes 67.718 seconds. SH-14 therefore continues with generated-code
quality and parallel-unit architecture. The next implementation tranche is:

1. emit smaller independently compilable C units and eliminate the giant
   SSA-temporary stack shape;
2. add deterministic value-lifetime reuse and direct structured control flow;
3. freeze shared semantic/type state, then lower independent source units in
   parallel into ordered private output buffers;
4. rerun the five-sample absolute/D-relative suite only after an ordinary
   closed rebuild is at or below 30 seconds.

A DMD ImportC experiment was rejected: optimizing the generated frontend took
113.656 seconds before runtime compilation/linking, and its objects were not
link-compatible with the bundled TinyCC runtime objects. It is not an SH-14
implementation path and no DMD dependency was added.

## Engineering sequence

### SH-14A: measurement integrity

1. Add hierarchical timers and deterministic work counters inside OpenC.
2. Add pinned compiler-self, maintained-program, small-project, and synthetic
   scaling workloads.
3. Add same-host D-reference and generated-C comparator lanes without making
   either a compiler dependency.
4. Record cold, warm, no-op, and one-source-change paths separately.
5. Reject incomplete or incomparable samples rather than averaging them.

### SH-14B: remove superlinear work

1. Parse every source once per clean build and retain one immutable syntax
   representation.
2. Construct parent/child, containment, name, declaration, symbol, type, and
   call indexes in linear or `N log N` setup passes.
3. Replace remaining whole-table scans in lowering with indexed queries and
   add counters that fail if scan counts grow superlinearly.
4. Intern paths, module names, identifiers, and repeated text once per build.
5. Stop rereading, relexing, reparsing, or revalidating unchanged sources.
6. Separate semantic computation from deterministic sorting/serialization so
   determinism does not require repeated global searches.

### SH-14C: reduce allocation and copying

1. Use bounded arenas for syntax, symbols, types, IR, and target records.
2. Use numeric IDs and slices in hot paths instead of transient text objects.
3. Pre-size buffers from measured counts and eliminate geometric copying of
   multi-megabyte generated output.
4. Make ownership of cached data explicit and verify that cache invalidation
   cannot retain stale project state.
5. Keep peak-memory ceilings enforced while trading memory for speed only when
   the measured result is favorable and bounded.

### SH-14D: improve generated-compiler execution

1. Remove abstraction penalties visible in the emitted C for record access,
   buffer writes, loops, and bounds checks whose proof is already known.
2. Specialize compiler-internal hot operations without weakening OpenC safety
   semantics for user programs.
3. Emit direct structured control flow and avoid avoidable helper calls and
   pointer-alias pessimization.
4. Keep TinyCC time isolated. Backend changes do not count as a frontend win.
5. Preserve byte-identical closure after each optimization group.

### SH-14E: incremental build path

1. Fingerprint source bytes, project configuration, imported module surfaces,
   compiler version, target, runtime, and backend.
2. Cache parsed source, exported declarations, typed module state, and lowered
   target units only when every dependency fingerprint is exact.
3. Invalidate transitively and deterministically; never reuse evidence after a
   compiler, target, runtime, or semantic-rule change.
4. Make no-op and one-source-change performance part of the blocking suite.

### SH-14F: stability freeze

Before the first-party Windows backend begins, freeze and document:

- the typed Core IR consumed by target backends;
- target data-layout and calling-convention records;
- compiler/runtime ownership, failure, and cleanup boundaries;
- deterministic build-record and artifact-fingerprint formats;
- differential and conformance gates required for every backend.

Run the 20-build closure soak, complete conformance and maintained-program
gates, malformed-input stress, and deterministic archive verification. SH-14
is complete only after the measured speed and stability requirements pass
together.

## Non-solutions

- Raising the current 900-second budget is not throughput work.
- Replacing TinyCC while OpenC lowering still consumes minutes does not solve
  the measured bottleneck.
- Caching an incorrect or incompletely fingerprinted result is not a speedup.
- Hiding D, Python, or TinyCC invocation in a wrapper is not independence.
- Skipping correctness, safety, or closure checks to improve benchmark numbers
  is forbidden.

With SH-14 through SH-16 passed,
`compiler/design/WINDOWS_NATIVE_INDEPENDENCE.md` is the active implementation
sequence. SH-17 now builds the purpose-built Win32 Metadata reader and raw
projection on the completed ABI, PE32+, and runtime substrate; TinyCC removal
remains targeted at SH-19.
