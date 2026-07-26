# Native self-rebuild performance

Date: 2026-07-26
Host: Windows 10.0.19045, x86-64
Scope: OpenC-native compiler rebuilding `compiler/selfhost/openc.project.json`

## Result

The post-SH-6 native compiler completes a full self-rebuild in 381.049 seconds,
down from 698.918 seconds on the same host and project. This is a 45.5% elapsed
time reduction, or a 1.83x throughput improvement.

| Measurement | Pre-change | Optimized closed Stage 3 | Change |
| --- | ---: | ---: | ---: |
| Elapsed time | 698.918 s | 381.049 s | 45.5% lower |
| Peak working set | at least 1,947.0 MiB | 11.37 MiB | at least 99.4% lower |
| Peak private memory | at least 2,144.9 MiB | 161.55 MiB | at least 92.5% lower |

The pre-change memory values are lower bounds from the last observation before
process exit; they are not presented as exact peaks. The optimized values are
the peak fields recorded by the 50 ms Windows PSAPI sampler.

## Changes

- The native shim now interns path joins and uses deterministic open-addressed
  caches for joined paths and cached file reads. A bounded pointer-identity
  front cache is invalidated whenever OpenC releases memory, while content
  equality remains the correctness fallback.
- Process finalization releases the retained cache contents.
- `flow_next_direct_statement` now rejects source-order candidates before its
  expensive full-syntax parent scans. This removes the dominant repeated work
  in compiler-sized C/IR lowering without changing selection semantics.
- The Windows closure harness uses the stable basename `openc.exe` in separate
  stage directories. TinyCC records the PE export-module basename, so this
  prevents a path-induced byte difference between otherwise identical stages.

Phase measurement before the lowering fix attributed 686.969 of 692.691
seconds to the C/IR emission phase. The runtime caches alone reduced memory but
did not reduce elapsed time; the source-order guard supplied the time
improvement.

## Closure and regression evidence

The optimized native Stage 2 and Stage 3 are byte-identical:

- executable SHA-256:
  `9c74209ddfc8c865ae9be66586c2b18d8318be6b01617b4d84db37c6232639dd`
- generated-C SHA-256:
  `33a8bff3281b988925407a152430f65b37619cb58e91e0aa5d7adb5a53751d3d`
- normalized-PE SHA-256:
  `bca85705c132a265d9e308f148eb83bc3eeb2d89e7f5ae9f0387404adf73989b`

The closure build records exclude DMD, DUB, and Python. The closed Stage 3
passes 117 exact canonical-IR comparisons, 149 exact rejection outcomes, 232
flow/safety comparisons plus 34 frontend cases, and native build/execution of
all 4 maintained programs. The retained D conformance adapter passes 268/268
fixtures, and all 4 informative Python bootstrap tests pass. A copied
standalone layout also passes public `openc build` from a foreign working
directory and executes the Hosted CLI program with exact output.

## Reproduce

Run closure, then measure the closed Stage 3:

```text
python compiler/selfhost/bootstrap_windows_closure.py --stage1 PATH/TO/openc.exe --use-existing-stage1 --output build-output/selfhost-performance/closure
python compiler/selfhost/benchmark_windows_rebuild.py --compiler build-output/selfhost-performance/closure/stage3/openc.exe --output build-output/selfhost-performance/benchmark/openc.exe --report build-output/selfhost-performance/benchmark/measurement.json --sample-interval 0.05
```

The benchmark harness is external evidence orchestration. The measured native
compiler child receives a clean PATH containing only Windows System32 and the
shipped TinyCC directory.
