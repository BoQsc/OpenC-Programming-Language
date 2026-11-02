# SH-27 exact-input snapshot for partitioned compiler objects

Status: **isolated local and clean hosted fixed-point/correctness/RAM PASS;
no normal-default cold speed gain or final C/D parity proof; SH-27 remains
active**.

The 32-object source-partition cache now publishes an authenticated
whole-project *validation snapshot* only after a successful link. Its key
contains the exact project source bytes, project root and manifest, compiler
executable SHA-256, target/schema, partition count, and source-worker option.
An exact-input hit authenticates every saved COFF object again, relinks them,
and skips declaration, resolution, flow, and acceptance work. A changed byte
misses that snapshot and runs the full diagnostic path before using any
partition object. The earlier per-language-module snapshot still uses its
own key and manifest schema.

The source SHA-256 at its byte-exact Stage 2/3 fixed point is
`5ee5588523253df035b2e6263bc9266570af3f95dd7a5634c3fd4bb492dff671`.
Ignored local raw reports are `OpenC-1.0/build-output/sp27-cache-snapshot.json`,
`sp27-strict20-snapshot.json`, and `sp27-large-coff-snapshot.json`.
The exact source commit is `40ac1af8`; its clean hosted
[module/partition proof](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/36276374228)
passed with artifact `OpenC-SH27-module-COFF-36276374228` (ID
`10916868274`). The independent
[branch speed batch](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/36276374233)
failed its required cold speed gain: large-functions paired median was
-0.005 s against a 0.010 s null-noise floor, and control flow was +0.001 s
against 0.008 s null noise. Its correctness and determinism gates passed;
the failure is a real missing speed signal, not a snapshot correctness failure.

- On the actual 228-source compiler project, a cold 32-object build had
  0 hits/32 misses. An exact warm build had 32 hits, zero misses, zero
  validation/declaration/resolution milliseconds, and the same executable
  SHA. Its single local observed wall time was 0.542 s; sampled child
  private/working-set peaks were 43,925,504 / 34,656,256 bytes. This is
  an opt-in no-op observation, not repeated normal-default C/D parity.
- Truncating one content-addressed saved object invalidated the snapshot;
  the full path rebuilt that group (31 hits/1 miss) and produced exact
  output. A same-size/same-mtime change to real body code invalidated the
  snapshot, rebuilt one group, and matched a fresh uncached 32-object
  link byte-for-byte. Its single observed wall time was 5.347 s, versus
  37.668 s for a fresh 32-object link on this host. A declaration-projection
  change invalidated all 32 groups. Cached and uncached invalid-source
  diagnostics still matched with no executable produced.
- Existing multi-module object-cache, large-COFF overflow, and linked
  self-host fixed-point tests passed. Strict stability passed 13/13 checks
  and 20/20 byte-exact chained compiler generations. Its maximum sampled
  child private/working-set peaks were 247,177,216 / 65,355,776 bytes,
  below the enforced 256/64 MiB caps.

On the clean hosted runner, the same compiler SHA passed the complete
source-partition cache proof: cold 0/32 in 11.597 s; exact-input warm 32/32
with validation skipped in 0.221 s; body edit 31/32 in 2.783 s; fresh
body rebuild in 17.144 s; projection edit 0/32 in 12.224 s; corrupted
object recovered at 31/32; and invalid-source diagnostics matched. The
hosted strict lane passed all 13 checks and 20/20 chained generations,
with maximum sampled child private/working-set 247,332,864 / 66,060,288
bytes. The three representative workloads passed 3/3 each; ordinary
compiler self-build cold/warm/edit medians were 3.000/3.036/2.989 s.
The 2.783 s partition edit is a single opt-in observation, not paired
proof that it beats the normal 2.989 s edit median.

The cache proof now accepts `--partitions=N` (2 through 32) so the same
compiler, mutation, fresh-link comparison, corruption recovery, and RAM
checks can be run across several object granularities. One local sweep
of the 228-source compiler, with four flow workers, produced:

| Objects | Cold miss | Exact warm | One-body edit |
| ---: | ---: | ---: | ---: |
| 2 | 8.231 s | 0.359 s | 5.051 s |
| 4 | 10.836 s | 0.414 s | 4.347 s |
| 8 | 14.072 s | 0.420 s | 4.888 s |
| 16 | 15.204 s | 0.424 s | 4.162 s |
| 32 | 26.349 s | 0.542 s | 5.347 s |

All five full proofs passed, including exact fresh output and invalid
diagnostics. Raw ignored reports are
`OpenC-1.0/build-output/sp27-cache-snapshot-{2,4,8,16}.json` and the
32-object report above. These are single, non-randomized observations,
not a partition-policy selection. They show that smaller object counts
greatly reduce cold overhead, while edit timing is nonmonotonic and still
dominated by approximately 1.4-1.7 s of full-project validation plus
approximately 2.0-2.9 s of lowering/link work. A robust default requires
paired trials and an architectural cut to those costs.

This closes the exact-input no-op front-end cost for the isolated partition
path. It does **not** close edited-source speed or normal-default C/D parity:
the edited 32-object path still validates the whole project and is not
proven faster than ordinary direct OpenC compilation. The cold 32-object
path is also expensive. The next architectural batch must reduce changed-
source semantic/acceptance work and bounded COFF link overhead, then test
normal-default policy on retained projects. Final-source parity, editor,
release, and final-source clean hosted parity gates remain.
