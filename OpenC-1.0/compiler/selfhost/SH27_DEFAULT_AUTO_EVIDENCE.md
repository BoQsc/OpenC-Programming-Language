# SH-27 adaptive-default candidate: local and first clean proof

Status: **first clean production-policy proof on branch
`codex/sh27-default-auto`; not SH-27 closure**.
This records a production-policy change, not the typed-expression redesign or
a claim of five-compiler parity. The previous default was serial; this
candidate uses the already bounded adaptive two/four-source worker policy
for normal executable builds, with an explicit `--source-chunks=1` artifact
escape hatch. Small inputs remain serial under the adaptive thresholds.

## Guarded same-host comparisons

Every compile was order-alternated, executed under the 512 MiB Windows Job
process-tree limit, checked for execution/output and byte identity, and
retained per-sample JSON in ignored
`build-output/selfhost-sh27/sh27-policy-ab-20260923/` and
`sh27-default-auto-candidate-20260923/`.

| Workload | Same compiler: serial -> auto (11 pairs) | Old default -> candidate default (11 pairs) | Candidate selected workers | Largest observed candidate whole-Job private bytes |
| --- | ---: | ---: | ---: | ---: |
| Large functions | -528 ms; 11/11 wins | -611 ms; 11/11 wins | 4 | ~306 MiB |
| Control flow | -460 ms; 11/11 wins | -517 ms; 11/11 wins | 4 | ~162 MiB |
| Complete compiler self-build | -6.099 s; 11/11 wins | -6.427 s; 11/11 wins | 4 | ~285 MiB |

These are median *paired deltas*, not differences between independent
medians. The baseline/candidate revision comparison used the same candidate
source and required both compilers to produce the candidate's fixed-point
binary. The paired reports are `large-revision-default-pairs.json`,
`control-revision-default-pairs.json`, and
`selfhost-revision-default-pairs.json` in the candidate output directory.

The candidate passed a byte-exact Stage 2/Stage 3 bootstrap, 278/278 native
conformance, 25/25 Windows x64 substrate checks, integer boundaries, and all
13 SH-27 Python harness tests. The extended native proof compared explicit
serial, explicit auto, and flag-free normal `build` on self-build, small,
many-file, large-function, and control-flow projects. The latter two and
self-build selected four workers by default; the smaller projects selected
serial. All outputs matched byte for byte, and single- and two-error invalid
control-flow diagnostics matched exactly. Its report is
`sh27-default-auto-candidate-20260923/native-default-proof.json`.

## What this does not prove

The local host has only pinned DMD64 2.112.0, not the complete five-compiler
set. Its five-run normal-default comparison still measured OpenC/DMD at
**2.376x large functions** and **1.960x control flow**, both well above the
1.25x target. Local CPU/environment and clean Windows runner medians cannot
be mixed to infer a clean-runner ratio. The full report is
`sh27-default-auto-candidate-20260923/production-local-dmd.json`.

This policy is therefore a material wall-time improvement, but SH-27 stays
active. Two independent clean Windows default-mode parity runs,
representative projects, genuine incremental reuse, the first-visit semantic
redesign, and complete memory proof remain open. If the clean proof shows a
material small-project or memory cliff, revise the implementation or policy;
do not waive the gate.

The first candidate clean [run 35894838235](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35894838235)
stopped at the diagnostic-only type-profile proof before comparator timing.
The extended verifier accidentally forwarded `--profile-type-queries` to the
flag-free default `build` command, which accepts no such option. The exact
invocation failed locally in the same way; after restricting that flag to
explicit `artifact`, the local profile proof passed and a command-construction
unit test was added. This run is a harness failure, not a passed clean proof
or evidence of a compiler regression.

The repaired candidate at `447353c` then passed clean Windows
[run 35895744348](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35895744348),
including the normal-default parity-enforcing five-compiler step. This is
**one** successful clean run, not the required two independent runs. A
separate legacy 20-run self-build benchmark exposes a memory-policy conflict:
the four-worker default can reach about 283 MiB private bytes against that
harness's 256 MiB child cap. The 512 MiB Job-level proof in the workflow did
not fail, but SH-27 cannot quietly disregard the narrower standing guard.
The bounded-IR experiment and its still-open 64 MiB working-set issue are
tracked in `SH27_COMPLETION_ROADMAP.md`.
