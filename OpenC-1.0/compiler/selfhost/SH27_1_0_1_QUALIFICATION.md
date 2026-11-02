# SH-27 1.0.1 qualification

Status: local correctness/resource/editor checks pass; clean hosted final-source
certification and final artifact verification remain required.

The 230-source 1.0.1 compiler reaches an exact Stage 2/3 fixed point:
`81787a122301898ce36c0caabe4c7c4a8449cdff8e80f773c63f8bf033549139`.
Only release-version strings changed in compiler code from the previously
certified `1859f47f...` implementation. The project manifest, VSIX and runtime
oracles now agree on 1.0.1; Core/Hosted language editions remain 1.0.

The mixed-project audit exposed a process-start race in the Python evidence
harness: a fast child could finish before Job assignment. Measurement v3
uses `CREATE_SUSPENDED`, assigns the child to its bounded Job, then resumes
the primary thread. It retains the process handle through post-exit peak
accounting. Duplicated output handles use an explicit inheritance allowlist.
The child receives a null input stream; this is a noninteractive audit API.
Assignment/resume failures terminate the suspended child and close its handles.
Seven detecting guard tests cover delayed assignment, both startup failures,
concurrent output, unrelated handle exclusion, and high-water memory limits.
The 256/64 MiB compiler and 512 MiB aggregate limits are unchanged.

This follows the documented Windows
[process-creation flags](https://learn.microsoft.com/en-us/windows/win32/procthread/process-creation-flags),
[Job assignment](https://learn.microsoft.com/en-us/windows/win32/api/jobapi2/nf-jobapi2-assignprocesstojobobject)
and [thread resumption](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-resumethread)
contracts. V2 and v3 timing observations retain distinct labels; old timing
certificates are not relabelled as new measurements.

Current local 1.0.1 checks pass 27 worker fault variants, 30 native-cache
cases, failed-publication cleanup, named-layout/invalid-input replay, strict
20-generation closure, 278 conformance fixtures, 25 ABI checks, large overflow
COFF/seeded bootstrap, and source-partition invalidation. Strict self-build
private/working-set peaks are 240,336,896/60,837,888 bytes.

| Raw report under `build-output/z27/` | SHA-256 |
| --- | --- |
| `v101-workers.json` | `a230a9a40b475cd055377a6f663eba0cef994d19e9779bcba9956839ab23075a` |
| `v101-cache.json` | `195035b2f4a4ebd250eff5dacc69d9519984b2225fce492ce848f9e183e78665` |
| `v101-publication.json` | `5f1410471a567a92f8b59d3972941119bbe01b0bf3ba463118ebdcf9d3ddf523` |
| `v101-strict20.json` | `0942c1f9a53a19dfe104ed7e4279b1de6919fdfc16642873464f8f2079767ae9` |
| `v101-coff3.json` | `0327f548614cbdb79d3633f0151f68667c1301a9d1a8e83cf14f5f7b5ccdfec9` |
| `v101-source-cache.json` | `68c80f345f1f3cdd21572ac88083a411167b21e786264c4b20b376c7b3d2a04f` |

The 1.0.1 editor package is byte-identical across two builds at SHA-256
`d225c5d35c3654c5a662f518ea2acaab145c9aba5f1b6d52af08cc3adf5bd588`.
A fresh VS Code 1.144.0 profile passes installation, packaged-compiler identity,
language-server startup and diagnostics. VS Code/OpenC working-set peaks are
1,712,590,848/5,668,864 bytes. Native finalization 44/44, editor 33/33 and
contract 38/38 checks pass. The published 1.0.0 profile remains preserved in
`review/SH25_WINDOWS_EDITOR_EVIDENCE_V1_0_0.json`.

The preceding compiler's v3 mixed-project proof covers 240 measured builds
and 160 primes across cold/unchanged/edited four-project batches. Warm/edit
concurrency wins 5/5 above null; cold stays within the unchanged budget.
The Job peaks at 268,611,584 private bytes. Twenty-sample four-CPU scaling
measurements cover 64/256/1,024 operations per function and 1/8/24/64 files.
All available DMD ratios pass, but local C/Clang/LDC tools are absent. These
preceding-source observations remain separate from 1.0.1 certification.
CI now reruns both scaling suites on all five tools and the actual retained
four-project batch on the final compiler.
