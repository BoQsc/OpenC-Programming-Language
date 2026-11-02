# SH-27 current compiler and release qualification

Current status (2026-11-02): **SH-27 COMPLETE; 1.0.1 PUBLISHED AND VERIFIED**.
The final compiler is `7c6f7bbaa5b9ed737a23c5779c560e54e0954d51f8756c412aad7f5ab05d42f5`.
Two independent hosted C/D certificates, two cache/package certificates,
representative/four-project coverage, strict 20-generation closure, native
correctness and fresh editor checks pass. The exact pinned local DMD 2.112.0
large-function ratios are 1.087x/1.133x, below the unchanged 1.20x target.
The versioned release workflow builds and compares the final 16-asset set
before owner authorization. All five proof artifact identities and the bounded
local raw-evidence ZIP are pinned in
[qualification.json](.github/release-evidence/v1.0.1/qualification.json).
[Current qualification and findings](OpenC-1.0/compiler/selfhost/SH27_1_0_1_QUALIFICATION.md)
retains every rejected experiment and failed certificate. The owner authorized
the exact candidate and [v1.0.1 is published](https://github.com/BoQsc/OpenC-Programming-Language/releases/tag/v1.0.1)
at `06cdba3e0e4ba5e2539e45bd7f7d142d532347b4`. All 16 public assets match;
publication workflow `41521487125`, attempt 2, passes and immutable 1.0.0
remains unchanged. Durable receipts are pinned in
[publication.json](.github/release-evidence/v1.0.1/publication.json).

## Historical package-integrity checkpoint

The preceding package-integrity compiler is `0feaf99c92f07b773b47a9436ae620940b3596a550c0f515787dee699ff8943b`.
Fixed-point, conformance/ABI, native regression and fresh editor checks pass.
The `81787a12...` predecessor passes hosted original/scaling/negative-CLI,
module/cache/strict-20 and retained-project proofs, but its v3 four-CPU
large-function DMD ratio is 1.295x. The integrity compiler's first final-source
run is 1.274x; the unchanged ceiling remains 1.25x. Ten architectural/runtime
candidates were tested and rejected rather than promoted without a gain.
Two release integrity defects are fixed: nested D manifests in standalone
archives and stale source checksums. Native and independent package validation now pass; fresh hosted
proofs follow. [Current qualification and findings](OpenC-1.0/compiler/selfhost/SH27_1_0_1_QUALIFICATION.md).

The following checkpoint is historical and belongs to compiler `1859f47f...`.

Status (2026-11-02): **active; verification candidate, publication pending**.
Compiler SHA-256 is
`1859f47fa388d0de3f6003c028a5d3ed2bb6a70bd95dfe8091d46139237c1ed1`.
The 230-file compiler source is unchanged since `aec36012`; later commits
change verification, release inputs and evidence.

Two independent clean hosted production runs pass all twenty C/D ratio
checks, with 20 successful samples per tool/workload cell: 1,000 total
compile/execution samples. Both bootstrap the same exact compiler. The public
v1 corpus and its 1.25x ceilings are unchanged.

| Run | Large/control OpenC:DMD | Artifact ZIP SHA-256 | Raw production JSON SHA-256 |
| --- | --- | --- | --- |
| [40131377832](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/40131377832) | 0.413/0.202 | `65e3b2d982dfa4d76132d964da6805ecb23e534aa57cc1162ebd469a5ab31472` | `900981f857d8e04de328f89e8a9e96796e54880cc84d6332e579c59d3fcd67ab` |
| [41436539555](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/41436539555) | 0.397/0.199 | `7769f93c211562e5bb8a65301671ddce84ce3fdc552c28abb8c85ea1040548de` | `67e89e5fd7e9d0f6a154ed25db3f9ad62811425ba8e935215262dc9edabb216b` |

Two full native-cache/module runs also pass:
[40131377877](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/40131377877)
and [41436539551](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/41436539551).
The second downloaded ZIP is
`82d2d6a730987d79bf1787d2b996728164cbd43d75c7db843645a36bff078828`.
Both pass strict 20-generation exact self-hosting, cache/COFF recovery,
representative execution and the unchanged ordinary cold/warm/edit gates.
The repeat's 24-file cold paired overhead is 8.763 ms on 187.554 ms direct,
within the five-percent budget; this remains a narrow cold margin. Warm/edit
win 11/11. Compiler warm/edit also win 11/11 at 0.127139/0.529032 s against
3.461929/3.498340 s direct. Repeat strict peaks are 239,194,112 private and
63,025,152 working-set bytes. Do not infer a cold speedup from these passes.

Two retained four-logical-CPU DMD runs pass all five available public ceilings
at 1.228x/1.233x large and 0.773x/0.716x control. Large still misses the 1.20x
engineering headroom target by about 6.5 ms. Local MSVC/Clang/LDC are absent.
The [architectural experiment batch](OpenC-1.0/compiler/selfhost/SH27_FRONTEND_BATCH_NO_GO.md)
did not beat null noise and remains isolated.

## Release and editor checks

The release audit found nine manifest-listed compiler sources absent from
both the native release plan and source-completeness contract. Both inventories
now register all 230 sources. A detecting regression adds a source and proves
that either missing registration fails; CI checks coverage before bootstrapping.
The native plan also includes the authored SH-27 corpus, harness and evidence
files previously omitted from source packaging.

Two native editor-package builds have identical SHA-256
`d621340a7b47306c50a0f02bdb12c4d24dc30a0770e8febf41a3a73864cbb9bb`.
A new empty-profile VS Code 1.144.0 run installs the package, selects this exact
compiler, activates the language server and completes diagnostics, with no
unexpected server exits/provider failures. The test process tree is closed.
VS Code/OpenC working-set peaks are 1,643,352,064/5,726,208 bytes under the
existing 2 GiB/64 MiB limits. Native finalization 44/44, editor 33/33 and
contract 38/38 audits pass. The verified official VS Code ZIP SHA-256 is
`055722269e3c9531af0c50a8b757c14e8062a0d02fc973b038863d9732c567ea`.
The harness now supports the official ZIP's direct `resources/app/out/cli.js`
layout as well as version-directory installations.

Current evidence is [SH27_WINDOWS_EDITOR_EVIDENCE.json](OpenC-1.0/review/SH27_WINDOWS_EDITOR_EVIDENCE.json).
The native workflow's compatibility path `SH25_WINDOWS_EDITOR_EVIDENCE.json`
contains the same fresh evidence. Its original published-1.0 evidence is
preserved byte-for-byte in `SH25_WINDOWS_EDITOR_EVIDENCE_V1_0_0.json` with
SHA-256 `99a795ba5417d25c2a5f41a4bf27584862d4aab78612f415790913471abdb932`.

An isolated release input tree, containing exactly the 1,898 planned source
entries, passes the complete native release operation. The standalone has
1,535 entries, validates its manifest, rebuilds exact Stage 2/3, executes all
five maintained programs and native package audits, and passes 278/278 forced
conformance fixtures. Both archive pairs compare byte-for-byte:

| Artifact pair | Bytes each | SHA-256 |
| --- | ---: | --- |
| Standalone | 29,012,323 | `d4aefdf72015ed54c26eec29d24aaf7544c66e4afd49c1dac03c33e1d4e233f1` |
| Source | 17,326,818 | `5c7e90e5471f9c4dbd06b64eeebf6be3b168df353feb4dfe4e0a7c6a2f5baef5` |

The release Job peaks at 246,906,880 private bytes; the release process peaks
at 65,052,672 working-set bytes. Its native child guards remain active.
An earlier invocation from the repository's parent directory failed the
`VERSION`-reading maintained fixture. The successful isolated tree is the
working directory for the release proof; no fixture or language check changed.
These hashes identify that frozen 1,898-entry verification snapshot. Later
evidence/CI additions require final artifact regeneration before publication.

The immutable public `v1.0.0` tag and all fifteen assets stream-verify exactly.
The current public open-issue list is empty; checked-in intake has no received
independent reviews or open P0/P1 findings. No independent review is claimed.

Raw local evidence is retained under `OpenC-1.0/build-output/sh27-native-cache/`
and `OpenC-1.0/build-output/z27/release2/`. Remaining closure work includes
the real CLI's deliberate parity-failure proof, a requirement-by-requirement
incremental/project/scaling audit, and a fully versioned release record and
publication through the owner-authorized process. SH-27 remains active.
