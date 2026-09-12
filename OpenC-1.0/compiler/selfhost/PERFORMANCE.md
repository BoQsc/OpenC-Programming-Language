# Native self-rebuild performance

Date: 2026-07-26
Host: Windows 10.0.19045, x86-64
Scope: OpenC-native compiler rebuilding `compiler/selfhost/openc.project.json`

## SH-17 regression result (2026-08-21)

The closed 112-source SH-17 compiler remains inside every SH-14 throughput and
memory budget after adding the purpose-built WinMD reader and raw projector.
Its five-run clean median is 6.111 seconds and maximum is 6.170 seconds, versus
18.085 seconds for the pinned same-host D reference (0.338x). Peak private
memory is 253,460,480 bytes and peak working set is 28,917,760 bytes. Every
compiler and generated C output is byte-identical. WinMD parsing is a separate
offline generation command and does not run during ordinary compiler builds.

The compiler SHA-256 is
`027bd3258579bdac8aab5451cab13d1c1e4b5102b9fd1f15fb2907ac5df9a6b6`;
generated C SHA-256 is
`350a5a29e2190fe3faf5c1c83cb4bce0fc5b09ca61935b396735382794d51ce5`.
Complete evidence is in `release/SH17_WINMD_RAW_PROJECTION_EVIDENCE.md`.

## SH-16 regression result (2026-08-13)

The closed 107-source SH-16 compiler remains inside every SH-14 throughput and
memory budget after adding direct PE32+ emission and the CRT-free runtime
proof. Its five-run clean median is 6.665 seconds and maximum is 7.302 seconds,
versus 18.304 seconds for the pinned same-host D reference (0.364x). Peak
private memory is 220,303,360 bytes and peak working set is 26,693,632 bytes.
Every compiler and generated C output is byte-identical. The SH-14
4.137-second best baseline remains unchanged.

The compiler SHA-256 is
`590c54823693af5f115d123555225ab0ad5e8863d25ee7da21824d6969c475dd`;
generated C SHA-256 is
`2557a5a967e9cee26b1bf32b5bc5ff47ced6a5da69b21f5c9ac1ae9f8708b84b`.
Complete evidence is in
`release/SH16_PE32_PLUS_CRT_FREE_RUNTIME_EVIDENCE.md`.

## SH-15 regression result (2026-08-12)

The closed 104-source SH-15 compiler remains inside every SH-14 throughput and
memory budget after adding the Microsoft x64 ABI model, encoder, relocations,
unwind generator, and probes. Its five-run clean median is 6.218 seconds and
maximum is 7.156 seconds, versus 16.862 seconds for the pinned same-host D
reference (0.369x). Peak private memory is 244,424,704 bytes and peak working
set is 27,963,392 bytes. Every compiler and generated C output is byte
identical. The SH-14 4.137-second best baseline remains unchanged.

The compiler SHA-256 is
`b9edd79017cb92c2f1d3e87fab83c065460c3f966da0745fe602c61b5edcec1e`;
generated C SHA-256 is
`1b6fe066792f97299d25f76bc6fd1ef69fe1a04cd1e834262e545d2202c13350`.
Complete evidence is in
`release/SH15_WINDOWS_X64_ABI_MACHINE_CODE_EVIDENCE.md`.

## SH-14 D/C-class convergence (2026-08-10)

SH-14 is **PASS**. The final closed 99-source compiler has SHA-256
`cac25c7221a3b183fe4a9a1c66a8edb927af9dd4e08879c5cf7ed0cc7b3af8fc`;
its deterministic generated C has SHA-256
`2fbc757171dcec184cc8e7a151c911f932b3d51e66ec761f1715e044a927b141`.

The enforced five-run clean median is 4.137 seconds (maximum 4.854 seconds),
while the pinned same-host D reference median is 12.731 seconds. OpenC is
0.325x the D time. Small builds have a 0.158-second median and 0.184-second
maximum; exact-fingerprint one-source rebuilds have a 0.158-second median.
The 0.25/0.5/1/2 MiB scaling ratios are 1.303x, 1.446x, and 2.112x.

Twenty chained rebuilds preserve exact executable and generated-source hashes.
Peak private memory is 250,437,632 bytes and peak working set is 26,804,224
bytes, both within the 256 MiB/32 MiB ceilings. Native conformance is 278/278,
maintained programs are 4/4, and the full native workflow is 13/13.

The largest speedup came from preserving the compiler's byte-addressed source
span model at `project_slice`: compiler-internal slices now use direct checked
byte spans instead of repeatedly scanning UTF-8 scalar positions. Deterministic
parallel source lowering and a linear source-position declaration-owner index
complete the clean-build and scaling convergence. Full evidence is in
`release/SH14_COMPILER_THROUGHPUT_CONVERGENCE_EVIDENCE.md`.

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

## SH-14 convergence target (historical)

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

## SH-20 native public throughput closure

SH-20 removes the direct-native public validation bottleneck left by SH-19.
The final 116-source compiler has a 17.064-second five-run public-build median
and 11.352-second validation median. Twenty consecutive public builds close at
the identical 4,941,312-byte executable hash
`b82b228989c915db04370ed9463ac722375c610bbc15c497830b1c39ed707de3`.

The pinned same-host medians are 22.732 seconds for Clang 16.0.5 building the
TinyCC 0.9.27 ISO C codebase with `-O2`, and 17.504 seconds for DMD 2.112.0 /
DUB 1.41.0 building the retained D compiler in forced release mode. OpenC's
ratios are 0.751x and 0.975x. These tools are comparison oracles only; none is
invoked by the public OpenC build or packaged in the release.

All measured compiler runs retain 256 MiB private, 64 MiB working-set, and
bounded-output guards. Observed peaks are 216,932,352 private bytes and
49,405,952 working-set bytes. The detailed method and primary record paths are
in `../../release/SH20_NATIVE_PUBLIC_THROUGHPUT_EVIDENCE.md`.

## SH-21 OpenC-native benchmark ownership

SH-21 completes required self-build sampling and enforcement in the
OpenC-authored `openc benchmark` command. The final 130-source compiler passes
20/20 chained exact rebuilds at SHA-256
`7eea1c053132536398c562a09e46c98478f6f4cde6ddf9a2f706943ee4fbc130`.
Its enforced public-build median is 23.094 seconds and its semantic-validation
median is 14.827 seconds, below the unchanged 25-second and exclusive
15-second gates.

Peak compiler private and working-set memory are 181,161,984 and 53,575,680
bytes. Oversized backend and IR source records were partitioned at function
boundaries, reducing validation syntax candidates from roughly 1.05 million
in the regressed draft to 491,733 without changing compiler behavior. Every
hash buffer is freed, and all 20 build records reject Python, D, C, TinyCC,
assembler, and external linker use. See `SH21_COMPLETION_EVIDENCE.md`.
