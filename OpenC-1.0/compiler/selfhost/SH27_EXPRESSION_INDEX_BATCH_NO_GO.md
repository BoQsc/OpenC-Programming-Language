# SH-27 expression-index architecture batch: no-go

Status: **four layouts built and tested; no index source promoted**. The
retained certified compiler is still `27a1f830...` at `6ad7ba9`. The separate
native constant-materialization prototype does not change this decision.

## Layouts and correctness

The original accelerator has an eight-byte head and an eight-byte successor
for each source position. The first candidate replaces the dense successor
with occupancy words and next-nonempty-word links: `16 * ceil(capacity/64)`
bytes, versus `8 * capacity`, and a reverse pass over words rather than bytes.
The second inlines its successor query with baseline-x64 BSF instructions,
reached only for a nonzero word. The third additionally packs head IDs to u32
when the node count fits, with a full-width fallback. The fourth retains a
dense constant-time successor but uses u32 positions/heads where they fit,
halving their combined requested storage in the usual case.

No variant adds a second retained successor array or a source-sized node
sidecar. The packed head layouts preserve order and IDs; the occupancy
layout publishes bits while building existing expression-start lists.
All four candidates pass guarded stage-2/3 bootstrap fixed point and exact
generated application PE/runtime comparisons on all measured original lanes.
The initial direct-query emitter rejected an unsupported imm8 value at
bootstrap; it was corrected to SUB 1 before the passing candidate was tested.

An independent dense oracle copies all five old query implementations from
`439c4d1`, not the new successor helper. The first layouts pass 144 range/
capacity cases. Packed-head/dense-u32 probes pass both head widths on each
case: **288 cases**, checking every successor position, five query paths,
unaccelerated fallbacks, ties, empty/reinitialized indexes, sparse starts,
zero-length nodes, clipped/outside starts and final partial words. Capacities
are 0, 1, 63, 64, 65, 127, 128, 129, 4095, 4096, 4097 and 8193. Guard words
after both allocations are unchanged. Tests include every single-bit BSF
input plus zero, u32 maximum head IDs and a full-width ID above u32. Probe
executables are serial/adaptive byte-identical and run successfully.

These are differential and bounded-process proofs, not full conformance or
strict 20-generation certificates. Those larger gates were not spent on
index candidates whose target gain failed selection.

## Original-corpus throughput

All jobs remain serial, normal-default, affinity mask 0xF, guarded and measured
from launch to exit. Pairs rotate order and retain an adjacent baseline/null
control. No sample is discarded. Negative delta means faster.

| Series / candidate | Large delta / wins / null | Control delta / wins / null |
| --- | ---: | ---: |
| First 11 / helper occupancy | +6.522 ms / 3 of 11 / 30.883 ms | -0.653 ms / 6 of 11 / 8.672 ms |
| First 11 / direct occupancy | +2.631 ms / 5 of 11 / 30.883 ms | +3.475 ms / 4 of 11 / 8.672 ms |
| Second 11 / direct occupancy | -13.186 ms / 9 of 11 / 5.346 ms | -1.834 ms / 8 of 11 / 5.016 ms |
| Second 11 / packed heads | -12.092 ms / 7 of 11 / 5.346 ms | -2.479 ms / 7 of 11 / 5.016 ms |
| Independent 31 / direct occupancy | -0.675 ms / 18 of 31 / 19.374 ms | not requested |
| Independent 31 / packed heads | +5.011 ms / 12 of 31 / 19.374 ms | not requested |
| Dense u32 11 | -4.676 ms / 7 of 11 / 15.370 ms | -4.723 ms / 6 of 11 / 5.888 ms |

The second 11-pair series qualifies two large effects once. The independent
31-pair required-gain report fails both. Dense u32 also fails to qualify a
target gain. Small/many-file effects in these series remain below their null
floors. Lower requested bytes alone are not a throughput win. No index
candidate is credited with closing the constrained-host DMD gap.

## Retained evidence

Under ignored `build-output/sh27-expression-occupancy/`:

- `batch-four-cpu11.json`: `84a052e7a5a1b6bd5e52ca15b2276f33b0e8bbb23f82cafe6417d9f77911ae79`.
- `heads-four-cpu11.json`: `b24ec16fa0209630e780a59185b7cf1c3d424c1a1484303c36f5992e118681a7`.
- `large31.json`: `e9914c08058f83420732ca0e6d2bf78fdc1f73f3607a674d8623653c28701dde`.
- `dense32-four-cpu11.json`: `e36ad047e260424806fb4ac811976eac9eb49a2340d720963b761b4999f30e5a`.
- `heads-probe.json`: `9210578f992f0a746a6e4558f8c897b0c101bc5cc6f070406173ea3da6ed93b3`.
- `dense32-probe.json`: `2a5f51b873c3e5ae43c493d0ea98acbc5165528759325d25323ad683947b5754`.
- `compact-heads-source.patch`: `e3b9254f75bc84b74279cae79aaec1da4be797fa3d4bbee6c3b10dcd7f373889`.
- `dense32-source.patch`: `9b1098c82076d54a601a61defe86ed08de8f59a77e346fc745a68471bf8fafeb`.
- The dense oracle, probe, guarded verifier, bootstrap reports and binaries.

Candidate SHA-256 values in layout order are
`14918e4d1cff58dd5694c4c8fe685859bce656d85ab2797ed9c1577bbcaa6e9a`,
`4b7ccbd53b5443bc201c3c98a845f957aefff9d65c6b8401052d6e2f9b1f4e6f`,
`d78f72edcd364118a2b23f61b6ea1d316c35d40272881980294e152e9fc431b3`,
and `849a6a4dddef54ad2e2bcfedfae79e633aef058d35ab80708031b968c289a2d5`.
Archived patches cover the packed-head and dense-u32 source; do not claim
separate archived patches for the first two intermediate candidates.

Next target materialized native values and resolved parameter properties,
not more index-width variants without a new measured opportunity. Original
cold DMD, default incremental, real-project, repeated final-source and release
requirements remain mandatory.
