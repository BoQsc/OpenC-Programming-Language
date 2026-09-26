# SH-27 exact-input snapshot for partitioned compiler objects

Status: **isolated local fixed-point/correctness/RAM PASS; clean hosted repeat
pending; SH-27 remains active**.

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

This closes the exact-input no-op front-end cost for the isolated partition
path. It does **not** close edited-source speed or normal-default C/D parity:
the edited 32-object path still validates the whole project and is not
proven faster than ordinary direct OpenC compilation. The cold 32-object
path is also expensive. The next architectural batch must reduce changed-
source semantic/acceptance work and bounded COFF link overhead, then test
normal-default policy on retained projects. Final-source parity, editor,
release, and clean hosted gates remain.
