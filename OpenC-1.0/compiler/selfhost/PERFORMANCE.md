# Native self-rebuild performance

Date: 2026-07-26
Host: Windows 10.0.19045, x86-64
Scope: OpenC-native compiler rebuilding `compiler/selfhost/openc.project.json`

## SH-13 closed native measurement

Date: 2026-07-30

The closed 96-source compiler rebuilds itself in 557.985 seconds, down from the
SH-12 baseline of 780.621 seconds. That is a 28.5% elapsed-time reduction.
Input compiler, output compiler, and the next rebuilt compiler are
byte-identical at SHA-256
`006ffed8768aeb9050cdb690e3b8db2d835f3a939c82c75f8e40ff46b9628d9e`.
Generated C is byte-identical at SHA-256
`cbba2415d0d3e231a458a49f7aa4b3672a19ff41917a5f122e48cdf12659b58c`.

The native `openc build --timings=...` record separates the work:

| Phase | Milliseconds | Share |
| --- | ---: | ---: |
| Project load | 32 | <0.1% |
| Declarations | 1,546 | 0.3% |
| Resolution | 7,297 | 1.3% |
| Validation | 0 | 0.0% |
| OpenC lowering and C emission | 548,172 | 98.2% |
| TinyCC compile/link | 938 | 0.2% |
| Total | 557,985 | 100.0% |

SH-13 adds lazy type and expression-child caches plus indexed statements,
blocks, controls, expressions, names, declaration symbols, and module-top
symbols. These remove repeated full syntax/symbol-table scans while preserving
deterministic closure.

A separate 50 ms PSAPI-monitored budget run completed in 500.311 seconds with
214,630,400 bytes peak private memory and 14,274,560 bytes peak working set.
Its compiler and generated C have the same hashes shown above. All elapsed and
memory checks pass the tightened SH-13 budget.

This result is materially better but is not D/ISO-C-class compilation speed.
The remaining gap is explicitly open: it lies primarily in OpenC-owned
lowering/C emission and in the execution quality of the generated compiler,
not in the sub-second TinyCC invocation. Replacing TinyCC with a first-party
object/link backend remains future architecture work; SH-13 does not claim
that backend independence is complete.

## SH-14 blocking convergence target

The existing 900-second regression ceiling prevents further deterioration; it
is not an acceptable compiler-speed target. A preliminary same-host forced
release build of the retained D reference completed in 25.462 seconds on
2026-08-04, compared with OpenC's 500.311-second monitored clean rebuild. The
formal SH-14 comparator harness must reproduce both measurements with pinned
inputs and tools.

SH-14 requires a five-run clean OpenC median no greater than 30 seconds, every
clean run no greater than 45 seconds, and a median no greater than 1.25x the
pinned D reference. It also requires <=250 ms median small builds, <=1 second
median one-source rebuilds, near-linear scaling, existing memory ceilings,
byte-identical closure, and 20 consecutive stable clean rebuilds. No editor or
new platform implementation precedes that gate. The full work plan is
`THROUGHPUT_CONVERGENCE_PLAN.md`.

### SH-14 indexed-lowering checkpoint (2026-08-09)

Closed stage 101 rebuilds the current 96-source, 1,085,893-byte compiler in
80.149 seconds and is byte-identical to its input. Its internal timing record
reports 80.047 seconds total: 67.718 seconds IR lowering, 9.747 seconds C
emission, 0.968 seconds resolution, 0.375 seconds declarations, 0.315 seconds
lex/parse, 0.282 seconds index construction, and 0.328 seconds TinyCC.

The same closed compiler passes 278/278 native conformance and 4/4 maintained
programs. Peak private memory is 262,389,760 bytes and peak working set is
19,030,016 bytes. Counted lowering candidates are 0 statements, 0 parents,
112,607 expression positions, 152,945 syntax candidates, and 84,189 symbol
candidates. This is 91.9% fewer counted candidates than stage 74.

The checkpoint does not pass SH-14: it remains above the 30-second absolute
gate, and the required five-run/D-relative/scaling/incremental/soak evidence is
still open. With indexed lookup no longer dominant and TinyCC still sub-second,
the next work is generated-code quality (smaller C units, SSA lifetime reuse,
structured control flow) followed by deterministic parallel source lowering.

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

## SH-8 enforced regression budgets

SH-8 replaces descriptive-only performance history with the enforceable
budgets in `WINDOWS_NATIVE_BUDGETS.json`.

The SH-13 live-desktop 278-fixture native validation baseline is 32.612
seconds with 6,434,816 bytes peak private memory and 8,413,184 bytes peak
working set. Its reviewed ceiling is 90 seconds and 16 MiB. The SH-13
byte-identical 96-source native self-rebuild
baseline is 500.311 seconds with 214,630,400 bytes peak private memory and
14,274,560 bytes peak working set. Its tightened ceiling is 900 seconds; the
256 MiB private-memory and 32 MiB working-set ceilings remain unchanged.

The prior SH-8 baselines were 35.489 seconds for validation and 494.985 seconds
for the 92-source self-rebuild, whose ceiling was 620 seconds. The 94-source
SH-10 compiler adds the native formatter, project inspector, and test runner.
Repeated identical SH-10 executions on the live reference desktop ranged from
29.803 to 68.471 seconds for validation and from 574.050 to 744.926 seconds for
self-rebuild. Every validation passed 278/278; every completed rebuild was
byte-identical; memory remained stable and below the original ceilings. The
authored SH-10 review recorded those ranges and retained both original memory
ceilings. SH-11 observed a wider successful-build range through 945.439
seconds while generated C and memory remained stable. An initial executable
comparison used a `final-openc.exe` seed whose embedded PE module basename
differed from the rebuilt `openc.exe`; rebuilding and installing the stable
`openc.exe` basename restored byte-exact closure. The authored SH-11 review
raises only the elapsed ceiling to 1,050 seconds (11.1% baseline headroom) and
retains the existing memory ceilings.

SH-12 added the project-semantic language-service source without requiring a
budget increase. SH-13 indexed the dominant OpenC lowering lookups and reduced
the monitored rebuild from 780.621 to 500.311 seconds. The current baselines
provide 176.0% validation elapsed headroom and 79.9% rebuild elapsed headroom.

Run and enforce both budgets with:

```text
python scripts/windows_native_workflow.py full
```

Ordinary `daily` mode may reuse a passing 278-fixture report only when the
compiler, fixture tree, runtime, native shim, and TinyCC fingerprint is exact.
The recorded unchanged lookup takes 0.002 seconds and executes zero fixtures.
Full and release modes always execute the complete native corpus.
