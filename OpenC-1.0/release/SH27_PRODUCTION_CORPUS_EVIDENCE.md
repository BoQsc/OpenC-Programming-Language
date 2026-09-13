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

## Single-pass flow feature discovery

Automatic push run
[`34783983035`](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/34783983035)
completed successfully at commit `ec54933e1d09fced41932dce0134dd88cbda74b2`.
Artifact `OpenC-SH27-production-performance-34783983035`, ID `10325802498`,
contains 13,792,332 ZIP bytes at
`sha256:27561b2cebd760e4ab029d3bbd93f1d4a3918217bee1c4a2297732687fe46a28`.

The stateless-source gate formerly searched the complete source independently
for seven required words/operators and, for pointer-bearing projects, three
more operators. It now discovers the exact same substring features in one
pass and carries the `own` observation into later ownership logic. This keeps
every conservative positive while making negative work linear in source bytes
with one traversal instead of seven to ten.

The two guarded workflow rebuilds took 5.331 and 4.135 seconds and produced a
byte-identical 7,159,808-byte compiler at SHA-256 `703e79b1…2af2b3`. Their
largest private/working-set peaks were 193,687,552 and 81,465,344 bytes. A
local three-stage fixed point has the same hash, native conformance remains
278/278, repository audit passes, and all processes remain within both 512 MiB
evidence limits.

| Workload | OpenC | MSVC | Clang | DMD64 |
|---|---:|---:|---:|---:|
| small single file | 0.075 s | 0.096 s | 0.096 s | 0.158 s |
| 24 source files | 0.158 s | 0.307 s | 0.695 s | 0.119 s |
| 2,048 functions | 0.805 s | 0.413 s | 0.600 s | 0.262 s |

This is the fastest clean OpenC large median so far, 13.5% below the preceding
0.931-second low and 96.9% below the original 25.983-second result. Clean flow
falls from the preceding run's 93–94 milliseconds to 31–47 milliseconds, and
its parse counter remains zero. Three interleaved local A/B pairs independently
reduce flow from 187–219 to 140–141 milliseconds and produce byte-identical
programs without a material memory change.

Comparator timing also moves materially on this runner. Consequently, the
latest large ratios are still open at 1.949x MSVC, 1.342x Clang, and 3.073x
DMD64; the prior run's isolated Clang-gate pass is recorded but not promoted
as sustained parity. The unusually fast 0.119-second DMD64 many-file median
also moves that gate to 1.328x. Five of nine latest workload/comparator gates
pass. The complete self-build median is 4.262 seconds, the one-source-edit
median is 0.158 seconds, and four parallel OpenC builds sustain 32.307 projects
per second, ahead of all comparator batches.

The large clean phase ranges are 140–156 milliseconds for declarations,
0–16 milliseconds for resolution, 173–220 milliseconds for validation, and
358–421 milliseconds for lowering/emission. Expression acceptance remains
32–112 milliseconds; native index construction, IR lowering, and emission
remain 15–94, 62–123, and 111–172 milliseconds. Those compiler-owned passes
are the next measured targets.

## Acceptance expression candidate gates

Automatic push run
[`34784470942`](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/34784470942)
completed successfully at commit `7a0aa56cbe715862152fb80e20986cc87f07b96a`.
Artifact `OpenC-SH27-production-performance-34784470942`, ID `10325947882`,
contains 13,795,181 ZIP bytes at
`sha256:f88e4c095f35e81f809e1e15e7c81f542efdb6fec22dbca42c81c9be56f0f966`.

Acceptance now discovers assignment, binary, index/range, cast, and aggregate
syntax kinds once per source and does not enter a complete indexed traversal
for a rule family with no candidate. Every family with a matching kind retains
its full validator and per-rule reporting. On the generated large lane this
replaces three known-empty expression traversals with one shared discovery
traversal.

The workflow produces a byte-identical 7,162,880-byte compiler at SHA-256
`e908efa1…427181`. Bootstrap takes 8.087 and 6.310 seconds with largest
private/working-set peaks of 192,778,240 and 77,905,920 bytes. Local exact
fixed point, 278/278 conformance, repository audit, output equivalence, and all
512 MiB process guards pass. Interleaved local A/B reduces median expression
validation from about 281 to 253 milliseconds, although clean absolute timing
continues to vary across hosts.

| Workload | OpenC | MSVC | Clang | DMD64 |
|---|---:|---:|---:|---:|
| small single file | 0.097 s | 0.119 s | 0.118 s | 0.139 s |
| 24 source files | 0.200 s | 0.338 s | 0.852 s | 0.170 s |
| 2,048 functions | 1.237 s | 0.500 s | 1.016 s | 0.312 s |

The clean large ratios are 2.474x MSVC, 1.218x Clang, and 3.965x DMD64.
The Clang gate passes again, and all small and many-file gates pass. The
complete compiler self-build median is 6.866 seconds with 194,805,760 peak
private bytes and 81,649,664 peak working-set bytes.

## Already-ordered IR emission path

Automatic push run
[`34784845146`](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/34784845146)
completed successfully at commit `f36616d6c7f27730bdae0195324add8b0df52fb6`.
Artifact `OpenC-SH27-production-performance-34784845146`, ID `10325858698`,
contains 13,796,249 ZIP bytes at
`sha256:b50e51e7d7a4d6eaeb06e3b2e9e90c1f22646691b7f093d4f76a5637a5c3ad97`.

Native emission previously allocated two counting-sort work arrays and made
multiple passes for every function even when lowering had already emitted
instructions in monotonically increasing block order. It now proves that
property while constructing the identity order and returns it directly. Any
non-monotonic or invalid block stream retains the complete stable counting
sort. Emitted order is unchanged, while straight-line and already ordered
functions avoid the redundant arrays and traversals.

The workflow produces a byte-identical 7,163,904-byte compiler at SHA-256
`1c20b08f…3b709`. Guarded bootstrap takes 8.085 and 6.469 seconds; largest
private/working-set peaks are 195,235,840 and 82,681,856 bytes. Local fixed
point, 278/278 conformance, audit, and three pairs of byte-identical A/B large
outputs pass under the same 512 MiB limits.

| Workload | OpenC | MSVC | Clang | DMD64 |
|---|---:|---:|---:|---:|
| small single file | 0.097 s | 0.127 s | 0.139 s | 0.159 s |
| 24 source files | 0.235 s | 0.366 s | 0.950 s | 0.194 s |
| 2,048 functions | 1.248 s | 0.499 s | 1.029 s | 0.314 s |

Clean native-emission samples are 186, 221, and 250 milliseconds, compared
with 235, 250, and 250 milliseconds in the preceding run. Because other phases
and total wall time vary, this is localized evidence rather than a cross-run
total-speed claim. The latest large ratios are 2.501x MSVC, 1.213x Clang, and
3.975x DMD64: Clang passes for a second consecutive run, while MSVC and DMD64
remain materially open. Seven of nine latest workload/comparator gates pass.
The complete self-build median is 6.326 seconds with 195,239,936 peak private
bytes and 81,907,712 peak working-set bytes.

## Bounded call-free native constant pools

Automatic push run
[`34785359915`](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/34785359915)
completed successfully at commit `a9ce07b244ad3472f082234d9141af2edd8121cc`.
Artifact `OpenC-SH27-production-performance-34785359915`, ID `10326641080`,
contains 13,797,330 ZIP bytes at
`sha256:79c9029b91612f06892e0df5f8ec582cd2d489c8e1dae77dad58a57f5049ebb9`.

Native function setup formerly reserved twice the complete source length for
every function's constant buffer. A call-free function cannot enter a runtime
intrinsic emitter, so its constant section can contain only decoded
`const_text` instructions. The compiler now sums those encoded literal spans
while it already scans the function's instructions and uses that conservative
per-function bound. Functions containing calls retain the original reserve.

The workflow produces a byte-identical 7,164,928-byte compiler at SHA-256
`b068e3d4…108d96`. Guarded bootstrap takes 8.675 and 6.760 seconds; largest
private/working-set peaks are 195,629,056 and 77,950,976 bytes. Local exact
three-stage closure, 278/278 conformance, repository audit, and output
equivalence all pass within both 512 MiB limits. Three interleaved local A/B
pairs reduce median native emission from 763 to 516 milliseconds while
producing the same `54fe73ad…02746b` large-corpus executable.

| Workload | OpenC | MSVC | Clang | DMD64 |
|---|---:|---:|---:|---:|
| small single file | 0.108 s | 0.118 s | 0.150 s | 0.171 s |
| 24 source files | 0.245 s | 0.414 s | 1.022 s | 0.182 s |
| 2,048 functions | 1.436 s | 0.623 s | 1.103 s | 0.349 s |

Clean large native-emission samples are 204, 265, and 292 milliseconds. The
same-run large ratios are 2.305x MSVC, 1.302x Clang, and 4.115x DMD64. The
latest Clang observation is just outside the gate after two passing runs, so
large Clang parity is treated as intermittent rather than closed. Small OpenC
beats all three comparators; the many-file lane beats MSVC and Clang but is
1.346x DMD64. Six of nine current workload/comparator gates pass. The complete
self-build median is 7.361 seconds with 193,482,752 peak private bytes and
79,544,320 peak working-set bytes. Comparator and other compiler phases again
move materially on this shared runner; isolated phase evidence is retained,
but no cross-run total-speed claim is made.

## Indexed duplicate-function validation

Automatic push run
[`34786288051`](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/34786288051)
completed successfully at commit `a034b90b10cb73ed280134e75cd638d4822303b2`.
Artifact `OpenC-SH27-production-performance-34786288051`, ID `10326636966`,
contains 13,802,487 ZIP bytes at
`sha256:6c85e7e225c995036ff9a3b140a49fad64517cde4a024313648fc0d987098190`.

Duplicate-function validation formerly compared every top-level function with
every later symbol, reloading source names across roughly two million pairs in
the generated large lane. It now uses the already initialized module/name hash
buckets, checks only later functions in the matching bucket, and retains exact
name and signature comparison. The complete quadratic implementation remains
the fallback when indexes are unavailable.

The workflow produces a byte-identical 7,168,512-byte compiler at SHA-256
`12740066…44c2`. Guarded bootstrap takes 8.181 and 6.215 seconds; largest
private/working-set peaks are 194,789,376 and 82,161,664 bytes. Local
three-stage closure has the same hash, native conformance passes 278/278, and
the repository audit passes. The largest local fixed-point process remains at
186.3 MiB private and 77.9 MiB working set. Three interleaved large-corpus A/B
pairs reduce global acceptance overhead from a 203-millisecond median to 31
milliseconds, total acceptance from 564 to 423 milliseconds, and total build
time from 2.360 to 2.203 seconds with byte-identical output.

| Workload | OpenC | MSVC | Clang | DMD64 |
|---|---:|---:|---:|---:|
| small single file | 0.097 s | 0.110 s | 0.119 s | 0.161 s |
| 24 source files | 0.202 s | 0.350 s | 0.876 s | 0.161 s |
| 2,048 functions | 1.173 s | 0.497 s | 1.047 s | 0.314 s |

Clean large acceptance samples are 187, 202, and 204 milliseconds; expression
work is 109–126 milliseconds and call rules are 31–32 milliseconds. Large
ratios are 2.360x MSVC, 1.120x Clang, and 3.736x DMD64. The Clang gate passes
comfortably again. The many-file DMD64 ratio is 1.255x, only 0.5 percentage
points outside the gate. Seven of nine current workload/comparator gates pass.
The complete self-build median is 6.182 seconds with 194,011,136 peak private
bytes and 80,048,128 peak working-set bytes.

## Bulk native buffer copies

Automatic push run
[`34786895725`](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/34786895725)
completed successfully at commit `94aaa6810e08814d09dc4f302304f891254a9c50`.
Artifact `OpenC-SH27-production-performance-34786895725`, ID `10327111326`,
contains 13,803,072 ZIP bytes at
`sha256:36b11efaebc27b3572304c09169b23c9d77ec4a6a4f1329f017498263c984628`.

Native function assembly, object-stream linking, and final PE construction
formerly copied binary buffers with one checked `d_put_byte` call per byte.
The buffer layer now provides one capacity-checked raw-range copy backed by the
OpenC runtime's own memory-copy implementation. The x64 and native-image paths
use that operation without adding an OS, CRT, C, D, Python, assembler, or
linker dependency.

The workflow produces a byte-identical 7,169,024-byte compiler at SHA-256
`f475afa6…054411`. Guarded bootstrap takes 8.121 and 5.980 seconds; largest
private/working-set peaks are 193,204,224 and 80,199,680 bytes. Local
three-stage closure has the same hash, 278/278 conformance and the repository
audit pass, and all processes remain below both 512 MiB limits. Three
interleaved local A/B pairs preserve the exact large executable while reducing
total median from 1.515 to 1.329 seconds, lowering/linking from 733 to 579
milliseconds, and per-function native emission from 298 to 237 milliseconds.

| Workload | OpenC | MSVC | Clang | DMD64 |
|---|---:|---:|---:|---:|
| small single file | 0.097 s | 0.120 s | 0.117 s | 0.150 s |
| 24 source files | 0.189 s | 0.347 s | 0.895 s | 0.159 s |
| 2,048 functions | 1.045 s | 0.509 s | 1.055 s | 0.313 s |

OpenC now passes every small and many-file comparator gate, including 1.189x
DMD64, and beats Clang on the large median at 0.991x. Seven of nine current
gates pass. Large MSVC and DMD64 remain open at 2.053x and 3.339x. Clean large
lowering/emission samples are 387–469 milliseconds and native emission is
172–220 milliseconds. The complete self-build median is 5.910 seconds with
193,921,024 peak private bytes and 77,561,856 peak working-set bytes.

## Direct stack-allocation unwind records

Automatic push run
[`34787176733`](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/34787176733)
completed successfully at commit `552730e0b9a41aaeacf8cb17861c61a72e05b4ca`.
Artifact `OpenC-SH27-production-performance-34787176733`, ID `10326343689`,
contains 13,808,420 ZIP bytes at
`sha256:3daa6fbaa50fcf2382475d1c276c80643e9729965ea64e4fbafa996d1956c45c`.

Each generated function has exactly one stack-allocation unwind operation, but
the native path formerly allocated a generic operation arena and a second
encoded buffer per function. A specialized encoder now writes that exact
Windows x64 unwind record directly into the checked object stream. The generic
multi-operation builder remains unchanged for probes and future prologs.

The workflow produces a byte-identical 7,173,120-byte compiler at SHA-256
`0b2ff97d…6064e5`. Guarded bootstrap takes 6.893 and 5.057 seconds; largest
private/working-set peaks are 193,728,512 and 77,668,352 bytes. Local exact
three-stage closure has the same hash, 278/278 conformance and repository audit
pass, and all processes stay below both 512 MiB limits. Three interleaved local
A/B pairs preserve the exact large executable while reducing median native
emission from 284 to 203 milliseconds and total time from 1.407 to 1.344
seconds.

| Workload | OpenC | MSVC | Clang | DMD64 |
|---|---:|---:|---:|---:|
| small single file | 0.097 s | 0.138 s | 0.139 s | 0.138 s |
| 24 source files | 0.181 s | 0.375 s | 0.863 s | 0.159 s |
| 2,048 functions | 0.869 s | 0.501 s | 0.820 s | 0.313 s |

Clean large native-emission samples are 140, 141, and 156 milliseconds. OpenC
passes Clang at 1.060x and every small and many-file gate. Large MSVC and DMD64
remain open at 1.735x and 2.776x. Seven of nine current gates pass. The complete
self-build median is 4.864 seconds with 194,088,960 peak private bytes and
77,447,168 peak working-set bytes.

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
