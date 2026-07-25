# Test execution status

On 2026-07-20, all eight canonical D test commands and all four informative Python bootstrap tests passed on the recorded Windows host. `run_all.py` records the D matrix; `run_maintained.py` builds, executes, and records the four maintained OpenC programs.

On 2026-07-26, SH-5 native Windows closure also passed: public `openc build`
rebuilt the OpenC compiler with the shipped TinyCC backend while DMD, DUB, and
Python were hidden, and the resulting C source and executables were
byte-identical across native stages.

Conformance execution is recorded separately by the canonical `openc validate` command. Local success is not evidence for untested targets or independent review.
