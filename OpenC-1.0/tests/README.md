# Test execution status

On 2026-07-20, all eight canonical D test commands and all four informative Python bootstrap tests passed on the recorded Windows host. `run_all.py` records the D matrix; `run_maintained.py` builds, executes, and records the four maintained OpenC programs.

On 2026-07-26, SH-5 native Windows closure also passed: public `openc build`
rebuilt the OpenC compiler with the shipped TinyCC backend while DMD, DUB, and
Python were hidden, and the resulting C source and executables were
byte-identical across native stages.

On 2026-07-26, SH-6 passed from the deterministic relocated standalone
package: packaged Stage 1 built Stage 2, Stage 2 built a byte-identical Stage 3,
native semantic/IR parity covered 263 authored fixtures (117 accepted IR
comparisons and 149 exact rejections), conformance passed 268/268, and all 4
maintained programs built and executed. The retained repository matrix also
passed 9/9 debug builds, 9/9 release builds, 8/8 D test commands, and 4/4
Python bootstrap tests.

The post-tag conformance-evidence milestone expands the repository corpus to
278/278 passing fixtures, covers all 466 active rules with dedicated fixtures,
and supplies accepting/rejecting pairs for all 174 grammar productions. The
historical RC8 package count above remains unchanged.

Conformance execution is recorded separately by the canonical `openc validate` command. Local success is not evidence for untested targets or independent review.
