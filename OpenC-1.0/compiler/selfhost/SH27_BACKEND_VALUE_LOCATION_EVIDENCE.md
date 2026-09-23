# SH-27 native value-location prototype

Status: **rejected, not promoted**. Isolated source commits `ad2f5ef` and
`84ba536` on `codex/sh27-backend-value-location` start from compiler source
`6794d56`, with no call-summary experiment from the other rejected branch.

The native function emitter previously wrote a reference-origin graph into
`value_slots` during `native_analyze_values`, then overwrote every slot before
the first native instruction was emitted. That graph had no reader. This
prototype removes the dead dataflow writes. The emitter's existing per-IR
native-layout scan also now proves whether all instruction values need at
most one aligned eight-byte stack slot. In that general case, stack offsets
are derived directly from SSA IDs, with no slot-map allocation or second
per-value layout walk. Wide or over-aligned aggregates retain the old
per-value layout and slot map. This is source-level value-location selection,
not a benchmark-name special case, and no codegen semantics or checked
arithmetic mode was intentionally changed.

The ownership seam is `backend_native_scalar_part3.p` (layout proof and
allocation), `backend_native_scalar_address.p` (analysis), and
`backend_native_scalar.p` (`native_slot` lookup). To promote, compare emitted
bytes and diagnostics on representative scalar and aggregate programs,
run guarded 11-pair large/control/self-build throughput, and rerun the strict
20-generation RAM gate. The clean DMD gap on the prior scalar-flow source was
57.25 ms large and 8.25 ms control. Less-contended critical-worker medians
put the prior native emit stage at 32 ms large and 16 ms control, and IR lower
at 78/47 ms; these are nested phase observations, not additive wall-time
credit. A native-only reduction cannot be assumed to close the large gap.

Initial proof: checked-out-source Stage 1/2/3 bootstrap passed under its
512 MiB guard with byte-exact Stage 2/3 compiler output. The SH-19 native
scalar/aggregate verification passed **63/63**, including deterministic PE
bytes, recursion/calls, pointer widths, aggregates, and unwind checks.
Bootstrap peak private was 260,358,144 bytes; peak working set was
67,387,392 bytes. The latter is 272 KiB over the separate strict
64 MiB self-build working-set gate, so that gate remains **unproved**. This
was Stage 2; Stage 3 peaked at 59,568,128 bytes. The candidate's Stage 3
compiler is under ignored
`build-output/selfhost-sh27/sh27-backend-value-location-bootstrap-20260924/`.

The shared guarded 11-pair matrix passed all generated compilation, execution,
byte-exact binary, and RAM checks, but not the paired speed-selection rule:

| Workload | Median paired candidate-minus-baseline | Candidate wins | Same-run null noise floor |
| --- | ---: | ---: | ---: |
| Large functions | -46 ms | 6/11 | 136 ms |
| Control flow | +11 ms | 4/11 | 34 ms |

The large critical-worker native-emit subphase had a -31 ms median paired
delta, but the whole compiler gain was below null noise and control flow
regressed. These phase clocks are noisy and cannot justify promotion.
Neither the clean DMD gap nor the strict self-build RAM gate is closed.
The raw matrix is at
`build-output/selfhost-sh27/sh27-backend-value-location-matrix-20260924.json`
in the main workspace. A larger backend architecture would need to reduce
IR lowering and emission together, not merely simplify slot layout.
