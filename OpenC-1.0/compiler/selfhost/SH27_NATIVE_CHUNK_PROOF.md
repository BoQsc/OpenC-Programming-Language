# SH-27 native source-chunk proof (experimental)

This isolated branch establishes a prerequisite for native source workers. It
does **not** run sources concurrently or claim a compilation-speed gain.

`openc artifact --kind=exe --source-chunks=4` closes derived types, creates
four private type tables, export caches, and native layout caches, then emits
source ranges into separate binary object streams. The ranges currently run
serially and merge in source-record order. The normal `openc build` path
remains serial and unchanged. A type-table growth or buffer failure fails the
experimental command rather than silently emitting a non-deterministic image.

Run the bounded proof with:

```text
python compiler/selfhost/verify_sh27_native_chunks.py \
  --compiler PATH/TO/openc.exe \
  --output build-output/selfhost-sh27/native-chunks.json
```

The local proof at compiler SHA-256 `1a066723d02f36732c43c1e3eb0562b5320cabd763419ce7d3cc806156561bb3`
passes byte-exact serial/chunked executable comparison for the 221-source
self-hosted compiler, the 24-file generated corpus, the eight-file large
corpus, and the four-file control-flow corpus. A modified control-flow source
also preserves the exact semantic diagnostic. Stage-two, serial stage-three,
and chunked compiler binaries share that SHA-256. The same compiler passes
25/25 x64 substrate, 278/278 native conformance, and 10/10 SH-27 harness
tests. The maximum measured process-tree private peaks in MiB are:

| Workload | Serial | Four isolated chunks |
| --- | ---: | ---: |
| Self-hosted compiler | 174 | 289 |
| Many files | 28 | 48 |
| Large functions | 127 | 177 |
| Control flow | 61 | 86 |

All stay below the 512 MiB guard, but the ~115 MiB self-build overhead is too
large to ignore. Threads would overlap source arenas and could raise the peak
further. Before enabling concurrency, the native runtime needs thread-safe
allocation accounting, deterministic diagnostic buffering or serial
prevalidation, a Windows thread entry independent of the hosted-C runtime,
bounded 2/4-worker scheduling, failure-to-serial fallback, and memory/headroom
proofs under actual concurrent execution. Only then can paired throughput
results determine whether this architecture should be promoted.

## Atomic allocator prerequisite

The native heap's live-byte limit now uses a locked compare/exchange loop for
both reservation and release. Its file/path diagnostic counters use locked
increments. This prevents two future workers from independently admitting
allocations against the same 512 MiB live-byte headroom. The 256 MiB
single-allocation cap is unchanged. A failed HeapAlloc still
exits through the existing checked failure path; it never continues with an
unaccounted allocation. This is only an allocator prerequisite, not evidence
that compiler source lowering is thread-safe.

The allocator version self-rebuilds byte-identically at SHA-256
`b2c8764b34ac48631dcadc7a6477965589b3584e6c4dfbecbff0c7114f35138b`.
The guarded four-workload proof in
`build-output/selfhost-sh27/native-chunk-proof/final-atomic-report.json`
passes byte-exact executables and the invalid-source diagnostic. The largest
measured process-tree private peak is 300 MiB in the four-chunk self-build,
still below the 512 MiB guard. The x64 substrate passes 25/25 and final native
conformance passes 278/278.

Eleven-pair guarded same-host comparisons against the preceding chunk-proof
commit also pass every build, exact-output, memory, and fixed-point check.
Control-flow has a +3 ms median paired delta (five candidate wins, six losses);
large-functions has +24 ms (four wins, seven losses). Both runs show substantial
host variability, so these results establish no speed gain and do not justify
promoting the atomic path as a production performance change. The underlying
reports are `atomic-paired-control.json` and `atomic-paired-large.json` in the
same ignored build-output directory.

The next isolated change sizes each chunk's binary stream from its actual
cached source bytes: at most 12 bytes of capacity per source byte plus 128 KiB,
clamped to the original whole-project ceiling. Overflow still fails the
experimental command; it cannot silently truncate a binary. This reduces the
guarded four-chunk self-build private peak from 300 MiB to 259-261 MiB, about
a 40 MiB reduction. All four valid workload executables remain byte-identical to serial
builds, and the invalid-source diagnostic remains exact. The compiler reaches
a byte-exact stage-two/stage-three fixed point at SHA-256
`0a662e7d4a0db4201a12f64ed8da51eaa3b3fb53141a4a34a34fcd89eeb51857`.
The final compiler also passes 25/25 x64 substrate and 278/278 native
conformance; its detailed proof is `sized-final-report.json` under the same
ignored output tree. The path still runs serially and cannot count as
compilation-speed progress.

A first Windows-thread launch experiment was **discarded**. Its opt-in
artifact path access-violated; reducing the new call to a no-thread sentinel
still reproduced the violation. The direct threaded code, the sentinel call,
and callback scaffolding were removed. The precise call-boundary defect is
not yet proven, so native workers remain disabled. The next attempt needs a
minimal reproducible call/ABI fixture before restoring any CreateThread path,
then isolated-cache and ordered-diagnostic tests under actual concurrency.
