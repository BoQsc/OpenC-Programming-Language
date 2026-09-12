# SH-21 OpenC-native workflows and bootstrap boundary

Status: **ACTIVE; TRANCHE 6 PASS**.

Implementation progress: the Python ownership inventory is complete in
`SH21_PYTHON_WORKFLOW_INVENTORY.md`. The OpenC-authored `openc workflow` owns
public identity/project checks, four established programs plus the native
`out ptr` regression, native conformance, two compiler rebuilds, SHA-256
fixed-point comparison, and JSON evidence. Tranche 2 adds OpenC-native bounded
child supervision and a public adversarial `openc process-guard` verifier. The
third tranche adds the public OpenC-native `openc audit` command and makes
canonical-tree/source/authority/conformance/rule/grammar verification part of
both daily and full workflows. Tranche 4 adds the public `openc pe-audit`
command and makes PE32+, section, import, relocation, TLS, x64 unwind, and CRT
absence inspection native. Tranche 5 adds the public `openc lsp-audit`
command, canonical byte-counted JSON-RPC sessions, production state-machine/
framing coverage, deterministic wire transcripts, and native workflow
ownership of the 42 language-service contracts. Tranche 6 adds the public
`openc benchmark` command, 20-build exact closure, raw performance and memory
samples, legacy-tool rejection, and leak-free raw hashing under the existing
RAM ceilings. The fixed-point compiler passes all six tranches; see
`SH21_NATIVE_WORKFLOW_TRANCHE1_EVIDENCE.md` and
`SH21_NATIVE_PROCESS_GUARD_TRANCHE2_EVIDENCE.md` and
`SH21_NATIVE_REPOSITORY_AUDIT_TRANCHE3_EVIDENCE.md` and
`SH21_NATIVE_PE_AUDIT_TRANCHE4_EVIDENCE.md` and
`SH21_NATIVE_LSP_AUDIT_TRANCHE5_EVIDENCE.md` and
`SH21_NATIVE_BENCHMARK_TRANCHE6_EVIDENCE.md`. Deterministic release ZIP
ownership remains active work and is not claimed complete.

SH-20 makes the public compiler competitive with the measured C and D
references while keeping correctness and RAM bounds intact. SH-21 now removes
the remaining required Python orchestration and makes the first-binary
bootstrap boundary explicit. This milestone changes workflow ownership, not
OpenC language semantics or the already independent `openc build` path.

## Exit gates

- A clean normal environment containing only a pinned previous OpenC compiler,
  canonical `.p` source, and documented Windows system DLLs can build, test,
  validate, benchmark, package, and verify the release.
- Required workflows invoke no Python, DMD, DUB, TinyCC, C compiler, C runtime,
  external assembler, or external linker.
- OpenC-native tools reproduce deterministic archives, streaming hashes,
  package manifests, compiler/source fingerprints, and PE import/unwind audits.
- OpenC-native process supervision enforces the existing 256 MiB compiler
  private-byte, 64 MiB compiler working-set, bounded-output, and timeout rules;
  release packaging has explicit bounded streaming guards.
- The optional historical bootstrap/audit kit is separately named and is not
  searched or invoked by default. It may retain D, Python, C, and TinyCC only
  for archaeology, differential testing, or producing the first OpenC binary.
- SH-20 performance remains green: five-run public-build median at most 25
  seconds, validation median below 15 seconds, 20/20 exact closure, 278/278
  conformance, and 4/4 maintained programs.
- Two independent standalone archives remain byte-identical and pass the full
  relocated-package verifier with no legacy tool available.

## Work order

1. Inventory Python entry points used by `windows_native_workflow.py`, the
   standalone release builder/verifier, benchmarks, PE inspection, and source
   audits; classify each as required, optional audit, or obsolete history.
2. Move reusable manifest, hashing, ZIP, PE/COFF inspection, subprocess guard,
   and deterministic-report logic into OpenC-authored modules and compiler
   subcommands. Hashing, repository audit, and subprocess guards are complete;
   first-party PE executable inspection is complete; general COFF and ZIP
   ownership remain.
3. Add an OpenC-native `openc workflow` command for structure, conformance,
   maintained programs, CLI/project/LSP regressions, and performance gates.
   Structure/source/coverage, PE inspection, conformance, maintained programs,
   LSP regressions, and performance gates are now owned.
4. Add an OpenC-native `openc release` command that assembles and verifies two
   deterministic standalone archives using bounded streaming I/O.
5. Add an OpenC-native benchmark driver with raw samples, tool/input hashes,
   resource ceilings, and an optional explicitly requested C/D comparison.
   The required OpenC-only sampling and enforcement path is complete; C/D
   comparison remains optional and external.
6. Split retained D/Python/C/TinyCC material into a documented optional audit
   kit and prove it is absent and unavailable in the normal release run.
7. Execute the SH-20 regression suite and two independent neutral-path release
   verifications before marking SH-21 complete.

## What follows

SH-22 is PE/COFF ecosystem completeness: COFF objects, OpenC DLLs, imports and
exports, static/import libraries, resources, manifests, console/GUI subsystem
selection, secure runtime linking, and optional C-ABI interoperability. SH-23
then adds optional COM and WinRT projections. Native editor integration remains
SH-24. Linux and freestanding remain optional future targets.
