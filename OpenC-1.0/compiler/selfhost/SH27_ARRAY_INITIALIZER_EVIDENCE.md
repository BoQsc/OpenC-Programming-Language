# SH-27 array-root and operand isolation correction

Date: 2026-10-16. Status: **local correctness and paired non-regression
verified; throughput closure and hosted final-source certification remain open**.

During the lowering-scratch investigation, inspection found two independent
array defects. The old nearest-array-parent index admitted every expression
descendant, including call arguments and binary operands, as an array
element. The indexed lowerer also published an operand range before lowering
children, so their call/conversion operands entered the array's range.

The retained `91573ac5...` compiler compiled the focused reproducer and printed
`112123\n` in the required call order, but exited **2**: its first array
element was wrong. The memory/time guards passed. This is an actual generated
program failure, not an optimization hypothesis.

## Correction and scope

- A shared token-delimited iterator selects only expression roots between
  top-level commas/closing braces. Nested calls, parentheses, brackets,
  aggregate braces, quoted delimiters, and trailing commas do not add false
  elements. No syntax-node postorder assumption is used.
- Array adjacency now appends these roots in written order, removing the old
  whole-source descendant/nearest-parent searches and sorted insertion.
- Indexed and non-indexed lowering collect child result values first, then
  publish one contiguous array operand range. Temporary buffers are sized
  from actual element count. This does not retain the rejected scratch arena.
- Element lowering uses the declared element type, materializes a referenced
  value where needed, and emits explicit numeric widening conversions so
  stored width/float representation agrees with the array element layout.
- Acceptance requires the exact positive element count and compatible values;
  fixed-array copies with different extents are not lossless conversions.
- The native writer rejects wrong array operand counts and out-of-element or
  out-of-array member extents before emitting writes.

These implement the existing Core `OPENC-ARRAY-INIT-001` and
`OPENC-EVAL-ARRAYINIT-001` requirements. They add no new language syntax or
normal compilation dependency and change no arithmetic safety mode.

## Local proof

Three guarded bootstrap stages reached the identical compiler SHA-256
`ce6e976c4a302cbf5f74e476134eb4bfee1676accfb56f22c3ebd2b242b3d01d`.
All 278 existing native conformance fixtures pass. The focused verifier
passes exact check/build/runtime behavior and serial/adaptive PE identity
for calls, mixed and nested expressions, evaluation order, parentheses,
trailing commas, quoted comma/brace text, nested aggregate initializers,
i32-to-i64 and f32-to-f64 widening, u8 element stores, and referenced structs.
It also rejects six invalid count/type/range/copy-extent programs in `check`
and `artifact`, with exact serial/adaptive diagnostics and no executable.
The same verifier **fails on the retained old compiler**, so it detects the
original gap rather than merely checking that the new compiler runs.

The strict self-build suite passes 5 small builds, 5 edited builds, and
20/20 byte-exact compiler generations under the unchanged 256 MiB child
private / 64 MiB child working-set gates. Peak private bytes were 228,716,544
and peak working set was 54,431,744. Native source-chunk serial/adaptive
output and invalid diagnostics match exactly; integer boundaries, argument
snapshots (including concurrent DLL/EXE use), and all 25 x64 substrate checks
also pass. TinyCC is used only as the optional layout/ABI test oracle.

Eleven order-alternated pairs per lane compare the correction with retained
compiler `91573ac5...`, including adjacent baseline/null controls:

| Lane | Four-CPU paired delta | Null floor | Unrestricted paired delta | Null floor |
| --- | ---: | ---: | ---: | ---: |
| Large functions | -4.430 ms | 8.160 ms | +2.733 ms | 8.988 ms |
| Control flow | -9.028 ms | 4.727 ms | +0.889 ms | 4.539 ms |
| Small single file | +0.355 ms | 0.680 ms | +0.497 ms | 1.689 ms |
| Many files | -3.013 ms | 7.193 ms | +2.650 ms | 3.444 ms |

Positive deltas are slower. All builds, execution oracles, exact PE bytes,
and memory guards pass. No paired median slowdown exceeds 5%; the
unrestricted small-file *independent* medians differ by 12.7%, versus 3.1%
for paired ratios, with the 0.497 ms paired delta below its 1.689 ms null
floor. Keep both statistics rather than treating the independent medians as
an established regression or hiding their difference. Real compiler
self-build is flat: 1.962298/1.965354 s independent medians, -18.791 ms
paired median and 7/11 wins, with all outputs at the new fixed point.
No whole-toolchain speedup is claimed. In particular, the observed control
gain is not attributed to arrays: that v1 workload contains no arrays.

The source fixture is `tests/sh27_array_initializer_operands/`; the command is
`python compiler/selfhost/verify_sh27_array_initializers.py --compiler OPENC.exe
--output REPORT.json`. It is also attached to the push/manual production CI
workflow. The 278-fixture historical corpus and its rule-ID mapping are not
rewritten by adding this focused regression.

Ignored local evidence is under `build-output/sh27-array-operands/`:
`baseline-build-v2.json`, `baseline-run-v2.json`, `regression-rejects-old.json`,
`bounded/bootstrap-current/bootstrap-current.json`, `bounded-regression.json`,
`conformance.json`, `stability.json`, `chunks.json`, `integers.json`,
`arguments.json`, `x64.json`, `four-cpu-matrix11.json`,
`unrestricted-matrix11.json`, and `selfhost11.json`. Key SHA-256 identities:

- Detecting regression on old compiler: `bb4cbff75815c50c840395938ee7d61181a4d22762631c19b7b4efdaabe5a80d`.
- Passing focused regression: `cc20a93ba1360496d6c8e7f8faf44e3e6eda608e7099291c68e296f3be17923b`.
- Strict stability: `0155ad36895c80d8f1f09b6fdebbeff5d449b5dcceb8dda3850f9f66c70658d9`.
- Four-CPU pairs: `0f5e55c2f2bfd09b23d496a149a621406c0892bb6104926cc28421e3175fafe3`.
- Unrestricted pairs: `c18ca45e49925c0d883898f0b812149f5048c75aca125cc5ac65c03c7e70530f`.
- Self-build pairs: `0ed82161c5d2756e91dfbc50ca1f67a27c865a5f7009c6ad94565c1aa3ade32c`.

The current four-CPU C/D deficits in `SH27_FOUR_CPU_PROFILE_EVIDENCE.md` remain
active. Correcting array generation does not close the 47/8.5 ms first-visit
throughput margins, normal-default incremental policy, real-project breadth,
or the final editor/release gates.
