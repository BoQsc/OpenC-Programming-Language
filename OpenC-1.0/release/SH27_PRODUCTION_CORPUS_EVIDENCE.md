# SH-27 production compiler corpus evidence

Status: **CLEAN WINDOWS OPENC/MSVC/CLANG/DMD PASS; SCALING DEFICIT OPEN**

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

## Clean-host result

Automatic push run
[`34773764974`](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/34773764974)
completed successfully at commit `6cdfb3dee9788182bbe1eca8d5221c5174808750`
on Windows Server 2025 image `win25-vs2026` version `20260907.229.1`.
All compiler-presence, version, compilation, execution, output-capture, and
memory checks passed. The 11,048,512-byte evidence artifact is retained as
artifact `10322752743` for 90 days.

The exact x64 comparators were MSVC 19.44.35228, Clang 20.1.8 targeting
`x86_64-pc-windows-msvc`, and DMD64 2.112.0. The released OpenC input was
`eadbef1…c191087`.

| Workload | OpenC | MSVC | Clang | DMD64 |
|---|---:|---:|---:|---:|
| small single file | 0.107 s | 0.109 s | 0.129 s | 0.139 s |
| 24 source files | 0.436 s | 0.343 s | 0.831 s | 0.158 s |
| 2,048 functions | 25.983 s | 0.509 s | 0.950 s | 0.302 s |

OpenC's large-workload ratios are 51.047x MSVC, 27.351x Clang, and 86.036x
DMD64. Its 24-file result is 1.271x MSVC, 0.525x Clang, and 2.759x DMD64. The
small case passes the 1.25x parity threshold against every comparator.

The repeated one-source-edit medians are OpenC 0.437 s, MSVC 0.342 s, Clang
0.834 s, and DMD64 0.159 s. Four simultaneous small projects complete at
18.862, 21.062, 21.427, and 15.823 projects/second respectively. The complete
OpenC self-build passes three times at an 8.252-second median. Its measured
peak is 177,487,872 private bytes and 59,936,768 working-set bytes.

The clean large OpenC sample attributes 24.035 of 25.906 compiler milliseconds
to validation. Pointer-arithmetic scanning alone consumes 13.138 seconds on
pointer-free input; expression acceptance costs 5.922 seconds and
function/scope/enum acceptance costs 2.831 seconds. Peak large-workload OpenC
memory is 157,614,080 private bytes and 37,707,776 working-set bytes, below the
512 MiB kill limits. The compiler emits a 2,786,304-byte CRT-free executable;
different output sizes are recorded but are not treated as correctness
equivalence.

The report status is `EVIDENCE_COMPLETE_DEFICIT`, not parity. The successful
workflow proves that the evidence is complete for this corpus and that the
deficit is real; it deliberately does not turn a green infrastructure run into
a C/D-class throughput claim.

## Pointer-free validation optimization

Automatic push run
[`34775393808`](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/34775393808)
completed successfully at commit `418417d3b721b3e4d0c0d292543e1168b13f6b8e`
on the same Windows image. The workflow first used the immutable SH-25 seed to
build the checked-out compiler twice under the 512 MiB guards, required the two
7,119,872-byte outputs to be byte-identical at SHA-256 `391fd639…7639b8`, and
then benchmarked that current compiler. Both guarded bootstrap builds passed.

The compiler now proves from resolved semantic types that a project has a raw
pointer-valued symbol before running pointer-arithmetic analysis. It also
checks whether a candidate is pointer-valued before searching for an enclosing
unsafe region. The existing rejecting and accepting pointer fixtures still
pass, native conformance passes 278/278, and the repository audit passes.

| Workload | OpenC | MSVC | Clang | DMD64 |
|---|---:|---:|---:|---:|
| small single file | 0.085 s | 0.086 s | 0.106 s | 0.117 s |
| 24 source files | 0.291 s | 0.284 s | 0.671 s | 0.126 s |
| 2,048 functions | 10.003 s | 0.395 s | 0.763 s | 0.249 s |

The large OpenC median improved by 61.5% from 25.983 to 10.003 seconds.
Pointer-arithmetic validation fell from 13.138 seconds to 0 milliseconds on
all three pointer-free large samples. The complete compiler self-build median
improved from 8.252 to 6.435 seconds. All compilation, execution, output, and
memory checks passed; the largest recorded OpenC private/working-set peaks were
177,684,480 and 60,116,992 bytes respectively.

The large lane remains materially noncompetitive at 25.324x MSVC, 13.110x
Clang, and 40.173x DMD64. Clean attribution now identifies expression
acceptance at approximately 4.56 seconds and function/scope/enum acceptance at
approximately 2.22 seconds as the next two dominant targets. The report remains
`EVIDENCE_COMPLETE_DEFICIT`.

## Indexed acceptance optimization

Automatic push run
[`34776722018`](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/34776722018)
completed successfully at commit `f0efadd373748445aa164b12416dbfcc8e0557e4`
on Windows image `win25-vs2026` version `20260907.229.1`. The retained artifact
is `OpenC-SH27-production-performance-34776722018`, ID `10324275949`, with
13,756,773 ZIP bytes and digest
`sha256:fb3f181c4d00f4aff2bbc3a535818ca2c78103bd5cb610421b165f4882cb1a42`.

This tranche uses existing IR indexes and adjacency lists for root/name lookup,
direct block statements, control nodes, call nodes, and return-to-function
selection. Return validation is a single source-order statement pass rather
than a complete syntax pass for every function. Native conformance remains
278/278 and the repository audit remains PASS at 507 required files, 39 pinned
hashes, 278 fixture identities, 466 covered rules, and 174 covered grammar
productions.

The immutable 7,119,360-byte seed `eadbef1f…c191087` built the current compiler
twice under the 512 MiB process guards. Both 7,122,432-byte outputs were
byte-identical at SHA-256 `6820884d…25af30`; their guarded build times were
7.913 and 7.795 seconds and their largest private/working-set peaks were
175,374,336 and 60,669,952 bytes.

| Workload | OpenC | MSVC | Clang | DMD64 |
|---|---:|---:|---:|---:|
| small single file | 0.097 s | 0.106 s | 0.118 s | 0.149 s |
| 24 source files | 0.323 s | 0.334 s | 0.818 s | 0.159 s |
| 2,048 functions | 4.039 s | 0.505 s | 1.007 s | 0.312 s |

The large median improved another 59.6%, from 10.003 to 4.039 seconds, and is
84.5% below the original 25.983-second baseline. Expression acceptance fell
from about 4.56 seconds to 109–110 milliseconds in the clean samples;
function/scope/enum acceptance fell from about 2.22 seconds to 0–16
milliseconds. Small builds beat all three comparators, and the 24-file build
beats MSVC and Clang, but DMD remains faster in that lane.

The large ratios remain outside the 1.25x target at 7.998x MSVC, 4.011x Clang,
and 12.946x DMD64. The next measured targets are now flow validation: pointer
facts cost 202–281 milliseconds, unsafe primitives 455–530 milliseconds,
scope actions 219–265 milliseconds, and unsafe-call validation 297–313
milliseconds. The complete compiler self-build median is 7.718 seconds. Every
compiler presence/version, compilation, execution, output, fixed-point, and
memory check passed; the report correctly remains
`EVIDENCE_COMPLETE_DEFICIT`.

## Workflow contract

`.github/workflows/openc-performance.yml` runs automatically when the compiler
source/project, corpus, harness, memory sampler, bootstrap seed, or workflow
changes and can also be started manually. It rebuilds the checked-out compiler
twice under the RAM guards, requires a byte-exact fixed point, and benchmarks
that current binary. It uses the Windows 2025 runner, requests MSVC toolset
14.44, requires MSVC 19.44, Clang 20.1.8, and DMD 2.112.0 version evidence,
and requires all four compilers. It retains the complete JSON and run tree for
90 days and accepts an explicit manual `enforce_parity` switch. The normal run
preserves correctly measured deficits as evidence; compiler, execution,
missing-tool, version-pin, output, or RAM failures remain blocking.

Python and the three comparison compilers are optional evidence tools only.
Normal `openc build`, the self-hosting compiler, and the standalone release
remain independent of Python, C, D, TinyCC, assemblers, and external linkers.

SH-27 remains active after this tranche. The production corpus still needs
file-I/O/allocation runtime cases, incremental object/build-system reuse, LDC,
broader real projects, and fixes for every material measured compiler deficit.
