# Test execution status

All eight canonical D test commands and all twenty-one Python source tests pass on
the recorded Windows host. `run_all.py` records the D matrix;
`run_maintained.py` uses the verified native compiler by default and records
native build/execution of the four maintained OpenC programs.

On 2026-07-26, SH-5 native Windows closure also passed: public `openc build`
rebuilt the OpenC compiler with the shipped TinyCC backend while DMD, DUB, and
Python were hidden, and the resulting C source and executables were
byte-identical across native stages.

On 2026-07-26, SH-6 passed from the deterministic relocated standalone
package: packaged Stage 1 built Stage 2, Stage 2 built a byte-identical Stage 3,
native semantic/IR parity covered 263 authored fixtures (117 accepted IR
comparisons and 149 exact rejections), RC8 conformance passed 268/268, and all
4 maintained programs built and executed. Current mainline conformance passes
278/278; RC9 repeats that complete corpus from the relocated package. The
retained repository matrix also
passed 9/9 debug builds, 9/9 release builds, 8/8 D test commands, and 4/4
Python bootstrap tests.

The post-tag conformance-evidence milestone expands the repository corpus to
278/278 passing fixtures, covers all 466 active rules with dedicated fixtures,
and supplies accepting/rejecting pairs for all 174 grammar productions. The
historical RC8 package count above remains unchanged.

On 2026-07-27, SH-7 moved the complete gate to the OpenC-authored native
`openc validate`: 278/278 fixtures pass with zero infrastructure failures,
including 35/35 runtime executions and 153/153 diagnostic contracts. The
required package gate does not execute the retained D seed.

On 2026-07-28, SH-8 made the OpenC-native compiler the default
compiler-under-test. The native daily workflow passes structure, source
completeness, coverage, 10/10 Python tests, 278/278 conformance, 4/4 maintained
programs, and 6/6 demos. Its unchanged-input cache reruns zero fixtures. Full
and release workflows force fresh native validation; the D seed remains an
explicit optional audit only.

On 2026-07-28, SH-9 added the OpenC-authored public native CLI. The 12/12
command contract covers help, version, target, active and historical rule
explanation, valid and invalid `check` records, lexical/flow/semantic human
diagnostics, `run`, and argument forwarding. All 6 demos now execute through
public `openc run`; 15/15 Python source tests pass.

On 2026-07-28, SH-10 added the OpenC-authored native formatter, project
context inspector, and deterministic test runner. The 21/21 command contract
covers check/write/idempotence/invalid-source formatting, all context views,
name-sorted discovery, filtering, no-run checks, direct and manifest execution,
stable hashes, failure classification, and target rejection. The same contract
runs against relocated Stage 3; 21/21 Python source tests pass.

On 2026-07-28, SH-11 added OpenC-authored `openc lsp --stdio`. The 19/19
contract covers lifecycle and capability negotiation, full-document open,
change, and close synchronization, native rule-ID diagnostics, SH-10
formatting, protocol error states, shutdown/exit semantics, byte-accurate
`Content-Length` framing, and byte-identical independent transcripts. The
transcript schema and five focused Python tests pass; required execution does
not invoke the retained D seed.

On 2026-07-28, SH-12 added a bounded synchronized project workspace and seven
native semantic methods. The 23/23 contract covers document symbols, typed
hover, cross-document definition and references, deterministic completion,
prepare-rename, safe project rename, rejection of keywords and declaration
collisions, project-root isolation, synchronized close, transcript-schema
validation, and byte-identical semantic responses under opposite document-open
orders. Three focused Python tests cover the fixture, schema, and verifier
helpers.

Conformance execution is recorded separately by the canonical `openc validate`
command. Local success is not evidence for untested targets or independent
review.
