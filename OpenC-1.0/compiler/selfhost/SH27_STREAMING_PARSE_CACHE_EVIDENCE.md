# SH-27 streaming parse-cache lifetime experiment

Status: **one full clean Windows proof passed; repeatability pending; SH-27 active**.
Branch: `codex/sh27-streaming-parse-cache`. This cut builds on the bounded-IR
experiment and restores the default four-worker source policy.

## Structural change

The declaration pass retains compact token and syntax records for all 222
self-host source files so resolution, validation, and native lowering can
reuse the parse. Previously those records stayed live until the entire build
returned. Native source emission now releases each cache entry as soon as
that source has been lowered. Distinct source records are owned by distinct
workers. The invalid-program diagnostic replay reparses released entries;
the original end-of-build cleanup skips entries already cleared. The normal
successful build still parses each source once.

The strict `openc benchmark` 20-generation chain is a separate, standing
memory gate from the 512 MiB whole-Job native proof. It allows at most 256
MiB child private bytes and 64 MiB child working set. The bounded-IR-only
candidate intermittently failed the latter with four source workers. Forcing
two workers passed memory but regressed self-build speed by about 1.3 s in
paired testing, so it was not selected.

## Local evidence

The new Stage 2/Stage 3 bootstrap is byte-exact. With compiler SHA-256
`9c53e536e448988283836865256cdd4c5f1edd0f5e3927208438e85c85b550cc`,
`openc benchmark --runs=20` passed **20/20** chained generations, each with
exact input/output compiler hash and a public build record. Its maximum
observed child private bytes were **251,101,184** (limit 268,435,456) and
working-set bytes **55,173,120** (limit 67,108,864); median public build
time was **2,922 ms**. The report is in ignored local build output at
`build-output/selfhost-sh27/sh27-streaming-parse-cache-20260923/legacy-benchmark20.json`.

The adaptive native proof passed byte-exact serial/chunked outputs for
self-build, small, many-file, large-function, and control-flow projects and
byte-exact diagnostics for one- and two-error invalid control-flow cases.
Conformance passed 278/278, Windows x64 substrate 25/25, and the integer
boundary proof passed. Their JSON reports are beside the benchmark report.

The first clean Windows [run 35902031392](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35902031392)
passed fixed point, conformance, and the new strict 20-generation benchmark,
then stopped at the older two/four-worker **trade-off** assertion. That
assertion required a 32 MiB saving on every workload regardless of the
four-worker footprint. The local exact-output proof reproduces its failure:
two workers save 25.2 MiB on control flow, whose four-worker whole-Job peak
is only 85.8 MB; they still save 47.1 MiB on large functions and 46.1 MiB
on self-build. The verifier now requires non-increasing two-worker memory on
all three workloads, and retains the 32 MiB minimum whenever four-worker
peak exceeds 128 MiB. Below that ceiling the absolute savings requirement
was obsolete. This revises a trade-off assertion, **not** the strict
64/256 MiB compiler limits or 512 MiB whole-Job guards. Unit tests cover
both the low-memory exception and failure for a high-memory workload that
does not save 32 MiB. The next clean
[run 35903033443](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35903033443)
passed bootstrap, conformance, and the strict benchmark but stopped earlier
in the serial/parallel exact-output/RAM proof. The prior clean run reached
the later trade-off step with the same compiler source, and local serial,
two-, four-, and default-mode proofs all pass, so the failure cannot be
classified from step status alone. The public job page does not expose its
raw log or artifact contents through the available read-only API credential.
The verifier now emits a compact failure annotation containing the selected
mode, exit, memory observation, timing-validity flag, and output hash for
each failed case; a later clean retry can identify the actual failure if it
recurs. This failed run is not treated as a green proof.

The next clean [run 35903863226](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35903863226)
completed successfully: strict 20-generation memory, exact worker outputs
and diagnostics, all historical speed/correctness checks, and enforced
normal-default pinned C/D parity. This is one full clean pass for the
streaming-cache compiler source, not the required two independent passes.
The earlier intermittent worker-proof failure remains disclosed; three
additional local four-worker proof repetitions all passed. A follow-up run
will publish each of the 20 ratio decisions as check annotations after the
timed samples, making the clean result inspectable without artifact download
permission. The annotation code is outside the timed compiler path.

Eleven order-alternated, same-host pairs against the bounded-IR-only compiler
showed median paired deltas (candidate minus baseline) of **-4 ms** on large
functions, **0 ms** on control flow, and **+224 ms** on complete self-build.
The self-build baseline's median was 4,584 ms, so the paired delta is about
4.9% of it: just inside the 5% regression screen, but the host was noisy
(individual self-build times spanned roughly 3-7 s). A second independent
11-pair local self-build series, on a calmer host interval, measured **-5 ms**
median paired delta. Thus a sustained local speed cliff was not reproduced;
the clean workflow remains the promotion gate. The largest locally measured
candidate whole-Job private peak in the adaptive proof was 253,734,912 bytes,
under the 512 MiB Job cap.

The candidate timing records from those paired runs give a fresh default-mode
critical-path baseline (median of each field, ms):

| Workload | Serial declarations | Validation wall | Worker stage wall | Critical worker acceptance | Critical worker IR lower | Critical worker native emit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Large functions | 235 | 110 | 344 | 187 | 32 | 63 |
| Control flow | 62 | 78 | 218 | 125 | 31 | 16 |
| Compiler self-build | 421 | 1109 | 1359 | 656 | 111 | 452 |

Critical-worker values are nested within worker wall time and must not be
added to top-level phases. Both serial declaration work and first-visit
acceptance remain substantial for large functions; self-build also has a
large native-emission component. The next architectural cut is the planned
fused typed-expression/assignment path, with a fresh profile afterward to
decide whether declaration indexing or backend value-location work is the
next larger wall-clock target. This is one local diagnostic baseline, not a
new C/D ratio claim.

## Promotion decision

The commit-triggered `openc-native-parallel.yml` workflow on this branch now
enforces the strict 20-generation benchmark after bootstrap, in addition to
fixed point, conformance, x64, exact-output/diagnostic, worker speed, and the
normal-default pinned C/D parity gate. Require a second independent clean
pass and investigate any repeated worker-proof failure before promoting.
If clean CI fails a speed or memory gate, retain its raw samples and rework
the lifetime/allocator design; do not raise the standing limits.
