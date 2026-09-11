# SH-21 OpenC-native workflow tranche 1 evidence

Status: **PASS FOR THIS TRANCHE; SH-21 REMAINS ACTIVE**.

This tranche establishes the first required workflow that is itself authored
in OpenC. It does not close SH-21: native child-process enforcement,
structure/source/coverage inspection, PE and LSP verification, benchmarking,
and deterministic release/archive ownership remain open exit gates.

## Native workflow result

The public command is:

```text
openc workflow --root=ROOT --output=REPORT.json --mode=daily|full
```

The final renamed compiler passed the full workflow in 160.792 seconds:

- 7/7 native workflow tasks;
- 278/278 native conformance fixtures;
- 5/5 maintained and native-runtime programs;
- public version, target, and project-check contracts;
- two successive native compiler rebuilds;
- exact compiler/Stage-2/Stage-3 SHA-256 equality;
- no Python, D, C compiler, TinyCC, external assembler, or external linker
  invoked by the workflow.

The daily mode passed 4/4 tasks in 3.320 seconds under the external evidence
guard. It compiles the five-program manifest without running the programs and
keeps full conformance and compiler closure in `full` mode.

The fixed-point compiler has 117 canonical OpenC compiler source units,
1,621,898 source bytes, and these stable properties:

- executable bytes: 5,018,624;
- SHA-256:
  `53bb43c52c78af6f4f2cf42c5861e2fa979c67c51c9c3b94d31502d3b7426701`.

The two fixed-point builds were deliberately named
`openc-renamed-a.exe` and `openc-renamed-b.exe`. Their exact equality and the
successful workflow run from `openc-renamed-b.exe` prove that recursive
compiler actions now locate the actual process image rather than assuming a
sibling named `openc.exe`.

## Memory evidence and current boundary

The two guarded compiler builds passed the existing 256 MiB private-byte and
64 MiB working-set ceilings. Their maximum observed values were 217,858,048
private bytes and 48,074,752 working-set bytes. Captured output remained below
4 MiB.

The outer full-workflow process used 33,853,440 private bytes and 28,196,864
working-set bytes. This outer observation does not measure or constrain the
entire descendant tree. The native workflow therefore does not yet claim the
SH-21 child-supervision exit gate; each compiler build used the existing
external guard while the OpenC-owned supervisor remains pending.

## Defects found and closed

Two backend defects were exposed by exercising the workflow in process:

1. Native lowering treated an `out ptr` local as an already initialized
   address. `file.read_bytes_raw` could consequently write through address
   zero. Output operands now use lvalue-storage addressing, and the maintained
   `E_NATIVE_OUT_POINTER` program reads and frees `VERSION` successfully.
2. Recursive compiler commands constructed a sibling `openc.exe` path. The
   standard process module and both native/C bootstrap backends now expose the
   actual executable path, and all recursive CLI consumers use it.

The new `openc hash FILE` command also computes SHA-256 without Python and is
used by the fixed-point workflow.

## Primary local records

- `build-output/selfhost-sh21/final-workflow/renamed-daily.json`;
- `build-output/selfhost-sh21/final-workflow/renamed-full.json`;
- `build-output/selfhost-sh21/final-workflow/renamed-full-parent-memory.json`;
- `build-output/selfhost-sh21/rename-final/gen2-memory.json`;
- `build-output/selfhost-sh21/rename-final/gen3-memory.json`.

These build-output records are reproducible working evidence, not canonical
source-controlled artifacts. The plan, inventory, test manifest, and this
evidence summary are the canonical record for the tranche.
