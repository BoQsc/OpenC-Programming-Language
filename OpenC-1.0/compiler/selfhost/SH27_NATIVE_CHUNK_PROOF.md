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
