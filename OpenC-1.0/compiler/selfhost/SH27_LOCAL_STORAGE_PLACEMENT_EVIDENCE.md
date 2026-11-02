# SH-27 local storage-placement control

Status: **C: large-function DMD deficit reproduced; D: ratio improvement is
not an OpenC compiler speedup** (2026-09-27).

The first local 20-sample production run of compiler
`e68db627ca1ea4699691de23d93eb8760272c78e2c8ae02a06ac3337a09d6333`
on the Windows 10 four-logical-CPU host measured large functions at 1.462x
pinned DMD 2.112.0 with its generated corpus and outputs on C:. A second
20-sample run put all generated inputs and outputs on D:. Its five available
OpenC/DMD ratios passed 1.25x, including large functions at 1.198x and
control flow at 1.201x, but its overall status is `FAIL_PARITY` because MSVC,
Clang, and LDC are not installed locally. Both compilers were much slower in
absolute time on D: (large OpenC/DMD 0.898/0.750 s versus 0.532/0.364 s
in the earlier C: run). These separate runs alone cannot attribute the
change to storage rather than time-varying host load.

To test placement directly, `benchmark_sh27_storage_location.py` generated
byte-identical large-function sources on C: and D: and ran 11 adjacent pairs
of all four conditions: OpenC and DMD on each volume. Condition order rotated
and reversed across pairs. Every guarded compile and executable run passed;
OpenC's executable bytes were deterministic within each location. The same
OpenC and DMD SHA-256 identities were used throughout, with 512 MiB
compiler and 64 MiB program process-tree guards.

| Location | OpenC median | DMD median | OpenC/DMD |
| --- | ---: | ---: | ---: |
| C: inputs and outputs | 0.757 s | 0.515 s | **1.470x** |
| D: inputs and outputs | 0.941 s | 0.822 s | 1.145x |

The paired D:-minus-C: median was **+178 ms for OpenC** (D: slower in 10/11
pairs) and **+331 ms for DMD** (D: slower in 8/11 pairs). These two medians
are not additive and do not isolate source reads from output writes. They do
show that the 1.25x verdict on this host is sensitive to the combined volume
placement. The concurrently measured C: 1.470x ratio reproduces the earlier
1.462x C: deficit despite different absolute times. The D: pass is not a
reason to declare host-general C/D throughput parity or change the corpus
location to make the gate green.

The raw paired report is retained in local scratch at
`D:/openc-sh27-profile-jr31thkr/storage-location11.json`, SHA-256
`1ac8f8cd30aaa16a31ef3d7871f8e321b5a026a2aed9a571d9a02ba4cb9950ee`.
The separate D: 20-sample report is
`D:/openc-sh27-profile-jr31thkr/local-dmd20-d-drive.json`. Their run trees
remain in scratch for now. These are local DMD diagnostics, not the clean
five-compiler hosted gate, which passed 20/20 ratios on another host.

Next: keep the C: location as the local deficit reproducer. The latest
unprofiled large-function run shows a 336 ms critical two-source worker,
including 187 ms acceptance, with 86 ms serial declarations. A guarded
opt-in diagnostic profile localizes source 0 (the 256-call `main`) as the
critical source and observes 250 ms acceptance in that worker, including
124 ms expression and 78 ms call-rule time; opt-in profiling perturbs wall
time and these nested numbers cannot be subtracted from normal compilation.
The next compiler architecture must reduce actual first-visit and/or
semantic-to-lowering work on this critical source, then pass adjacent
large/control/self-build A/B and the same C: DMD gate. SH-27 remains active.
