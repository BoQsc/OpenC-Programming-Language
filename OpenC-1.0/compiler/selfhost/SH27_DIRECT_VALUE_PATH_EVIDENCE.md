# SH-27 native direct-value chain experiment

Status: **isolated checkpoint; initial adjacency cut fails the two-lane
throughput selection**. Branch starts at compiler source `6794d56`; it does
not include the rejected indexed-call or direct-slot-layout prototypes.

For an adjacent, single-use integer/bool SSA result in the same basic block,
the native emitter can leave the producer's result in RAX for the first
consumer instead of storing it to the stack and reloading it. A function-wide
use-count scan proves single use. Eligibility is deliberately confined to
existing scalar producer/consumer handlers whose first machine operation is
the matching RAX load. Integer arithmetic's checked-overflow code remains
inside those handlers. Calls, aggregates, bounds/other control operations,
cross-block uses, references, and uncertain layouts keep the original path.
The handoff may continue across multiple adjacent instructions; if the
expected load/store is absent, native lowering rejects the function rather
than emit wrong code. This changes executable bytes and therefore requires
behavioral comparison, not baseline-vs-candidate PE identity.

The implementation spans `backend_native_scalar_part3.p` (eligibility,
function emission, use counts), `backend_native_scalar_part1b.p`
(materialization handoff), `backend_native_scalar.p` (per-function state),
and `backend.p`/parallel timing/JSON emission (measured eliminated-pair,
code-byte, and stack-frame counters). A direct-value pair means one native
stack store and one reload were omitted. Stack frames are still reserved
according to the original layout; the counters make that explicit.

Initial proof on the isolated Stage 3 compiler:

- Three guarded bootstrap stages passed with a byte-exact Stage 2/3 fixed
  point. Stage 3 self-build recorded **3,353** direct handoffs,
  **6,625,705** native code bytes, **4,222,112** total frame bytes, and
  **59,400** maximum frame bytes.
- SH-19 native scalar/aggregate tests passed **63/63**. SH-27 integer
  boundary tests passed, including checked overflow behavior.
- Three invalid projects (`call_argument_count`,
  `arithmetic_type_mismatch`, `assignment_conversion_checked`) had the same
  baseline/candidate exit code and byte-identical stdout/stderr.
- Stage 3 self-build peaks were **255,533,056** private and **59,494,400**
  working-set bytes. Stage 2 working set reached **67,678,208** bytes, above
  the separate strict 64 MiB historical self-build limit; this is a
  provisional risk, not proof that the strict Stage 3 chain fails.

The shared guarded 11-pair matrix passed generated runtime/output,
per-compiler binary determinism, and RAM checks. Because native bytes change,
baseline/candidate PE identity was intentionally not required. The initial
adjacency cut has a large-function wall signal but fails the two-lane rule:

| Workload | Median paired candidate-minus-baseline | Wins | Null noise floor | Median direct pairs / native code-byte change |
| --- | ---: | ---: | ---: | ---: |
| Large functions | -121 ms | 7/11 | 80 ms | 1 / -16 bytes |
| Control flow | -29 ms | 8/11 | 38 ms | 769 / -12,304 bytes |

The large-function speed observation cannot be attributed to one eliminated
pair. The dominant generated arithmetic is already lowered through the
small-integer immediate fusion, so this adjacent-only cut scarcely reaches
it. A separate successor must prove a handoff through that immediate
fusion, not treat this checkpoint as a completed throughput result. The
strict 20-generation RAM gate and clean pinned C/D comparator remain open.
Raw local reports are under ignored `build-output/selfhost-sh27/sh27-direct-value-*`;
the matrix report is
`build-output/selfhost-sh27/sh27-direct-value-matrix-20260924.json` in the
main workspace.
