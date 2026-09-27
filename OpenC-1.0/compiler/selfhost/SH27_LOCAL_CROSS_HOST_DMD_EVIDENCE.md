# SH-27 local cross-host DMD gap on the latest compiler

Status: **FAIL for the 1.25x local DMD diagnostic; not a new-source
regression and not a five-compiler certification** (2026-09-27).

Two independent clean Windows-2025 runs of production source `1b58d5e`
passed all 20 pinned C/D ratios. To test whether that result generalized to
the user's four-logical-CPU Windows 10 machine, the unchanged `CORPUS.json`
v1 (`ac35a710344f247454efdd039c13e6a84809fc97e9dc96cd49cd70b42361ef61`)
was run locally with 20 samples per clean workload, default OpenC source
chunks, rotated tool order, exact execution checks, and the production
compile/link wall-time harness. The pinned local DMD 2.112.0 executable has
SHA-256 `5ec3152d183b5a7f4c3abb67d01a7055a247d7d3c79e6041ec33b9f95c913bf5`.
MSVC, Clang, and LDC were unavailable locally, so this is a DMD-only
cross-host diagnostic. The corpus harness used its declared 512/512 MiB
per-compiler guard; this run is not a substitute for the separate strict
64 MiB working-set / 256 MiB private self-build gate.

The two fixed-point OpenC executables were verified by SHA-256 before the
runs: earlier hosted-green source `1b58d5e` was
`d0c18a385d1589db21da0c9ec5684e442bf828124d46c489aed29c4dddb6d9e7`;
the latest opt-in-COFF source `0477c39` was
`0c83deac588cfb81968f652cd7a77f28fc0f9ffa2c9342992a511711e634e0ca`.
Both raw reports recorded exact outputs and compiler execution/memory checks.
The earlier-source comparison was measured after the latest-source run, not
interleaved with it, so cross-revision millisecond changes are directional,
not a paired speedup claim. The **within-run** OpenC/DMD ratios are decisive:

| Workload | Earlier OpenC / DMD, seconds (ratio) | Latest OpenC / DMD, seconds (ratio) | Latest OpenC reduction needed for 1.25x |
| --- | ---: | ---: | ---: |
| Small single file | 0.1665 / 0.1275 (1.306x) | 0.1600 / 0.1185 (1.350x) | 11.9 ms |
| Many files | 0.2585 / 0.1615 (1.601x) | 0.2385 / 0.1510 (1.579x) | 49.8 ms |
| Large functions | 0.5385 / 0.3360 (1.603x) | 0.5190 / 0.3375 (1.538x) | 97.1 ms |
| Control flow | 0.3450 / 0.2250 (1.533x) | 0.3050 / 0.2045 (1.491x) | 49.4 ms |
| Startup, file, allocation | 0.1555 / 0.1370 (1.135x) | 0.1390 / 0.1270 (1.094x) | Already within 1.25x |

On the latest large-function run, median OpenC internal time was 375 ms,
including a 242.5 ms native worker wall; the first two-source chunk was
critical in all 20 samples. Its sampled acceptance, IR-lowering, and native
emission phases were 126/31/31 ms (nested expression/assignment/call
figures must not be added to acceptance). On control flow, internal time was
172 ms with a 140.5 ms worker wall; the first one-source chunk was critical
in 19/20 samples, with about 125 ms acceptance in a representative sample.
The local benchmark-authoritative 20 samples and full timing records are in
ignored `build-output/sp27-identity-reuse/final-source-local-dmd20.json` and
`prior-source-local-dmd20.json` beside this source tree's root.
Their SHA-256 values are, respectively,
`966642cf7f8af9c00c73317074b74e6f9caf3873e29333153c46acca81b1781a`
and `af2ba592cf08495abb11d24db426ce66517ecd79a717ebd330bdb502a48030e0`.

The earlier hosted-green executable also misses the local DMD gate, while
the latest executable improves absolute OpenC medians in every local lane.
This rejects the hypothesis that the opt-in COFF changes introduced the
local parity failure. It does **not** prove an across-host OpenC speedup or
invalidate the two hosted results: DMD and OpenC absolute times both differ
substantially by host. It does show that two passes on one hosted runner class
are insufficient evidence for a general C/D-class throughput claim.

An additional adjacent, order-alternated 11-pair earlier/latest direct-PE
matrix compiled byte-identical executables and passed exact program behavior
and every guard after its null-control paths were shortened. Large-functions
latest-minus-earlier paired median was **+49 ms** (3/11 wins) against a
**139 ms** null-control noise floor; control flow was **-2 ms** (6/11 wins)
against **31 ms** null noise. Neither difference is an accepted source-speed
effect. The ignored `prior-vs-latest-direct11-shortpath.json` report has
SHA-256 `458ded860c087fccec7eca5cca250b7ce10d70944f72214dcc8fd25867c4f169`.
The first matrix attempt was invalid because its long output-directory name
made the null-control `.build.json` path exactly 260 characters: PE emission
succeeded but the compiler returned failure on sidecar publication. The
matrix harness now creates a compact run directory and rejects over-budget
sample paths before compiling. Its 23 orchestration unit tests pass. The
invalid matrix is not used for a speed or correctness conclusion.

Next: treat the 97/49/50 ms latest-source large/control/many-file deficits as
local architectural budgets. The existing whole-source worker balance does
not offer an easy four-worker repartition; prioritize a measured
first-visit acceptance-to-lowering cut and the many-file fixed/declaration
path, then use adjacent guarded same-host A/B and repeat the full hosted gate
on the final source. Keep the cache opt-in until its cold and edited-build
economics justify a normal-default policy. SH-27 remains open.
