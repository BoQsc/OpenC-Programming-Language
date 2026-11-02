# SH-27 typed-operation prebuild: rejected

Candidate `codex/sh27-typed-pipeline` at `5bc95f8` built a source-scoped,
indexed eight-word-per-syntax scalar operation arena. It accepted name,
literal, binary, assignment and call facts in dependency order and passed
them to native lowering. Unsupported or invalid sources fell back to the
existing diagnostic path. This was an experiment, not a promoted compiler
change.

The guarded Stage 1/2/3 fixed point passed with a 512 MiB job cap. The
generated large workload specialized 8/8 sources and the control 4/4. Their
generated executables were byte-identical to baseline and ran successfully.
Ten targeted invalid-source cases preserved exit status, stdout and stderr.
The candidate's counters reported 140,035 and 27,075 purported avoided
legacy first visits in large and control respectively. These count new facts
without legacy inference; they are not a measured subtraction from baseline
work.

The parent's ignored local 11-pair report is
`C:\Users\Windows10_new\Documents\OpenC Programming Language\OpenC-1.0\build-output\selfhost-sh27\sh27-typed-pipeline-matrix-20260924.json`.
All generated-compile, runtime, byte-exact and RAM checks passed, but the
throughput gate failed: large paired median **+2 ms**, 5/11 wins, 50 ms null
floor; control **-6 ms**, 7/11 wins, 11 ms null floor. In the critical worker,
large expression time rose 63 ms and acceptance 16 ms while assignment fell
93 ms and calls 47 ms; critical wall rose 16 ms. Control expression rose
15 ms while assignment fell 78 ms and calls 16 ms; critical wall was flat.
These nested, rounded phase values are not additive. They show work shifted
into eager expression construction instead of disappearing.

The old assignment/binary validators did skip specialized sources. However,
the new evaluator recursively revisited the syntax graph, performed indexed
record lookups and the same rule/type checks, then allocated an arena beside
legacy caches. Call validation still ran afterward. The next experiment
should fuse validation into the already-required lowering traversal, replay
the old acceptance path on error for exact diagnostics, and avoid a second
full syntax arena. Do not promote this prebuild or claim SH-27 parity from its
activation counters.
