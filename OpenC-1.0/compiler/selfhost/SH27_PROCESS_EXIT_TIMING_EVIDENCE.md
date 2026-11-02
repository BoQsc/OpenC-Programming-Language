# SH-27 process-exit timing correction and candidate rejection

Date: 2026-10-15. Status: **measurement correction verified; no compiler
optimization promoted; SH-27 active**.

The retained production compiler is unchanged:
`91573ac579fc66df94b8ce7123bd7dcf9798b01eb05f02a8dfb0b6c2abdeb959`.
The final-source Oct 14 hosted artifact was inspected locally and verifies
one full five-compiler `PASS_PARITY` for that exact binary; see
`SH27_ARGUMENT_SNAPSHOT_EVIDENCE.md`. Its separately retained local 1.263x
large-function result is not erased by that hosted pass.

## Measurement defect and correction

`windows_process_measure.py` previously slept after each memory sample and
reported elapsed time only after final memory accounting, output reads,
decoding, and temporary-file cleanup. Consequently a completed compiler
could wait for the next sampling interval, and harness work was included in
its reported time. Ordinary SH-27 samples used 10 ms intervals. These are
additive measurement costs, **not evidence that they explain the entire
historical C/D deficit**.

Two new regression tests failed on the old harness: a quick Python process
with a one-second sample interval reported 1.008 s; a 100 ms timeout with
that interval returned after 1.014 s. The correction waits on the Windows
process handle, waking on exit or the next memory/deadline sample. It records
the parent monotonic elapsed interval immediately after process completion,
before final memory/output work. It is still parent-observed launch-to-exit
wall time, not kernel process CPU time or a claim of zero launch overhead.

The additive `timing_basis` identifies
`parent_perf_counter_launch_to_process_exit_v2`; `measurement_wall_seconds`
retains total harness wall. Elapsed values retain six decimal places. Job,
child-private, working-set, timeout, disk, and captured-output limits are
not raised or removed. Non-finite sampling/timeout inputs are rejected.

All **20** production-harness tests pass, including the existing parent/child
aggregate memory-limit tests. A delayed-output-reader test proves that its
400 ms injected reading cost is excluded from compiler time. The nine
candidate-matrix decision tests also pass.

A seven-pair, order-alternated old/new harness control ran identical Python
`pass` commands at a 100 ms sampling interval. Old/new medians were
106.000/22.877 ms; all memory/timeout checks passed. This measures removal
of harness delay, not a compiler optimization. The control pins the old
source at `a9a955d` and retains each sample and both measurement-source hashes.
Never subtract its delta from an unrelated compiler run.

## Broad candidate batch and independent integration check

All five frozen compilers reached byte-exact Stage 2/3 fixed points. The
ordinary generated executables and runtime outputs were exact against the
retained baseline; all compile/execution/RAM checks passed. No syntax or
safety semantics were intentionally relaxed.

The candidates were repeated semantic-function-context reuse, bounded literal
operator call lowering, both together, LEA-only packed-record addresses, and
LEA addresses with an adjacent same-block constant-field proof. The initial
coarse-harness matrices were insufficient. All five were therefore compared
together with the corrected harness, not selectively retried until green.

Median paired candidate-minus-baseline milliseconds in that 11-pair matrix:

| Candidate | Large | Control | Small | Many files |
| --- | ---: | ---: | ---: | ---: |
| Function context | -0.822 | +0.589 | -0.037 | -1.150 |
| Literal operator | -6.885 | +1.588 | +0.042 | +0.541 |
| Context + operator | -1.285 | -7.243 | +0.338 | -0.677 |
| LEA only | -0.481 | -2.863 | +1.407 | -1.593 |
| LEA + constant field | -8.184 | -2.873 | +0.445 | +2.088 |

The null floors were 4.605/7.420/0.492/1.818 ms respectively. Literal-operator
and constant-field variants had initial large-function signals (7/11 and
9/11 wins). They were not promoted on that single matrix.

A separate 11-pair integration matrix retained the same baseline, both
individual candidates, and their combined compiler. Large-function paired
deltas were **+3.994/-2.932/-2.227 ms**, with **3/7/7 wins** and **15.726 ms**
null noise. None reproduced a qualifying target-lane gain. Control deltas
were -3.516/+1.626/-2.943 ms against 9.155 ms noise. The combined many-file
-1.454 ms result exceeded its 1.319 ms floor, but does not solve the target
large-function gap.

Decision: **remove all candidate compiler edits**. Preserve their source
patches and binaries as experiments; do not merge one just because it passed
correctness or happened to improve a single comparator invocation. The
earlier feature-inventory variant was also removed: its large/control paired
changes were -1/-2 ms against 12/2 ms null floors.

The rejected literal-operator compiler additionally passed 278/278
conformance, 20-generation strict self-build, integer boundaries, and exact
serial/adaptive compiler/generated executables and invalid diagnostics.
Strict peak private/working set was 227,377,152/54,063,104 bytes, below
256/64 MiB. Its eleven self-build pairs were flat (-11.322 ms, 6/11 wins).
The focused 88-case fixtures covered empty/ASCII/escaped/Unicode/dynamic
expectations, maximum-width span bounds, and ordinary-module isolation; an
activation fixture demonstrably fails with lowering disabled. These proofs
do not rescue the non-replicating speed result.

Its separate corrected-harness 20-sample pinned DMD run measured large
0.195377/0.175656 s = 1.112x; all five available DMD ratios passed. This is a
**rejected experimental compiler**, not certification of retained source or
an improvement attributable to that source. Overall `FAIL_PARITY` also
records that MSVC/Clang/LDC are unavailable locally.

## Retained evidence

A fresh corrected-harness 20-sample run of the **unchanged retained compiler**
passed every available DMD ratio, execution, and memory check:

| Workload | OpenC median | Pinned DMD median | OpenC/DMD |
| --- | ---: | ---: | ---: |
| Small single file | 0.016133 s | 0.064328 s | 0.251x |
| Many files | 0.061643 s | 0.082529 s | 0.747x |
| Large functions | 0.210893 s | 0.185754 s | 1.135x |
| Control flow | 0.105389 s | 0.114285 s | 0.922x |
| Startup/file/allocation | 0.015253 s | 0.068930 s | 0.221x |

The compiler pin is the unchanged `91573ac5...`; DMD remains official 2.112.0
at `5ec3152d...`. This Windows 10 / Intel i5-12450H host has 12 logical CPUs,
normal-default source policy, C: storage, OS caches not flushed, and antivirus
state neither controlled nor queried. Its overall report is `FAIL_PARITY`
because the three other comparators are absent, not because a measured DMD
ratio failed. This is one local observation, not cross-host certification.
The difference from the historical 1.263x must not be attributed wholly to
the timing correction: no adjacent old/new-harness compiler comparison
isolated that effect, and the absolute time difference exceeds one sampling
interval. No new compiler-speed claim follows from this run.

Raw reports, generated fixtures, controls, rejected patches, and compilers
remain under ignored `build-output/sh27-precise/`, `sh27-record-address/`,
`sh27-semantic-context/`, and `sh27-feature-inventory/`.

| Report under `sh27-precise/` | SHA-256 |
| --- | --- |
| `timing-control.json` | `4d5905fcb93c0995a0d68dbac3d36e5fd60d6cde92e51b7b0240cfe02db1ea84` |
| `matrix11.json` | `2c26004b941f194dea3d81d7b93c1d5a38f016e703856664fd38b84f65a6d6a6` |
| `integrated-matrix11.json` | `a8618ef6671c162385d4bdeedb62c6abdbd2483d4fa6f511bd15ea33e53b2ab4` |
| `unchanged-pinned20.json` | `89d3ced69adddcafa650c4e75785dc83b257cec23593e3509386d93452713a6c` |
| `operator-selfhost11.json` | `89454d20203716899d6480f54ea1defa24d5bc769bbfc12364f1e467b6b576a2` |
| `operator-stability.json` | `86a78da3fa18bae41821ff319a4ce28f63b7e6d6507bc6dfb1d4761f1d909004` |
| `operator-conformance.json` | `3dd7d80aeab7a152e4ba75ad2414e6e4cddef948b7b75b7f1cfc4d4577354c3b` |
| `operator-regression-activation.json` | `84f301faaec640af6c486d01309304060d2d6cf38ca5ffa23107b0538e4a1f9c` |
| `operator-regression-detects-disabled.json` | `d59fee1a8fb9f583749a2d0fdc1142c132572d2dd4acfe7894db1ef36ef82271` |
| `operator-chunks.json` | `6d8d24dc9939dff801b1a41c466e84e99a8ee32f654821b66717e162f4773033` |
| `operator-pinned20.json` | `26680c71c3508f6f142c4b242169becc1e9401a838fe54a4b9d22790bc74edd5` |

Next: obtain clean hosted comparisons with the corrected timing basis,
retain the explicit Windows CPU/storage/resource profile, and resume the
normalized function-scoped semantic/lowering architecture. Do not repeat
these helper variants to seek a favorable median. Default incremental policy,
representative projects, repeated final-source C/D certification, and
editor/release gates remain required for SH-27 closure.
