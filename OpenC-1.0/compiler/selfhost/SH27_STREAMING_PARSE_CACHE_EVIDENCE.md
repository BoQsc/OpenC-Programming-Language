# SH-27 streaming parse-cache lifetime experiment

Status: **local proof passed; clean Windows CI pending; SH-27 active**.
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

Eleven order-alternated, same-host pairs against the bounded-IR-only compiler
showed median paired deltas (candidate minus baseline) of **-4 ms** on large
functions, **0 ms** on control flow, and **+224 ms** on complete self-build.
The self-build baseline's median was 4,584 ms, so the paired delta is about
4.9% of it: just inside the 5% regression screen, but the host was noisy
(individual self-build times spanned roughly 3-7 s). The clean workflow must
confirm there is no sustained self-build cliff. The largest locally measured
candidate whole-Job private peak in the adaptive proof was 253,734,912 bytes,
under the 512 MiB Job cap.

## Promotion decision

The commit-triggered `openc-native-parallel.yml` workflow on this branch now
enforces the strict 20-generation benchmark after bootstrap, in addition to
fixed point, conformance, x64, exact-output/diagnostic, worker speed, and the
normal-default pinned C/D parity gate. Do not promote from the local proof
alone. If clean CI fails a speed or memory gate, retain its raw samples and
rework the lifetime/allocator design; do not raise the standing limits.
