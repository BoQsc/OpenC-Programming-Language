# SH-27 scalar acceptance/lowering fusion: correctness pass, speed no-go

Status: **isolated source candidate, not promoted**. Source commit
`31f44504c2665c03d812263366416704b9dacf05` was benchmarked from the
isolated `codex/sh27-lowering-fusion` worktree. The clean hosted source tree
was reproduced at `54a4def` on `codex/sh27-lowering-fusion-ci`; its compiler
source and project manifest were byte-identical to the isolated candidate.
No part of this candidate has been merged into the production compiler.

The candidate folds scalar assignment and binary validation into the already
required native IR-lowering traversal. A one-bit syntax visitation record
marks rules actually covered; unresolved or invalid cases replay the old
category-order validator for exact diagnostics. `check` retains its old
validation path. This removes legacy whole-expression *scan loops*, unlike
the rejected eager typed-operation arena: on the proof corpus it omitted
293,392 old assignment/binary scan-node visits for large functions and
59,024 for control flow, while still checking 57,601 and 10,817 rules
respectively. The rule-predicate work moved into lowering; it was not
eliminated.

## Correctness and memory

- Guarded Stage 1/2/3 bootstrap reached a byte-exact Stage 2/3 fixed point.
  Stage 3 child peak private/working set was 255,963,136/59,662,336 bytes;
  Stage 2 was 256,245,760/59,932,672 bytes. These bootstrap jobs had the
  512 MiB process-tree guard, not the strict Stage-4 child thresholds.
- Focused large/control proof passed 8/8 and 4/4 cases, with byte-exact PE
  artifacts and identical execution. Targeted invalid lvalue and
  short-circuit cases matched diagnostics and failed-artifact behavior; the
  implementation routes uncovered invalid cases to legacy replay.
- Full native conformance passed 278/278, with 79 exact diagnostic
  observations and no infrastructure failures. The outer conformance Job
  peaked at 28,872,704 private bytes.
- Strict chained self-build passed 20/20 closures/public records. It reported
  median build 3,860 ms and validation 1,297 ms; maximum child private/
  working set was 252,403,712/55,382,016 bytes, below the 256/64 MiB
  limits. The outer 512 MiB Job peaked at 261,619,712 private bytes.

Local ignored reports are under the isolated worktree's
`OpenC-1.0/build-output/sh27-lowering-fusion/` directory, including
`proof-01.json`, `conformance-01.json`, and `benchmark20-01.json` with their
guard companions. The frozen Stage-3 compiler SHA-256 was
`4a35c39bc67fa0f7670d351ca8fcd3eb615b89b14bc871483aeb4c00a890b8e4`.

## Paired throughput decision

The local 11-pair guarded matrix gave large-functions **-98 ms**, 7/11 wins,
against an 84 ms null floor, but control-flow **-15 ms**, 6/11 wins, against
a 43 ms null floor. Thus even the local result failed the required two-lane
gate. The raw local matrix is
`build-output/selfhost-sh27/sh27-lowering-fusion-matrix-20260924.json` in the
main worktree.

The [clean Windows 2025 batch](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35938985209)
failed the gain gate more decisively: large-functions **-2 ms**, 6/11 wins,
and control-flow **+10 ms**, 3/11 wins; the null floor was 10 ms in each
lane. The hosted run generated its matrix and uploaded a 21 MB evidence
artifact. Negative values mean the candidate was faster. Its correctness
and memory results do not rescue the absent reproducible speed gain.

Decision: do not promote or combine this source with other changes under a
speed claim. The mechanism eliminated counted scans but not critical-path
wall. The next architecture cut must directly reduce first-visit acceptance
work or restructure ownership/parallel scheduling, then face the same clean
two-lane matrix. This experiment specifically falsifies “remove the scalar
validator sweep” as a sufficient SH-27 solution.
