# SH-27 normal-default parity replication on the current source

Status: **synthetic throughput replication passed; SH-27 remains open**.
Both independent GitHub-hosted Windows runs used production commit
`1b58d5e1bde84307426c5f5ff33171765b4ecf1f`, the normal default OpenC
compiler, `--runs 20 --require-all --enforce-parity`, and pinned MSVC 19.44,
Clang 20.1.8, DMD64, and LDC 1.43.0. No isolated compiler-speed candidate was
promoted between them. The immutable corpus was
`benchmarks/sh27/CORPUS.json` v1.

| Independent clean run | Result | Large-functions OpenC/DMD | Control-flow OpenC/DMD | Raw artifact |
| --- | --- | ---: | ---: | --- |
| [35941734238](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35941734238) | `PASS_PARITY`, 20/20 ratios | 0.753x (0.481/0.639 s) | 0.582x (0.291/0.500 s) | `10785676628` |
| [35942493151](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35942493151) | `PASS_PARITY`, 20/20 ratios | 0.843x (0.466/0.552 s) | 0.679x (0.297/0.438 s) | `10785616911` |

Each downloaded `sh27-production-comparators.json` reports all 20 named
OpenC-to-comparator checks true, all requested/version-pinned compilers
present, compile/memory/execution checks passed, and byte-exact Stage 2/3
current-source self-host fixed point. Every ratio is below 1.25x. The
five-workload maximum ratios across the four comparators were:

| Workload | Run 35941734238 | Run 35942493151 |
| --- | ---: | ---: |
| Small single file | 0.230x | 0.250x |
| Many files | 0.349x | 0.375x |
| Large functions | 0.753x | 0.843x |
| Control flow | 0.582x | 0.679x |
| Startup, file, allocation | 0.194x | 0.203x |

These are **within-run** ratios. Do not infer an OpenC speedup by comparing
absolute times between clean runners. An earlier clean run on this compiler
family showed a substantial DMD gap; these two passes establish replication
on the pinned hosted setup, not a guarantee across arbitrary hardware,
antivirus state, projects, or compiler releases.

This is not a full SH-27 completion certificate. The current native path still
has one whole-project COFF output, not content-validated per-module object
reuse or a multi-object native relink. Separately versioned representative
projects, cold/warm/edit cases, strict 20-generation 64 MiB working-set and
256 MiB private-byte self-build, full conformance/diagnostic/runtime/ABI
matrix, release integrity, and final-source reruns after any compiler source
change remain. The hosted parity report's own `remaining_corpus_expansion`
names incremental object reuse and broader real-project coverage.
