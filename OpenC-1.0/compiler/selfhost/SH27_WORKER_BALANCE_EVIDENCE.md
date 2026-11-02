# SH-27 critical-worker balance and semantic budget

Status: **local diagnostic proof, not a throughput cut or parity pass**.
Source `e4e4e9a` adds four additive `chunk_walls_ms` values to the existing
native timing JSON and makes the native chunk verifier require that their
maximum equals the reported critical chunk. The compiler does not change
worker assignment, semantic evaluation, IR, or emitted bytes.

## Why this measurement was needed

The earlier report named only the slowest chunk. That establishes its phase
cost but cannot show whether a worker-count/partition change has any plausible
wall-time headroom. On the scalar-flow source, clean
[run 35928451776](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35928451776)
passed all pre-parity correctness/RAM gates but failed the normal-default
DMD ratios: large functions 0.451/0.315 s (1.4317x; 57.25 ms to 1.25x),
control flow 0.272/0.211 s (1.2891x; 8.25 ms to 1.25x).

## Guarded local observations

The instrumented source rebuilt to a byte-exact Stage 2/3 fixed point.
The native source-chunk proof passed exact serial/default executables and
invalid diagnostics on self-build, small, 24-file, large-function, and
control-flow projects, including the 512 MiB Job guard. The strict SH-20
stability harness then passed 5/5 small builds, 5/5 changed-source builds,
and 20/20 exact compiler self-builds: peak child private **255,336,448**
bytes and working set **60,116,992** bytes, below 256/64 MiB.

Eleven order-alternated serial/default same-compiler runs of each generated
workload all produced byte-identical executables. The default's four worker
wall times, in source-range order, were:

| Workload | Median chunk 1/2/3/4 wall (ms) | Critical chunk counts | Median within-run max-minus-min (ms) |
| --- | --- | --- | ---: |
| Large functions | 328 / 219 / 204 / 234 | 11 / 0 / 0 / 0 | 125 |
| Control flow | 312 / 250 / 266 / 266 | 8 / 0 / 0 / 3 | 94 |

For the critical chunk, median nested phase counters were large functions:
acceptance **187 ms**, expressions **109 ms**, assignments **94 ms**, calls
**62 ms**, IR lower **78 ms**, native emit **32 ms**. Control flow: acceptance
**219 ms**, expressions **203 ms**, assignments **156 ms**, calls **15 ms**,
IR lower **47 ms**, native emit **16 ms**. These are independently rounded
medians and nested categories; **do not add them** to one another or to
top-level wall time. The local wall times are not subtracted from a separate
clean runner's DMD medians.

The generated large-function source 0 includes the entry call chain as well
as worker functions, and its acceptance time is consistently much higher
than other source records. Four fixed whole-source chunks therefore leave
one critical worker. But the 125/94 ms max-minus-min gaps are **not**
recoverable-speed claims: each control-flow worker already has one source,
and isolating source 0 in the eight-file large project would force another
worker to handle three files. A whole-file repartition alone is not proved
to close the clean 57 ms gap.

## Architectural decision

Prioritize one measured acceptance-to-lowering redesign that removes
first-visit assignment/expression and call work, especially in the critical
source. Evaluate finer-grained function-level work scheduling only with a
bounded ownership/merge design that keeps deterministic bytes, diagnostics,
and 256 MiB child private memory. Do not add a five-worker special case or
claim the imbalance as a gain without an eleven-pair guarded A/B and a clean
normal-default comparator. The Step 2-4 throughput cut and the later
incremental/project/final-source gates in `SH27_EXECUTION_PLAN.md` remain open.

Raw local reports are retained under ignored
`build-output/selfhost-sh27/sh27-worker-balance-profile-20260924/`.
