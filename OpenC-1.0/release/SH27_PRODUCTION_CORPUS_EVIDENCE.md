# SH-27 production compiler corpus — tranche 1 evidence

Status: **LOCAL OPENC/DMD PASS; CLEAN-HOST MSVC/CLANG/DMD RUN PENDING**

SH-27 now has a checked-in deterministic corpus and bounded Windows harness
for equivalent OpenC, ISO C, and D parsing, semantics, native code generation,
linking, and executable checks. `benchmarks/sh27/CORPUS.json` defines three
workloads: a small single file, 24 source files, and 2,048 arithmetic
functions. The harness also executes a repeated one-source-edit lane, four
independent projects concurrently, output size/SHA-256 capture, executable
startup, and complete OpenC compiler self-builds.

Every compiler process is sampled through PSAPI and killed if it crosses the
checked-in 512 MiB private or working-set ceiling. Compiler output is spooled
to bounded temporary files instead of being retained in RAM. The harness
records raw samples, medians, p95, tool hashes and versions, source hashes and
bytes, exact commands, deterministic rotated run order, and the unflushed OS
cache policy.

## Local result

The 2026-09-13 local harness validation used the released OpenC 1.0.0 compiler
and DMD64 2.112.0 for three samples per lane. All compilation, RAM, output,
and executable checks passed. MSVC and Clang are not installed in the local
environment and are therefore not represented by this preliminary result.

| Workload | OpenC median | DMD median | OpenC / DMD |
|---|---:|---:|---:|
| small single file | 0.192 s | 0.503 s | 0.382x |
| 24 source files | 0.625 s | 0.148 s | 4.223x |
| 2,048 functions | 36.336 s | 0.345 s | 105.322x |

The complete 221-source OpenC compiler self-build passed in 11.167 seconds at
174,632,960 peak private bytes and 54,415,360 peak working-set bytes. The
large generated workload remained within the guard at 157,523,968 peak
private bytes and 36,642,816 peak working set.

After registering the four SH-27 files, source completeness passes at 515/515
(414 source and 101 required non-source files), the frozen repository audit
passes all 507 file, 39 hash, 278 fixture, 466 rule, and 174 grammar checks,
and the OpenC-native daily workflow passes 14/14. The immutable 1.0 release
packaging plan and released compiler bytes were not changed.

This result confirms a material scaling deficit and does **not** establish
broad C/D-class parity. Native timing attribution assigns 34.171 of 36.781
seconds to validation. Within validation, pointer-arithmetic scanning costs
18.687 seconds despite the corpus containing no pointer arithmetic, expression
acceptance costs 8.201 seconds, and function/scope acceptance costs 3.877
seconds. Those measurements identify validation candidate scanning as the
first optimization target.

## Clean-host gate

`.github/workflows/openc-performance.yml` runs automatically when the corpus,
harness, memory sampler, bootstrap compiler, or workflow changes and can also
be started manually. It uses the Windows 2025 runner, requests MSVC toolset
14.44, requires MSVC 19.44, Clang 20.1.8, and DMD 2.112.0 version evidence,
and requires all four compilers. It retains the complete JSON and run tree for
90 days and accepts an explicit manual `enforce_parity` switch. The normal run
preserves correctly measured deficits as evidence; compiler, execution,
missing-tool, version-pin, output, or RAM failures remain blocking.

Python and the three comparison compilers are optional evidence tools only.
Normal `openc build`, the self-hosting compiler, and the standalone release
remain independent of Python, C, D, TinyCC, assemblers, and external linkers.

SH-27 remains active after this tranche. The production corpus still needs
the clean-host MSVC/Clang/DMD result, then file-I/O/allocation runtime cases,
incremental object/build-system reuse, LDC, broader real projects, and fixes
for every material measured compiler deficit.
