# SH-27 indexed lexical scope and parameter handoff

Date: 2026-10-16. Status: **material local throughput gain; full SH-27 closure
and clean final-source certification remain open**.

The normal compiler already constructs block-parent and function-parameter
indexes. Two consumers still discarded those facts: indexed name lookup
rescanned the entire syntax tree for the declaration's containing block,
and native parameter setup rescanned the entire project symbol table for
each parameter. This batch replaces those scans with the existing indexes.
It adds no prepass, cache, allocation, worker, or normal tool dependency.

## Changes and invariants

`ir_indexed_find_local` now uses `ir_indexed_block_contains_use`. It obtains
the declaration's smallest enclosing block from `ir_block_parent`, then
applies the same half-open source interval test. The parent-position index
is initialized before acceptance; the null-cache fallback retains the old
scan. Parameter/variable selection, declaration-before-use, name comparison,
and newest eligible declaration ordering are unchanged.

`c_local_parameter` traverses only the current function's parameter list,
retaining the same name comparison and absent-parameter sentinel. The
unindexed fallback still uses the old symbol scan. Native argument
classification, register/stack passing, reference handling, safety modes,
and generated program bytes are unchanged.

The fixed-point compiler SHA-256 is
`f58c5a0746c5040146c37507aca1f6676ec72932a7c5df6e1fbd727ebda62897`.
The retained A/B baseline is array-corrected compiler `ce6e976c...`, not an
older compiler with the array defect. All three bootstrap stages match.

## Same-host paired measurements

Eleven adjacent order-alternated pairs and baseline/null controls per lane
use the corrected process-exit observer and unchanged RAM/output/time gates.
All generated PE bytes and executed exit/stdout/stderr match exactly.

| Lane | Four-CPU paired delta / wins / null floor | Unrestricted paired delta / wins / null floor |
| --- | ---: | ---: |
| Large functions | -32.461 ms / 11 of 11 / 10.391 ms | -37.000 ms / 11 of 11 / 5.786 ms |
| Control flow | -63.946 ms / 11 of 11 / 5.612 ms | -42.162 ms / 11 of 11 / 6.658 ms |
| Small single file | +0.552 ms / 5 of 11 / 0.670 ms | -0.696 ms / 7 of 11 / 1.244 ms |
| Many files | -2.544 ms / 8 of 11 / 3.029 ms | +0.384 ms / 5 of 11 / 4.708 ms |

Negative deltas are faster. Both target lanes exceed null noise and win all
pairs in both profiles. Protected-lane effects are below their null floors;
their paired median ratios are 1.034/0.958 (four CPU) and 0.971/1.006
(unrestricted), within the 5% non-regression gate. The unrestricted small
*independent* medians are 19.108/23.234 ms, a 21.6% difference, unlike the
paired statistic; retain that timing instability rather than hiding it.
The four-CPU matrix's overall `FAIL` is because `--require-gain` was also
requested on these protected lanes: neither proves a speed gain. It is not
a correctness or target-lane gain failure.

An independent 31-pair protected-lane repeat passes exact output and all
guards: small-file paired delta -0.073 ms (17/31 wins, 0.911 ms null,
paired ratio 0.995), many-file -1.008 ms (18/31, 3.809 ms null, ratio
0.983). Its independent medians are 16.063/16.002 ms and
61.482/60.210 ms. No protected-lane speed gain is claimed from these
below-noise changes; the repeat supports non-regression.

Real compiler self-build wins 11/11 pairs: **-313.275 ms paired median**,
with 1.886202/1.537134 s independent medians. Every output matches the new
fixed point. There is no competing heavy benchmark during these samples.

## Fresh constrained-host DMD comparison

A separate normal-default 20-sample run uses the same owned-process affinity
mask `0xF` and pinned DMD 2.112.0 (`5ec3152d...`).

| Workload | OpenC median | DMD median | OpenC/DMD |
| --- | ---: | ---: | ---: |
| Small single file | 0.018403 s | 0.069322 s | 0.265x |
| Many files | 0.058746 s | 0.080870 s | 0.726x |
| Large functions | 0.227998 s | 0.179219 s | **1.272x FAIL** |
| Control flow | 0.082405 s | 0.113966 s | 0.723x |
| Startup/file/allocation | 0.015237 s | 0.072460 s | 0.210x |

Large functions still need **3.974 ms** for the public 1.25x ceiling, or
**12.935 ms** for 1.20x headroom in this run. Other local C/LDC tools remain
absent, so this is not a complete comparator certificate. All available
version, compile, runtime, memory, edited-build and self-build checks pass.
Do not calculate a causal speedup by subtracting the earlier DMD-run medians;
the paired measurements above establish the batch's effect.

## Correctness and memory proof

All 278 native conformance cases pass. The strict stability suite passes
5 clean builds, 5 edited builds, and 20/20 byte-exact compiler generations;
peak private/working set is **227,627,008/54,042,624 bytes**, within unchanged
256/64 MiB limits. Serial/adaptive self-build and four generated-workload
PEs match exactly, as do single- and multi-source invalid diagnostics.
All 25 Windows x64 substrate checks, integer boundaries, array initializers,
and argument-snapshot/concurrent EXE/DLL checks pass.

`tests/sh27_indexed_bindings/` exercises nested and sibling blocks, loop
locals, repeated parameter names across functions/files, eight integer
arguments and a referenced structure. Its guarded verifier passes on both
the baseline and candidate, with exact PE/runtime and serial/adaptive
diagnostics. Four invalid programs reject out-of-block, before-declaration,
sibling-block, and foreign-function parameter use. This verifier runs in
the push/manual production workflow without changing historical rule IDs.

## Diagnostic method and retained reports

An isolated sampler observes only compiler PIDs it launches under the normal
Job/time/RAM guard, briefly suspending and balancing each owned thread's
context capture. It joins the compiler's deterministic source-order function
table to its PE unwind ranges and validates count/order/code anchors. System
export names are joined only to exact unwind-entry starts. No arbitrary-PID
attach, system tracing, stack reads, or OS timer-period change is used.
The Windows contracts are documented by Microsoft for
[thread context capture](https://learn.microsoft.com/windows/win32/api/processthreadsapi/nf-processthreadsapi-getthreadcontext)
and [private high-resolution timers](https://learn.microsoft.com/windows/win32/api/synchapi/nf-synchapi-createwaitabletimerexw).

The sampler's context/owner/finally-resume tests pass 9/9, but it remains
diagnostic-only in ignored `build-output/sh27-index-handoff/`. Sampled large
median is 324.462 ms versus 265.146 ms control; 583 of 788 observations lie
outside compiler functions, largely waiting system thread-pool threads.
These counts are not CPU percentages, inclusive stacks or precise wall
budgets. They prompted inspection of full-scan consumers, not a speed claim.
Only uninstrumented A/B measurements support the gain above.

Raw evidence under that directory:

- `four-cpu-matrix11.json`: `ad2a96d60a9198693c7bcef87e8fdf2ad155bafc7cec165c6e28c3539b97e3a9`.
- `unrestricted-matrix11.json`: `9180cbfd974adb4b8ee9d8120888f90c55ce23b7412d198c7ebe389d01a4eb2c`.
- `four-cpu-dmd20.json`: `2d6f37bb17e91a68a2b01fbcc04194a3f2b5d830fa05873ddec86dce73042977`.
- `selfhost11.json`: `67daa80deb622628cc6faf2cfee3adbbc3438927da910fc9518b8eb605969933`.
- `stability.json`: `386e98d9a5d2a1f87b1eead0a1a55937552ba95c6cdd1df2f2bcfa7e3861a1aa`.
- `bindings.json`: `a20b589b2cf511c77a1aeab6de961e78a4379dce4afe16ac035a24b3c6ee10e1`.
- `protected31.json`: `b0a9bd6320664e8f908a8eaa89195fb770561a60bbf853a545c48f0a9c44b6d5`.

Next: close the remaining large-function margin, using the new critical-path
profile rather than assuming all old semantic costs remain. Import/cycle
queries still rescan complete sources and deserve a retained-graph audit.
Then finish normal-default incremental policy, representative projects and
repeated final-source correctness, memory, comparator, editor and release
certification. This batch does not complete SH-27.
