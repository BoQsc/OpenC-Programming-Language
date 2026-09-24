# SH-27 semantic/IR B3 control-cost batch: no-go

Status: **rejected for throughput, isolated**. This batch combined two
mechanisms on the Phase B2 source: pointer-order validation can prove from
the existing call index that no `memory.alloc` call exists before scanning
relational nodes, and the required expression-ownership census carries a
compact operator code in kind-disjoint `call_cache` slots so lowering does
not repeatedly decode operator text. The visitor resolves `i32`/`i64` type
IDs once per eligible source rather than per recursive node. No default
production source was changed.

The stable production compiler accepted this source with `check --project`.
Guarded Stage 1/2/3 bootstrap passed; Stage 2 and 3 were byte-exact with
SHA-256 `75754ecfb37b0718ea40efaf245b6d7ce922f1a4211e470477f0a2a5772307be`.
The bootstrap used 512 MiB guards; Stage 2 reached 67,936,256 bytes working
set, so this does **not** prove the strict 64 MiB self-build gate. The local
ignored report is
`build-output/sh27-function-semantic-ir-b3-bootstrap-20260924/bootstrap-current/bootstrap-current.json`.

An adjacent 11-pair baseline/candidate matrix with a baseline-vs-baseline
null, exact PE/runtime checks, and 512 MiB Job/working-set guards finished
with **overall FAIL**. Its local ignored raw report is
`build-output/sh27-function-semantic-ir-b3-matrix-20260924.json`.

| Lane | Candidate minus baseline paired median | Wins | Null floor | Decision |
| --- | ---: | ---: | ---: | --- |
| Large functions | -22 ms | 7/11 | 57 ms | Below null noise |
| Control flow | +1 ms | 4/11 | 16 ms | Flat/regressive |

All generated binaries and runtime results matched the frozen production
baseline byte-for-byte. The large-lane null control contained a 2.986 s
sample, so the 57 ms noise floor is meaningful evidence against a speed
claim on this run. The control critical-worker median was 156 ms for both
baseline and candidate: candidate acceptance fell from 94 to 16 ms, while
candidate IR lowering rose from 16 to 109 ms. Those phase medians are
diagnostic and not additive wall-time predictions. The operator/pointer
batch did not remove enough critical-path work to improve control.

No strict repeated self-build, full conformance, or independent real-project
speed certificate was run for this rejected candidate. Phase B2 had 0/223
self-build sources eligible; B3 does not broaden eligibility. Do not merge
this as a performance win. The next throughput architecture must make the
accepted typed expression facts the **direct input to native lowering**
without a second recursive semantic walk, and cover the compiler's real
expression forms. It must separately measure where pointer-order and
visitor time went, then pass both protected lanes above their same-run null
floor before promotion.
