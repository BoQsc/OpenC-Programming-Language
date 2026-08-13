# SH-14 compiler throughput convergence and stability evidence

Status: **PASS**

Date: 2026-08-10
Target: Windows x86-64 Hosted
Compiler implementation: OpenC `.p` source
Compiler SHA-256: `cac25c7221a3b183fe4a9a1c66a8edb927af9dd4e08879c5cf7ed0cc7b3af8fc`

## Throughput

The enforced five-run same-host suite passes every absolute, deterministic,
memory, and D-relative check:

| Measurement | Result | Gate |
| --- | ---: | ---: |
| OpenC clean median | 4.137 s | <= 30 s |
| OpenC clean maximum | 4.854 s | <= 45 s |
| Pinned D clean median | 12.731 s | reference |
| OpenC / D median ratio | 0.325x | <= 1.25x |
| Small-build median | 0.158 s | <= 0.250 s |
| Small-build maximum | 0.184 s | <= 0.500 s |
| One-source median | 0.158 s | <= 1.0 s |
| Worst scaling doubling | 2.112x | <= 2.4x |

The exact one-source lane fingerprints compiler, project, changed source,
runtime, target, profile, and TinyCC inputs. Identical fingerprints reproduce
identical outputs. Scaling uses deterministic 0.25, 0.5, 1, and 2 MiB,
32-source projects with proportional frontend, semantic, lowering, emission,
and backend work.

## Closure, stability, and memory

Twenty consecutive chained self-rebuilds pass. Every output compiler matches
its input at SHA-256
`cac25c7221a3b183fe4a9a1c66a8edb927af9dd4e08879c5cf7ed0cc7b3af8fc`,
and every generated C file matches SHA-256
`2fbc757171dcec184cc8e7a151c911f932b3d51e66ec761f1715e044a927b141`.
The soak median is 5.711 seconds and its maximum is 6.796 seconds. Peak private
memory is 250,437,632 bytes against the 256 MiB ceiling; peak working set is
26,804,224 bytes against the 32 MiB ceiling.

## Correctness and workflow

- native conformance: 278/278;
- maintained programs: 4/4;
- SH-9 native CLI: 12/12;
- SH-10 project workflow: 21/21;
- SH-11 LSP: 19/19;
- SH-12 semantic LSP: 23/23;
- full native workflow: 13/13;
- retained D seed executed by required workflow: false.

The native build record separately attributes project/frontend, declaration,
resolution, index, IR-lowering, C-emission, TinyCC, and total work. The D and
Python tools remain external comparison/evidence tools, not normal compiler or
runtime dependencies.

## Reproduction

```text
python compiler/selfhost/benchmark_throughput_suite.py --compiler PATH/TO/openc.exe --output build-output/selfhost-sh14/final-throughput-suite.json --runs 5 --enforce
python compiler/selfhost/benchmark_sh14_extended.py --compiler PATH/TO/STANDALONE/openc.exe --output build-output/selfhost-sh14/final-extended-suite.json --small-runs 9 --incremental-runs 7 --scaling-runs 5 --soak-runs 20 --enforce
python scripts/windows_native_workflow.py full --compiler PATH/TO/STANDALONE/openc.exe --output build-output/selfhost-sh14/full-workflow --force-conformance
```

The retained reports are:

- `build-output/selfhost-sh14/resolution-owner-index/final-throughput-suite.json`;
- `build-output/selfhost-sh14/resolution-owner-index/final-extended-suite.json`;
- `build-output/selfhost-sh14/resolution-owner-index/full-workflow-v2/full-workflow-result.json`.

## Next milestone

At SH-14 closure, SH-15 became active. SH-15 has since passed its Microsoft x64
ABI and typed machine-code/relocation substrate gates; its evidence is in
`SH15_WINDOWS_X64_ABI_MACHINE_CODE_EVIDENCE.md`. SH-16 has also passed its
deterministic, CRT-free PE32+ executable gate; SH-17 Win32 Metadata and raw
projection is active. Compiler-capable backend closure and TinyCC exit remain
SH-19.
