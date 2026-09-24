# SH-27 pinned hosted representative medium-app proof

Status: **PASS for this checked-in four-module audit fixture; not SH-27
completion or broad C/D-class parity.**

The [Windows-2025 hosted run 35946485926](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35946485926)
at commit `5739dfb` verified separately reviewed literal SHA-256 identities for
MSVC `cl.exe`/`link.exe` and DMD 2.112.0, guardedly bootstrapped the checked-out
OpenC source to an exact Stage 2/3 fixed point, then compiled and executed
the checked-in `medium_audit` application in OpenC, C17/MSVC, and D/DMD.
Its [raw artifact](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35946485926/artifacts/10787161624)
contains every build/measurement record and the final
`representative-medium.json` report. The compiler source matches the
`1b58d5e` production-source parity certificate; documentation and CI pins
changed, not compiler source. Stage 2 and 3 had the same SHA-256
`d0c18a385d1589db21da0c9ec5684e442bf828124d46c489aed29c4dddb6d9e7`.

All three independent staged repetitions passed exact stdout/stderr/exit
equivalence for cold, warm, and one-source edit, including runtime output
equivalence across all three languages. Median **compiler-plus-link** wall
seconds (three samples per cell) were:

| Language/tool | Cold | Warm | Edit |
| --- | ---: | ---: | ---: |
| OpenC fixed-point compiler | 0.087 | 0.086 | 0.087 |
| MSVC C17 | 0.408 | 0.401 | 0.409 |
| DMD D | 0.782 | 0.788 | 0.798 |

The first MSVC cold sample was 3.760 s and the first DMD cold sample was
1.247 s; the table uses medians and the raw samples are preserved. OpenC's
highest observed child working set was 11,546,624 bytes and private bytes
21,237,760, within the suite's 64/256 MiB compiler limits. Comparator
compiles use their separately declared 512/512 MiB limits; they are not
misrepresented as meeting OpenC's gate.

This is a small benchmark-authored file-processing program, not an
independent retained user project. "Warm" repeats unchanged inputs after
a build with OS cache present; OpenC has no module artifact cache here, so
the warm/edit values prove **no incremental speedup**. MSVC and DMD standard
libraries and DMD's selected linker are not separately hashed, though the
runner image and compiler binaries are recorded. The generated large/control
20-ratio gate is independent and is not replaced by this result. A later
compiler-source change must rerun all final-source certificates.

Next: retain larger third-party or user projects, execute repeated
cross-language comparisons on them, build actual content-validated per-module
COFF reuse and relink, then repeat the complete synthetic, strict-memory,
conformance, editor, and release gates on one final source revision.
