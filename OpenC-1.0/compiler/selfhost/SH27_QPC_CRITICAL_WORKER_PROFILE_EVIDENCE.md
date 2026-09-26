# SH-27 opt-in QPC critical-worker probe (isolated; not for promotion)

Date: 2026-09-24. Base: production commit `dd8adc6d5a3f664e13abee59f81b7990b631d780`.

This branch adds `artifact --profile-qpc --timings=...` as a compiler-private
Windows probe. It resolves documented `QueryPerformanceCounter` and
`QueryPerformanceFrequency` through the already imported `LoadLibraryExW` and
`GetProcAddress`, then caches the function address for workers. The ordinary
PE import layout is unchanged. The flag is opt-in and requires a timing file.
Its JSON `critical_worker_qpc` object contains the measured worker wall,
frequency, exclusive index/acceptance/IR-lower/native-emission ticks, and
their residual. Expression/assignment/calls are explicitly nested acceptance
subphases and must **not** be added to worker wall or to one another:
assignment is part of expression. The critical chunk is chosen by QPC wall
when the probe is enabled; existing millisecond counters remain for context.

## Guarded proof and limitations

`python OpenC-1.0/compiler/selfhost/bootstrap_sh27_native_parallel.py
--output-dir OpenC-1.0/build-output/selfhost-sh27/sh27-qpc-profiler-bootstrap-20260924`
passed all three stages. Stage 2 and Stage 3 were byte-exact:
SHA-256 `a668a278fceff4394b6829fc63d5ca770cc0006faa175191a9e3e1506c4f2d3f`,
7,206,400 bytes. The bootstrap's 512 MiB working-set/private guard passed;
Stage 1/2/3 peak working sets were 56.8/64.3/57.2 MiB, and peak private
bytes were 182.8/249.3/244.3 MiB. Thus Stage 2 is **not proven under the
strict 64 MiB working-set limit**.

The first strict-64-MiB large-corpus opt-in run was stopped at 67.1 MiB
working set. A 128-MiB guarded diagnostic run completed at 70.22 MiB
working set and 157.25 MiB private; the unprofiled run of the same corpus
completed at 71.74/160.86 MiB. Control completed at 47.78/79.75 MiB with
profiling and 47.76/79.77 MiB without it. These are single-run diagnostic
observations, not an A/B performance or memory equivalence proof.

For both corpora, profiled and unprofiled generated executables had identical
SHA-256, also matching the known production-baseline artifacts from the
`sh27-direct-immediate-matrix-20260924` corpus:

| Corpus | Generated executable SHA-256 |
| --- | --- |
| Large functions | `81d22e50b31b4c958bce1e3da02c7c114d67ca815934b58b2902cb97cbb76c4e` |
| Control flow | `31b8906a62a954d885b37fe8a03a94010eefaa619648f42626620ca455590e50` |

The probe perturbs timings significantly. One profiled/unprofiled pair had
large critical-worker millisecond wall 781/531 and process wall 1930/1115;
control was 422/360 and 1453/669. Scheduling and QPC-call overhead are not
separated by these pairs. **The QPC numbers below must not be used as
unprofiled baseline milliseconds or as evidence of a speed improvement.**
The source should remain isolated until overhead and the 64-MiB issue are
resolved under repeated paired guarded tests.

## Raw high-resolution critical-worker account

Windows QPC frequency was 10,000,000 ticks/second in both runs. All columns
below are nonoverlapping, and the residual is worker wall minus the other
four columns. The JSON reports exact raw ticks and `nonoverlap_consistent`.

| Corpus | Worker wall | Acceptance | Native emit | IR lower | Index | Residual |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Large functions | 785.127 ms | 465.734 ms (59.3%) | 213.106 ms (27.1%) | 50.920 ms (6.5%) | 29.486 ms (3.8%) | 25.881 ms (3.3%) |
| Control flow | 422.052 ms | 275.783 ms (65.3%) | 61.563 ms (14.6%) | 68.372 ms (16.2%) | 8.784 ms (2.1%) | 7.551 ms (1.8%) |

The first two ranked nonoverlapping phases cover 86.4% of large-worker wall
(acceptance + emission) and 81.5% of control-worker wall (acceptance + IR).
Nested acceptance measurements: large expression 274.211 ms, of which
assignment is 218.810 ms; calls group 124.830 ms. Control expression
263.180 ms, of which assignment is 181.275 ms; calls group 7.389 ms. These
nested times are not additional worker time. The large/control difference in
the calls group is a falsifiable semantic-workload distinction, not proof of
an implementation cause.

## Next measured decision

If this profiler is needed further, lower its per-function QPC read rate or
use function sampling with explicitly estimated IR/emission subshares. First
measure opt-in versus unprofiled overhead in repeated ABBA pairs under the
same RAM guard; do not silently substitute sampled estimates for exact phase
ticks. Independently inspect acceptance's expression/assignment paths and
large-corpus call-rule path, because those account for most nested acceptance
work. Keep the probe off the production branch until the compiler's normal
output/imports, diagnostics, and strict RAM remain verified.

Ignored local evidence directory:
`OpenC-1.0/build-output/selfhost-sh27/sh27-qpc-profiler-bootstrap-20260924/`
contains `bootstrap-current/bootstrap-current.json`, each corpus's
`profile-*/timings.json` and `guard128.json`, the initial strict-failure
`profile-large/guard.json`, and `unprofiled-*/` comparison files.
