# SH-27 validation-error arena lifetime and RAM headroom

Status: **local and clean hosted fixed-point/correctness/memory PASS;
SH-27 remains active**.

The first large-COFF source revision was correct on the focused cache test,
but [hosted module proof run 36269809764](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/36269809764)
failed its three-run representative compiler self-build. The failure was the
second repetition's edited normal build: exit 70, `OpenC checked failure`,
with the Job already near the 256 MiB private limit. The large-COFF overflow,
cache, bounded-reader, selected-module, and 24-file steps passed before it.
That workflow did not reach the strict 20-generation step, so its status
cannot certify the source.

Inspection of `backend_emit.p` found a source-sized semantic-error record
arena allocated before validation and held until the entire build returned.
After successful flow/error reporting, native emission and its workers never
read that arena. This cut allocates it only when semantic validation runs,
releases it after all diagnostics/error paths are decided, and explicitly
releases it on each validation early return. It does **not** lower error
capacity, change the 256/64 MiB guards, or switch the default worker policy.

The byte-exact Stage 2/3 compiler SHA-256 is
`d9e8536bb2287c74bbed57dac3412f6b8a0b03293bf62f0c09ef6dbe36676719`.
Ignored raw reports are under
`OpenC-1.0/build-output/sh27-early-error-release-20260926a/`; the
short-path representative and paired reports are
`OpenC-1.0/build-output/r27-free.json` and
`OpenC-1.0/build-output/p27-free.json`.

- The full representative CLI, four-module file app, and actual edited
  compiler self-build passed three cold/warm/edit repetitions each with
  exact outputs and guards. Compiler-self-build peak child private was
  244,535,296 bytes, leaving 23,900,160 bytes under 256 MiB. Its
  cold/warm/edit medians were 3.969/3.980/3.909 s on this local host;
  those are not cross-host speed comparisons.
- Strict native self-build passed 13/13 checks and 20/20 byte-exact chained
  generations, peak child private/working set 244,342,784 / 63,782,912
  bytes. Native conformance passed 278/278; the Windows x64 substrate passed
  25/25 and integer-boundary proof passed.
- The 8.76 MB / 96,297-relocation compiler-object test still passed under
  nested RAM guards: cold, authenticated no-op, fresh uncached exact PE/COFF,
  malformed overflow-marker rejection, and a linked-compiler-seeded
  byte-exact Stage 2/3 fixed point. The small multi-module cache and full
  diagnostic tests, module boundaries/selected lowering, and the three
  pre-allocation reader cases passed.
- Five local 24-file cache repetitions passed: full/no-op/body-edit/
  ordinary medians 1.533/0.271/0.615/0.392 s, paired ordinary-minus-no-op
  0.121 s. This opt-in workload is not normal-default C/D parity.
- An 11-pair, same-host old/new matrix on generated large functions and
  control flow passed exact runtime/output, deterministic binaries, and
  memory guards. The large-function paired candidate-minus-baseline median
  was +0.028 s against a 0.041 s null floor; control was +0.005 s against
  0.024 s null. Neither difference is a qualifying speed signal. An initial
  matrix from a long nested output path failed both baseline and candidate
  writes; it is discarded, not interpreted as compiler regression.

## Clean hosted result on the same compiler identity

[Windows run 36270863013](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/36270863013)
completed successfully. Raw artifact `OpenC-SH27-module-COFF-36270863013`
(ID `10915497263`) retains the fixed-point, large COFF, cache, representative,
and strict-run reports. Hosted Stage 3 was the same
`d9e8536bb2287c74bbed57dac3412f6b8a0b03293bf62f0c09ef6dbe36676719`
binary as the local proof.

- The compiler-object cache test passed on an 8,760,732-byte object with
  96,289 `.text` relocations. Its linked compiler reproduced the Stage 2/3
  byte-exact SHA, and the malformed overflow-marker probe was rejected.
- The representative CLI, four-module file app, and real edited compiler
  self-build all passed 3/3 cold, warm, and edit repetitions. Compiler
  cold/warm/edit medians were 3.510/3.499/3.517 s **on this hosted runner**.
  Across those nine compiler builds, the largest sampled child private peak
  was 244,985,856 bytes: 23,449,600 bytes below the enforced 256 MiB cap.
  The largest sampled working set was 64,929,792 bytes, below 64 MiB.
- Strict stability passed 13/13 checks and 20/20 byte-exact chained compiler
  generations. The highest sampled private/working-set peaks in that chain
  were 244,342,784 / 65,105,920 bytes, below the 256/64 MiB child limits.
  The hosted 24-file cache workload passed five repetitions with full/no-op/
  body-edit/ordinary medians 0.787/0.107/0.282/0.199 s; that is an opt-in
  synthetic workload, not a normal-default performance claim.
- The separate [branch batch run 36270863002](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/36270863002)
  did **not** clear its required cold-speed gate. The large-function paired
  candidate-minus-baseline median was -0.005 s against a 0.007 s null floor;
  control was +0.001 s. All compiles, exact outputs, deterministic binaries,
  and memory guards passed, so this is a rejected speed signal, not a
  correctness failure. Its raw artifact is
  `OpenC-SH27-branch-batch-36270863002` (ID `10915940454`).

This promotes the **isolated RAM repair and large-object correctness proof**,
not SH-27 itself. Object reuse remains opt-in, the compiler has one giant
module so a source edit still rebuilds it, larger retained projects are
missing, and final normal-default C/D, editor, and release gates remain.
