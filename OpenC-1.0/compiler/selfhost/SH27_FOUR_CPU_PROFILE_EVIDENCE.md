# SH-27 four-logical-CPU resource profile

Date: 2026-10-15. Status: **current-source local deficit reproduced; SH-27
active**. No compiler edit or benchmark threshold change produced these data.

## Exact-source hosted proof and its limit

The corrected observer's clean [run 38693328802](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/38693328802)
at `459d3bce5af585c0d081463118f52d57b3ba706c` passed all 20 normal-default
MSVC/Clang/DMD/LDC ratios, with 20 samples per compiler/workload. Its compiler
was the unchanged retained `91573ac579fc66df94b8ce7123bd7dcf9798b01eb05f02a8dfb0b6c2abdeb959`.
Raw samples explicitly use `parent_perf_counter_launch_to_process_exit_v2`.
Large-function medians were OpenC 0.381313 s and DMD 0.543063 s (0.702x);
control was 0.204787/0.436455 s (0.469x). Argument-snapshot regression passed.

Artifact `11954120098` was downloaded and inspected, not inferred from green
job status. Its 94,035,189-byte ZIP SHA-256 is
`870d63fbd1ccbac00f0971d0cae24bec91e93a6720e109546c2fc174e33be775`.
The earlier exact-binary Oct 14 hosted pass used the previous observer;
this is one clean corrected-basis pass, not final repeated certification.

The unrestricted local 20-sample corrected-basis result on the 12-logical-CPU
i5-12450H was 1.135x large and 0.922x control. Hosted wins cannot erase a
failure on a separately pinned local resource profile.

## Controlled affinity restriction

The evidence wrapper set affinity **only on its own Python process**, before
launching any benchmark/compiler children. Original/system mask was 4095;
requested and read-back mask was 15 (`0xF`), providing logical processors
0-3. Normal Windows child affinity inheritance applies to the compiler,
its threads, and comparator/linker processes. The wrapper restores its own
original mask before exiting. No existing user process or system setting
was changed.

This does **not** claim four physical cores, a CPU-topology equivalence, or
reproduction of the unavailable older machine. It pins an additional
resource-constrained workload on the current Windows 10 host. C: placement,
the v1 corpus, normal-default OpenC policy, unchanged compiler hash, and
official pinned DMD 2.112.0 (`5ec3152d...`) remain fixed. OS caches are not
flushed and antivirus is not controlled. The standard RAM/output/time guards
remain in use.

| Four-CPU profile, 20 samples per cell | OpenC median | DMD median | OpenC/DMD |
| --- | ---: | ---: | ---: |
| Small single file | 0.016561 s | 0.064510 s | 0.257x |
| Many files | 0.058496 s | 0.077290 s | 0.757x |
| Large functions | 0.263754 s | 0.180722 s | **1.459x FAIL** |
| Control flow | 0.140244 s | 0.109815 s | **1.277x FAIL** |
| Startup/file/allocation | 0.014490 s | 0.068473 s | 0.212x |

All observed compilation, execution, memory, and DMD identity checks pass;
two DMD ratio checks fail. The other three comparators are also absent
locally, so the report is not a full five-compiler certificate.

The same-run large/control budgets to the public 1.25x ceilings are
**37.852/2.975 ms**; internal 1.20x headroom needs **46.888/8.466 ms**.
Matching DMD itself needs 83.032/30.429 ms. Do not subtract deltas measured
on the unrestricted host or another runner from these medians.

Unprofiled critical-worker medians on this resource profile are large:
172 ms wall, 94 acceptance, 16 IR lower, 16 native emit, 15.5 index;
control: 109 wall, 54.5 acceptance, 15 IR lower, native emit/index below the
coarse timer resolution. Expression/assignment medians (62.5/54.5 large,
47/31 control) are **nested within acceptance**. These are medians from
different samples and must not be added as one exact wall ledger. The
compiler's internal millisecond timer remains coarser than the corrected
parent observer.

## Next architecture gate

This reopens the first-visit semantic/lowering work even though the retained
binary passes the hosted suite. Candidate selection must include this
four-CPU profile, unrestricted protected lanes, self-build, exact output and
diagnostics, and the existing memory limits. Recheck two/four-worker economics
in this profile, but do not assume scheduling alone can remove the semantic
budget. A change confined to the entire measured IR/native emission phases
is not automatically sufficient for the 47 ms large-function margin.

Raw report: ignored `build-output/sh27-precise/four-cpu-pinned20.json`, SHA-256
`d2c0176e23c461060d64674a33d20988603f3bfa7fc3a6b45ce122c7825ff7ee`.
`run_four_cpu_profile.py` preserves the original invocation;
`run_four_cpu_command.py` applies the same profile to further guarded Python
evidence scripts and records its own hash. This is diagnostic orchestration,
not a runtime/compiler dependency.

The subsequent lowering-scratch batch reached fixed points and exact output,
but its generated large/control effects did not exceed null noise and real
self-build was flat (-5.752 ms, 6/11 wins). Its compiler edits were removed.
This concerned per-expression call/aggregate/scope buffers, not the earlier
43-allocation source-constructor arena hypothesis. Raw hashes:
`sh27-lowering-scratch/matrix11.json` =
`8984f4f5c506944acfe5f3bd105f403e6cd0832b0371f3127de432a143e2225b`;
`full-selfhost11.json` =
`9a640b241e5c93d538f84b149b1395beb995362d9db5b842406cdebac3b641bb`.
Do not promote it as a throughput fix.

## Source worker control on the array correction

On 2026-10-16, the fixed-point array-corrected compiler `ce6e976c...` was
compared with itself using explicit four versus two source workers in this
same affinity profile. Eleven order-alternated pairs per workload produce
identical executables/runtime results and pass all guards. Two workers are
slower by a paired median **66.426 ms** on large functions and **14.121 ms**
on control flow; they win 0/11 and 3/11 pairs respectively. A separate
adjacent same-binary/default-policy matrix measures null floors of
12.185/7.731 ms. These are serially executed diagnostic controls, not a DMD
comparison or a claim that the 2026-10-15 medians are unchanged.

Keep four source workers. Reducing the worker count is not the remaining
throughput solution. Reports under `build-output/sh27-precise/` are
`four-cpu-two-workers-large11.json`, `four-cpu-two-workers-control11.json`,
and `four-cpu-workers-null11.json`; their resource-profile records pin
the compiler, affinity, commands, wrapper hash, and raw samples.
