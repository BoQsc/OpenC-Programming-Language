# SH-20 native public throughput convergence

Status: **NEXT ACTIVE**.

SH-19 makes the normal compiler and its emitted programs independent of C,
TinyCC, D, Python, an assembler, and an external linker. It does not make the
fully validating public build fast enough. The final SH-19 compiler reports
109.328 seconds for its own 116-source public build, of which 97.828 seconds
are semantic validation. The already-validated direct native rebuild takes
9.965 seconds. That gap is the highest-priority engineering problem.

SH-20 therefore precedes workflow-language replacement. It may change data
structures and native code generation, but it may not skip, weaken, cache as
success, or special-case the public semantic checks.

## Exit gates

- `openc build` performs full syntax, resolution, flow/safety, acceptance, IR,
  native-code, and PE checks on every clean measurement.
- Five clean 116-source public self-builds have a median at most 25 seconds,
  every run is at most 35 seconds, and every output is byte-identical.
- A refreshed same-host D reference and a small ISO C reference are pinned;
  the OpenC public-build median is no more than 1.25x the slower reference and
  no more than 2.0x either reference. Raw samples and tool hashes are retained.
- Public validation falls below 15 seconds median without suppressing any
  current rule or acceptance check.
- Small clean builds remain at most 0.5 seconds median and one-source rebuilds
  at most 1.0 second median.
- Twenty chained native compiler rebuilds close byte-for-byte.
- Peak private memory remains at most 256 MiB and peak working set at most
  64 MiB. The allocation, validation, child-output, and process guards remain
  enabled in every measured run.
- Native conformance remains 278/278, maintained programs remain 4/4, and the
  complete SH-19 standalone-release verifier remains green.

## Work order

1. Add per-source and per-function validation timing/candidate counters that
   separate semantic work from generated-code inefficiency.
2. Remove repeated whole-project scans in flow and acceptance validation with
   stable owner/range indexes and bounded caches.
3. Improve generated x64 for validator hot loops: eliminate redundant stack
   traffic, fold address calculations, and use register-resident loop state.
4. Reuse the already-built declaration/resolution context during native
   emission so the public command does not rebuild equivalent project state.
5. Measure after each change with cold-process runs; reject changes that trade
   speed for unbounded memory or weaken diagnostics.
6. Run the five-run C/D comparison, 20-build closure, full workflow, and two
   independent release archives before marking SH-20 complete.

Python remains an external evidence harness during SH-20. Replacing required
Python build/test/release orchestration moves to SH-21, after public compiler
throughput is competitive and stable. Linux, freestanding, and ARM64 remain
optional future targets.
