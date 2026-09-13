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

## Candidate-free flow validation

Automatic push run
[`34778351292`](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/34778351292)
completed successfully at commit `ab4f5469731938dfff450cf944099a2129827d75`
on the same clean Windows image. Artifact
`OpenC-SH27-production-performance-34778351292`, ID `10324223589`, contains
13,765,036 ZIP bytes at
`sha256:9909e99381ae8abaf983f7a355b0b3f7128eb55eceecad7b08e673834ed03113`.

Flow validation now records source candidate facts during its existing index
walk, computes project pointer and unsafe-function facts once, bounds call
checking to the owning function where source order permits it, and retains the
complete-scan fallback. A source with no qualifying semantic candidate no
longer enters pointer-fact, unsafe-primitive, scope-action, or unsafe-call
analysis for every function. The retained call index is reused; the final
implementation does not add the discarded function-array/sort experiment.

The immutable seed again built the checked-out compiler twice under the RAM
guards. The two 7,129,088-byte outputs are byte-identical at SHA-256
`10a40c86…24d5f`; guarded builds took 8.002 and 7.757 seconds. Their largest
private/working-set peaks were 176,496,640 and 58,765,312 bytes. Native
conformance remains 278/278, and all repository audit counts remain exact.

| Workload | OpenC | MSVC | Clang | DMD64 |
|---|---:|---:|---:|---:|
| small single file | 0.098 s | 0.109 s | 0.118 s | 0.139 s |
| 24 source files | 0.324 s | 0.352 s | 0.888 s | 0.160 s |
| 2,048 functions | 2.797 s | 0.501 s | 1.028 s | 0.315 s |

The large median improves another 30.7%, from 4.039 to 2.797 seconds, and is
89.2% below the original 25.983-second result. On all three clean large
samples, pointer facts, unsafe primitives, scope actions, and unsafe calls each
measure 0 milliseconds because the generated project has no qualifying
candidate. Small builds pass the 1.25x target against all three comparators;
the 24-file lane passes against MSVC and Clang.

Large-program parity remains open at 5.583x MSVC, 2.721x Clang, and 8.879x
DMD64. Clean phase attribution now shows 250–281 milliseconds for declaration
collection, 703–718 milliseconds for resolution, 951–985 milliseconds for
validation, and 765–768 milliseconds for lowering/emission. Flow parsing alone
costs 253–265 milliseconds, demonstrating that repeated frontend traversal and
phase-local syntax construction—not the eliminated empty validators—are now
the main architectural target. The self-build median is 7.673 seconds, its
largest private/working-set peaks are 175,824,896 and 61,136,896 bytes, and all
process guards pass.

## Stateless-source flow fast path

Automatic push run
[`34778904952`](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/34778904952)
completed successfully at commit `bc7fdd1665edbc45cd536c03e8aaceea2e4d82c5`
on the same clean Windows image. Artifact
`OpenC-SH27-production-performance-34778904952`, ID `10324059749`, contains
13,769,217 ZIP bytes at
`sha256:b81c5a4380429ef1590bd11b0415694a040e133666097b5df77a24536d6e966c`.

Flow validation now discovers the source's symbol range before allocating or
constructing its private syntax tree. A conservative semantic/source gate
returns immediately when the source cannot contain state, pointer, ownership,
scope, or unsafe flow work; every uncertain source retains the complete
validator. Seven of the eight generated large-corpus source files qualify for
the fast path, while the entry source remains fully checked.

The immutable seed again built the checked-out compiler twice under the RAM
guards. The two 7,133,184-byte outputs are byte-identical at SHA-256
`43f83afe…d77db6`; guarded builds took 7.976 and 7.767 seconds. Their largest
private/working-set peaks were 176,263,168 and 57,200,640 bytes. Native
conformance remains 278/278, and the repository audit remains exact.

| Workload | OpenC | MSVC | Clang | DMD64 |
|---|---:|---:|---:|---:|
| small single file | 0.096 s | 0.109 s | 0.117 s | 0.137 s |
| 24 source files | 0.272 s | 0.330 s | 0.810 s | 0.158 s |
| 2,048 functions | 2.223 s | 0.496 s | 1.024 s | 0.314 s |

The large median improves another 20.5%, from 2.797 to 2.223 seconds, and is
91.4% below the original 25.983-second result. The repeated one-source-edit
median is 0.261 seconds, and four parallel OpenC builds sustain 19.547 projects
per second. The complete compiler self-build median is 7.634 seconds, with
176,115,712 peak private bytes and 58,748,928 peak working-set bytes. Every
process remained below the 512 MiB evidence guard.

Large-program parity remains open at 4.482x MSVC, 2.171x Clang, and 7.080x
DMD64. The clean large samples attribute 250–265 milliseconds to declarations,
703–718 milliseconds to resolution, 376–453 milliseconds to validation, and
766–796 milliseconds to lowering/emission. Flow falls to 110–157 milliseconds;
its parse component falls to 32–47 milliseconds. Resolution and lowering are
therefore the next measured architectural targets.

## Bounded prefix-type lookup

Automatic push run
[`34779762154`](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/34779762154)
and manual confirmation run
[`34780027346`](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/34780027346)
both completed successfully at commit
`a2f8994efa0f72c7e452fe4bc1e6a981c4ddb0b8`. The automatic artifact is ID
`10324950432`, 13,770,939 ZIP bytes at
`sha256:407ad4f05e0317f183ba2546c49250a9c286634ef03a4af64f63c765ecef3758`.
The confirmation artifact is ID `10325360850`, 13,770,931 ZIP bytes at
`sha256:4b6a2e333ec2515cd2ab85444ace6dd034f4fc6cbf2f27cfe2df3b51ce44d754`.

Every function, parameter, local, field, and constant formerly found its
prefix type by rescanning the complete source syntax table from record zero.
The parser already emits those type nodes immediately before their owner. The
compiler now searches that bounded preceding region, preserves earliest-node
selection for nested type expressions, and retains the complete scan as a
recovery fallback for non-canonical syntax. The change adds no allocation.

Both runs built the same 7,134,208-byte fixed point at SHA-256
`1681d17a…d3b54`. The first run exposed host-wide timing variance: unrelated
validation and emission rose with the self-build median to 9.332 seconds, while
large resolution still fell to 312–313 milliseconds. The manual rerun returned
the self-build median to 7.582 seconds and measured large resolution at
265–282 milliseconds, confirming the localized gain without concealing the
slower observation.

| Workload | OpenC | MSVC | Clang | DMD64 |
|---|---:|---:|---:|---:|
| small single file | 0.097 s | 0.107 s | 0.128 s | 0.137 s |
| 24 source files | 0.262 s | 0.358 s | 0.840 s | 0.159 s |
| 2,048 functions | 1.808 s | 0.494 s | 1.026 s | 0.313 s |

The confirmation run improves the large median another 18.7%, from 2.223 to
1.808 seconds, and is 93.0% below the original 25.983-second result. Its large
ratios remain open at 3.660x MSVC, 1.762x Clang, and 5.776x DMD64. Four parallel
OpenC builds sustain 20.959 projects per second, ahead of all three comparator
batches on that observation. Bootstrap took 7.913 and 8.340 seconds; the
largest private/working-set peaks were 177,147,904 and 59,793,408 bytes. All
correctness, execution, fixed-point, output, and 512 MiB memory guards pass.

Resolution is no longer the largest phase. The confirmation samples attribute
780–782 milliseconds to lowering/emission, including 251–267 milliseconds of
fresh parsing, 62–93 milliseconds of index construction, 77–124 milliseconds
of IR lowering, and 187–235 milliseconds of native emission. That phase is the
next measured target.

## Exact parsed-source reuse

Automatic push run
[`34781697232`](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/34781697232)
completed successfully at commit `3013c79065df9f7fed0cb4aed7cca4cfb63f5021`.
Artifact `OpenC-SH27-production-performance-34781697232`, ID `10325517880`,
contains 13,786,339 ZIP bytes at
`sha256:fed032f776446cd3c8c1c4986fdae0e666dd817796f00e7bb9d2d0541f3b3e82`.

Native resolution now retains exact-size copies of valid token and syntax
records and native lowering consumes those immutable records instead of
allocating and parsing the source again. Malformed/recovered syntax retains
the complete fresh-parse path. Legacy C emission does not retain unused cache
records when its parallel path owns parsing. Cache entries have one project
lifetime and one deferred release path; all uncertain cases remain complete.

The immutable seed built the checked-out compiler twice under the RAM guards.
The two 7,153,664-byte outputs are byte-identical at SHA-256
`9d1d34ea…71baa6`; guarded builds took 7.982 and 7.124 seconds. The largest
private/working-set peaks were 193,200,128 and 81,358,848 bytes. The increased
working set is the explicit cost of retaining useful syntax, while large-build
peak private memory falls to 146,243,584 bytes because exact records replace a
later worst-case parser arena. Native conformance remains 278/278, the
repository audit remains exact, and every 512 MiB process guard passes.

| Workload | OpenC | MSVC | Clang | DMD64 |
|---|---:|---:|---:|---:|
| small single file | 0.097 s | 0.129 s | 0.117 s | 0.128 s |
| 24 source files | 0.240 s | 0.330 s | 0.823 s | 0.159 s |
| 2,048 functions | 1.550 s | 0.497 s | 1.005 s | 0.302 s |

The large median improves another 14.3% from the prior 1.808-second confirmed
result and 18.4% from the immediately preceding 1.899-second automatic
observation. It is 94.0% below the original 25.983-second result. The large
ratios remain open at 3.119x MSVC, 1.542x Clang, and 5.132x DMD64. The 24-file
and one-source-edit medians are both 0.240 seconds, and four parallel OpenC
builds sustain 22.293 projects per second, ahead of every comparator batch on
this observation.

All three large samples record 0 milliseconds for lowering's parse component.
Lowering/emission falls from the preceding automatic run's 811–829 milliseconds
to 501–531 milliseconds. Declaration parsing remains 250 milliseconds and
resolution remains 281–297 milliseconds; moving cache creation to declaration
collection so resolution can reuse the same records is the next measured
frontend target. The complete compiler self-build median is 7.888 seconds.

## One-parse frontend cache

Automatic push run
[`34782327317`](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/34782327317)
completed successfully at commit `6e47bf8311e1b7670ac7f985e7b6f535fbc93075`.
Artifact `OpenC-SH27-production-performance-34782327317`, ID `10325042979`,
contains 13,789,849 ZIP bytes at
`sha256:b04e589741ca19148d38b8d4e99de3e7004b3d2fac258ba395ca2892655b2759`.

Cache construction now occurs during declaration collection. The same exact,
read-only token and syntax records feed predeclaration, resolution, fused
acceptance/lowering, and native emission. Resolution therefore performs symbol
collection without another lexer/parser or copy pass. Malformed sources remain
uncached and retain all complete recovery paths. An initially rejected version
also proved the ownership gate: bootstrap refused a temporary struct initializer
that captured two live allocations, so the final code uses one null-initialized
owner, exact copies, and one project-level deferred release.

The immutable seed built the checked-out compiler twice under the RAM guards.
The two 7,157,248-byte outputs are byte-identical at SHA-256
`d79c980d…51661e`; guarded builds took 5.754 and 4.781 seconds. The largest
private/working-set peaks were 194,691,072 and 81,829,888 bytes. Large-build
peak private memory remains lower at 145,428,480 bytes, with 50,749,440 peak
working-set bytes. Native conformance remains 278/278, the repository audit
remains exact, and every 512 MiB process guard passes.

| Workload | OpenC | MSVC | Clang | DMD64 |
|---|---:|---:|---:|---:|
| small single file | 0.088 s | 0.172 s | 0.118 s | 0.243 s |
| 24 source files | 0.179 s | 0.389 s | 0.740 s | 0.159 s |
| 2,048 functions | 0.931 s | 0.491 s | 0.707 s | 0.281 s |

The large median improves another 39.9%, from 1.550 to 0.931 seconds, and is
96.4% below the original 25.983-second result. Resolution records 0
milliseconds in every large sample, down from 281–297 milliseconds. The small
and 24-file lanes now pass the 1.25x target against all three comparators; the
24-file OpenC median is 46.0% of MSVC, 24.2% of Clang, and 1.126x DMD64. Four
parallel OpenC builds sustain 25.151 projects per second, ahead of every
comparator batch on this observation.

Large-program parity remains open at 1.896x MSVC, 1.317x Clang, and 3.313x
DMD64. The large phase ranges are 172 milliseconds for declaration/cache
construction, 0 milliseconds for resolution, 280–298 milliseconds for
validation, and 390–406 milliseconds for lowering/emission. Flow still spends
31 milliseconds reparsing the one stateful source; expression acceptance costs
93–109 milliseconds and calls cost 16–31 milliseconds. Reusing the existing
cache in flow validation is next. The complete compiler self-build median is
4.747 seconds.

## Flow-validation parsed-source reuse

Automatic push run
[`34783166021`](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/34783166021)
completed successfully at commit `9250641f40808ae2752fa101902a01088a514e73`.
Artifact `OpenC-SH27-production-performance-34783166021`, ID `10325841154`,
contains 13,790,426 ZIP bytes at
`sha256:cdc36fdc8d8e2c9bf11f9f22742c76de0deb02234ab05fcd6dfcfedc2400287f`.

Flow validation now consumes the same exact, immutable token and syntax records
already owned by the project cache. Non-native callers and any source that was
not safely cached retain the complete lexer/parser path and free only their own
fallback allocations. The change therefore removes the last known frontend
reparse without weakening recovery or transferring cache ownership.

The retained seed again built checked-out source twice under the RAM guards.
The two 7,157,760-byte outputs are byte-identical at SHA-256
`5c0a7fb4…079e7`; guarded builds took 8.495 and 6.300 seconds. Their largest
private/working-set peaks were 194,830,336 and 81,895,424 bytes. A local
three-stage fixed point produced the same compiler hash, native conformance
remains 278/278, the repository audit passes, and all local and workflow
processes remained below the 512 MiB private and working-set ceilings.

| Workload | OpenC | MSVC | Clang | DMD64 |
|---|---:|---:|---:|---:|
| small single file | 0.097 s | 0.128 s | 0.138 s | 0.159 s |
| 24 source files | 0.200 s | 0.362 s | 0.881 s | 0.180 s |
| 2,048 functions | 1.305 s | 0.532 s | 1.057 s | 0.339 s |

Absolute time moved upward for several tools on this runner observation, so it
is not used to claim a cross-run wall-clock improvement. The directly
attributable flow-parse counter is 0 milliseconds in all three large samples,
down from 31 milliseconds in the preceding run. Large OpenC/Clang is now
1.235x and passes the 1.25x parity gate for the first time. The large MSVC and
DMD64 deficits remain explicit at 2.453x and 3.850x. Seven of the nine
workload/comparator gates now pass.

The clean large samples attribute 281–297 milliseconds to declaration/cache
construction, 15–16 milliseconds to resolution, 346–423 milliseconds to
validation, and 547–608 milliseconds to lowering/emission. Expression
acceptance remains 109–125 milliseconds, call acceptance 31–32 milliseconds,
index construction 62–78 milliseconds, IR lowering 95–155 milliseconds, and
native emission 218–281 milliseconds. The complete compiler self-build median
is 6.274 seconds with 194,011,136 peak private bytes and 81,461,248 peak
working-set bytes. The repeated one-source-edit median is 0.200 seconds, and
four parallel OpenC builds sustain 21.572 projects per second, ahead of every
comparator batch on this observation.

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
