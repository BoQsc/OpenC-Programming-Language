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

## Independent current-source memory and release checks

The checked-out production source was rebuilt through a local guarded
three-stage bootstrap. Stage 2 and Stage 3 were byte-identical at SHA-256
`d0c18a385d1589db21da0c9ec5684e442bf828124d46c489aed29c4dddb6d9e7`.
Using Stage 3, `benchmark_sh20_stability.py --chain-runs 20 --enforce`
passed 5/5 small, 5/5 one-source, and 20/20 chained native rebuilds, with
byte-exact closure, all 13 recorded checks true, peak child private
255,287,296 bytes, peak child working set 60,051,456 bytes, and peak Job
private 255,291,392 bytes. The child limits were 256 MiB private and 64 MiB
working set; the process tree stayed below 512 MiB. Note that the separate
three-stage bootstrap uses a 512 MiB guard; its Stage 2 working set was
67,469,312 bytes, slightly above 64 MiB. Do not claim that *bootstrap Stage 2*
passed the stricter chain guard. The ignored local report is
`build-output/selfhost-sh27/sh27-current-source-cert-20260924/strict20.json`.

`verify_sh27_post_release.py` separately streamed and SHA-256-checked all
15 immutable public `v1.0.0` assets (48,681,989 bytes), its annotated tag
commit, release record, and SHA256SUMS: `PASS`. The ignored local report is
`build-output/sh27-public-release-verification-20260924.json`. This protects
the *old* release; it does not authorize or publish a new one.

The current-source Stage 3 compiler also completed its full public native
conformance command under an explicit 512 MiB process-tree private and
128 MiB per-process working-set guard: `EXECUTED_NATIVE`, 278/278 passed,
zero failed or infrastructure failures, 29,532,160-byte peak Job private.
Its `--windows-x64-substrate` report returned `PASS`. The ignored local
reports are beside `strict20.json` as `conformance.json` and
`x64-substrate.json`.

The same compiler's `workflow --mode=daily` completed 13/14 tasks under a
512 MiB process-tree guard. Repository, runtime, PE/COFF 40/40, COM/WinRT
33/33, LSP/editor, editor-package, and contract 38/38 tasks passed. The
SH-25 finalization task failed 2/44 checks: its hardcoded historical
`review/SH25_WINDOWS_EDITOR_EVIDENCE.json` names compiler SHA-256
`eadbef1f065261385c2c36d524624347f7e5cd3c021a4a1db9ccfcaf7c191087`
and VSIX SHA-256
`081ff8dd6de0960b1981620b3151fbaf74bb12ce73f17afc78e32d38777c3828`,
while this source/package are
`d0c18a385d1589db21da0c9ec5684e442bf828124d46c489aed29c4dddb6d9e7`
and `de25a069573da12939fcb1eedb13e91a80632af1aa974ce5815a9b5b270d4574`.
The other 42 checks passed. This is a
**current clean-profile identity evidence gap**, not a green full workflow:
the package/editor clean-profile exercise must be rerun against the current
compiler and VSIX, with its real report supplied to the finalization audit.
Do not rewrite the historical SH-25 evidence file or bypass the identity
checks. The ignored local reports are `workflow-daily.json` and
`sh25-native-finalization-audit.json` beside `strict20.json`.

With explicit user approval, `sh25_clean_vscode_profile.py` then exercised
the current VSIX/Stage-3 compiler in a separate empty VS Code profile. It
passed on VS Code 1.137.0: extension activation, packaged-compiler selection,
LSP readiness, diagnostics, exact compiler/VSIX identities, and clean test
process-tree termination. Peak VS Code test-tree working set was
1,765,773,312 bytes below its 2 GiB guard; OpenC inside it peaked at
5,734,400 bytes below 64 MiB. The current-source direct `finalization-audit`
using that new report passed **44/44**. Ignored local reports are
`clean-profile-current.json` and `sh25-native-finalization-current.json`.
With renewed user approval, the same production Stage-3 compiler and VSIX
were independently exercised again in a newly empty profile on VS Code
1.137.0. This repeat passed extension activation, packaged compiler
selection, LSP/diagnostics, exact SHA-256 identity, zero unexpected server
exits, clean test-process termination, and the 2 GiB/64 MiB working-set
limits (test tree 1,764,036,608 bytes; OpenC 5,750,784 bytes). Its matching
direct finalization audit again passed **44/44**. Ignored local reports are
`clean-profile-approval-20260924.json` and
`sh25-native-finalization-approval-20260924.json` beside `strict20.json`.
The historical review record was not modified. The daily workflow's hardcoded
historical report still makes *its* aggregate 13/14; an explicit current
`--clean-profile` workflow input is needed before the aggregate can pass on
new compiler revisions.

This is not a full SH-27 completion certificate. The current native path still
has one whole-project COFF output, not content-validated per-module object
reuse or a multi-object native relink. Representative projects still need
broader retained-user-app coverage and repeated project-level comparisons;
the remaining diagnostic/runtime/ABI matrix and final-source reruns after
any compiler source change remain. The hosted parity report's own
`remaining_corpus_expansion` names incremental object reuse and broader
real-project coverage.
