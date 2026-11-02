# SH-27 same-type scalar binary fast path: clean throughput no-go

Status: **isolated and rejected for throughput**, not merged into the
production compiler. Source commit `881799b` on
`codex/sh27-first-visit-typed` adds a direct valid-case exit for equal-type
numeric `+`, `-`, and `*` during binary acceptance. It leaves all contextual,
literal, pointer, conversion, invalid, and other operator cases on the old
rule path. The branch contains the exact 21-line source cut; it is not a
complete typed-expression redesign.

Guarded Stage 1/2/3 bootstrap passed with byte-exact Stage 2/3 fixed point.
The Stage-3 compiler SHA-256 was
`847bf0b40406b4d3eacdfb031b89a4dc03b0f736f3a105f4dd0853ddb0be37f7`.
This was the 512 MiB process-tree bootstrap guard, not the strict 20-chain
64/256 MiB certificate. Both generated SH-27 workloads compiled and executed
with exact baseline output and binary bytes in the local matrix; all compiler
jobs stayed under its guards. Full conformance/strict 20-chain was not run
because the candidate failed the speed gate.

| Same-revision guarded matrix | Large functions | Control flow |
| --- | ---: | ---: |
| Local paired median, 11 pairs | -29 ms; 7/11 wins | -14 ms; 8/11 wins |
| Local baseline-vs-baseline null floor | 70 ms | 38 ms |
| Clean Windows 2025 paired median, 11 pairs | -1 ms; 7/11 wins | -1 ms; 7/11 wins |
| Clean null floor | 5 ms | 2 ms |

Negative means candidate faster. Neither lane exceeds its same-run null
floor. The [hosted batch](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35940837530)
correctly failed its mandatory two-lane gain gate and uploaded its evidence.
The local raw report is the ignored
`OpenC-1.0/build-output/sh27-first-visit-typed/matrix-01.json` in the
isolated worktree.

Decision: no promotion and no claim that the broader first-visit typed path
has been solved. This branch only bypasses one family of rule predicates
after operand types have already been resolved. The clean result rules out
that shortcut as a meaningful SH-27 architecture cut on its own.
