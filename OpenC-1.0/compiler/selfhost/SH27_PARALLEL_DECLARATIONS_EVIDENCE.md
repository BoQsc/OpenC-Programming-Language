# SH-27 parallel source parsing before ordered declarations

Status: **isolated local candidate; clean Windows parity and self-build A/B
still open**. Branch: `codex/sh27-parallel-declarations`.

## Architectural cut

The declaration phase previously read, lexed, parsed, and compacted each
source serially before ordered type predeclaration. `resolution_part2.p` now
parses disjoint source ranges on the existing guarded Windows thread
substrate, writing distinct entries of the retained parse cache. The main
thread then predeclares types and collects symbols in exactly the former
source order. Invalid parsed sources are reparsed in that ordered pass, so
diagnostics are not emitted from workers. Thread-launch failure uses the
existing deterministic serial fallback.

The diagnostic profile reports parse-retained **wall time** and read/lex/
parse/compact **summed worker time**. Its verifier now checks the latter
against at most four times wall time only under this bounded four-worker
policy; serial paths retain the one-times bound. The profiled native proof
passed exact output and diagnostic checks after that accounting correction.
The first clean candidate run stopped at this old serial-only accounting
assertion. The second stopped at the unrelated explicit-four `many_files`
timing assertion: the compiler exited successfully with byte-exact output
and bounded RAM, but its worker wall/critical counters sometimes all round
to zero on the 79,873-byte input. A local 80-build explicit-four probe
reproduced exactly one such zero-tick record. The verifier now permits this
specific all-zero timing profile only below 192 KiB while retaining the
launch-state, selected-mode, exact-byte, exit, and RAM gates; larger inputs
still require a positive critical-worker clock. A third clean proof is
required before interpreting pinned comparator results for this candidate.

The first policy only enables concurrent parsing for native four-chunk builds
with 4-16 files and at most 1 MiB of source. This is a bounded RAM policy,
not a special case for named benchmark inputs. The 222-file self-build keeps
its serial declaration parse until the strict 64 MiB working-set and 256 MiB
child-private limits have headroom for a broader policy.

## Local proof and measured effect

The candidate built to a byte-exact Stage 2/Stage 3 fixed point. The native
serial/adaptive proof passed exact executable bytes for self-build, small,
many-file, large-function, and control-flow projects; one- and two-error
invalid control-flow diagnostics were exact. Conformance passed 278/278,
Windows x64 substrate 25/25, and integer-boundary checks passed. The strict
20-generation self-build chain passed 20/20 exact closures on the final
rebuilt binary with peak child private **251,125,760** bytes (limit
268,435,456), peak working set **54,747,136** bytes (limit 67,108,864), and
median public build **2,969 ms**. The earlier prototype also passed 20/20,
but its median was 3,844 ms during a noisier host interval. These medians are
not compared across intervals to claim a self-build speed change.

Eleven order-alternated, same-host default-mode pairs against the frozen
streaming-cache compiler both passed executable, RAM, and source-byte checks:

| Workload | Candidate-minus-baseline paired median | Candidate wins | Baseline/candidate declaration medians | Peak candidate Job private |
| --- | ---: | ---: | ---: | ---: |
| Large functions | **-108 ms** | 11/11 | 188/63 ms | 172,052,480 bytes |
| Control flow | **-16 ms** | 8/11 | 47/16 ms | 85,942,272 bytes |

The declaration change is material: the local large-function gain removes
about 63% of the 172 ms gap implied by the independent clean DMD run's
0.484/0.250 s medians. This is a planning comparison across runs, **not** a
new C/D ratio or a claim that the remaining gap is exactly 50 ms. The
control-flow local gain removes about 62% of that clean run's 26 ms deficit,
but only clean pinned comparators can confirm the remaining gap. An earlier
build of the same architecture measured -122/-29 ms on these two workloads;
the final rebuilt binary's series above is the primary result.

The complete self-build A/B harness insists that *both* old and new compiler
binaries reproduce the new compiler source's hash. The old compiler emits
the new thread hook as its serial stub, so its new-source output is not the
candidate's fixed-point binary; those samples correctly fail that semantic
gate. A completed eleven-pair timing-only diagnostic had exit code zero,
valid timing records, and guarded RAM on both sides; its paired median was
-192 ms with 7/11 candidate wins. The report's overall status is correctly
`FAIL` because the old compiler's output hashes differ from the new fixed
point, so this is **not** a self-build non-regression proof. The candidate's
own fixed point and strict chain pass. A valid same-revision self-build
speed comparison or clean workflow guard remains required.

A separate three-sample local DMD-only corpus was noisy (large OpenC samples
0.876, 4.794, and 2.805 seconds) and lacks MSVC/Clang/LDC. Its partial
ratios are not promotion evidence. The 11-pair same-host compiler A/B and
clean pinned Windows CI are the throughput decisions.

The final candidate's diagnostic-only profile refreshes the next critical
path (one local sample, not a timed A/B claim). On large functions, serial
declarations were **62 ms**, native worker-stage wall **297 ms**, and the
critical worker spent **140 ms** in acceptance, of which **78 ms** was the
assignment rule family. Control flow showed 15 ms declarations, 141 ms
worker stage, and 93/62 ms acceptance/assignments. On self-build, acceptance
and native emission remain material at 701/516 ms on the critical worker.
These nested worker fields cannot be added to top-level wall phases. They do
justify making Gate C's first-visit typed-expression/assignment redesign the
next architecture after the declaration cut's clean CI decision.

## Next decision

Run the full clean Windows workflow on this isolated cut, including all 20
normal-default pinned ratios and historical self-build speed guards. Keep
raw timing and memory artifacts. If the self-build guard fails, separate
source-size/capacity effects from runtime policy (self-build parsing remains
serial); do not waive it. If clean DMD large-function parity remains open,
continue the fused typed-expression/assignment cutover from
`SH27_TYPED_EXPRESSION_CUTOVER.md`. No parser micro-tuning or policy retargeting
substitutes for that architecture.
