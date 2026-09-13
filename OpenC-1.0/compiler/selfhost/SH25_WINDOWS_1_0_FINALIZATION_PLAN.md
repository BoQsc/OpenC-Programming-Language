# SH-25 Windows 1.0 finalization and review-intake plan

Status: **PASS**

Target: Windows x86-64 Hosted. Linux and freestanding remain optional future
targets and are not 1.0 gates.

## Required surface

- set the candidate identity to final `1.0.0` without weakening the frozen Core,
  ABI, conformance, performance, memory, or toolchain-independence contracts;
- have the OpenC-native compiler build a deterministic, dependency-free VSIX
  containing the exact fixed-point `openc.exe`;
- install that VSIX into empty VS Code user-data and extension directories and
  prove activation, native-server startup, and a diagnostic round trip;
- bound both the OpenC server and the complete editor process tree, and cleanly
  terminate the test process tree;
- publish an honest five-track external-review invitation and machine-readable
  intake without describing internal work as independent; and
- freeze the final Windows evidence while leaving final tag creation and public
  release publication to the project owner.

## Acceptance gates

`openc finalization-audit` must pass every record in
`tests/SH25_FINALIZATION_AUDIT_PLAN.tsv`. Two independently produced VSIX files
must be byte-identical, embed the exact compiler supplied to the command, and
contain no extension dependency. Clean-profile evidence must pass within the
2 GiB complete-editor and 64 MiB OpenC-server working-set ceilings.

Compiler work remains bounded at 64 MiB. VSIX package and finalization child
processes, which hold and verify the embedded compiler archive, have a distinct
96 MiB working-set ceiling and remain inside the existing 256 MiB Job limit.

The required native daily, full, contract, conformance, repository, benchmark,
fixed-point, and relocated-release gates remain green. Python may orchestrate
the external VS Code process because VS Code is not an OpenC-native component;
it is not used by `editor-package`, `finalization-audit`, or any ordinary OpenC
build, test, conformance, or release operation. No required native path invokes
D, C, TinyCC, Node/npm, an assembler, an external linker, or the network.

External review is invited and tracked but not fabricated: zero received
reviews means zero independently validated tracks. Any later P0/P1 finding is
handled under the published security and errata policies.
