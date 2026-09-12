# SH-22 completion evidence

Status: **PASS**.

SH-22 implements the complete planned Windows x86-64 PE/COFF ecosystem lane
in OpenC. The public `openc artifact` command emits PE32+ console and GUI
executables, DLLs, AMD64 COFF objects, deterministic static libraries, and
deterministic import libraries. It embeds application manifests and `RCDATA`
resources, emits DLL export directories and initialization, retains x64 unwind
records, and exposes secure absolute-path run-time linking in
`windows.resources`.

## Executed interoperability evidence

The OpenC-native `openc pe-coff-audit` gate passes 40/40 checks. In addition to
structural and byte-determinism checks, it executes two independent calls into
an OpenC-generated DLL:

- a purpose-built PE32+ executable imports `openc_add` at load time and exits
  with the function result, 42;
- the OpenC compiler calls `LoadLibraryExW` with secure absolute-path search
  flags, resolves `openc_add` with `GetProcAddress`, invokes it through the
  Microsoft x64 ABI, receives 42, and closes it with `FreeLibrary`.

The generated object contains five AMD64 COFF sections, C-ABI export symbols,
code relocations, and `.pdata`/`.xdata` unwind relocations. The generated DLL
has nine PE sections, export and resource directories, exception data, console
subsystem selection, and no Microsoft CRT marker. The generated GUI image has
the Windows GUI subsystem plus the embedded manifest and resource. Every
artifact pair is byte-identical.

## Independence and resource boundaries

The audit record declares no Python, D, C compiler, TinyCC, assembler, or
external linker. Those tools were not invoked by artifact generation or the
acceptance gate. The OpenC child supervisor continues to enforce 256 MiB
private/job memory, 64 MiB working set, 4 MiB captured output, and bounded
execution. Compiler allocation and section budgets were not raised for SH-22.

## Final closure record

The final compiler comprises 217 OpenC source units and 1,902,603 source
bytes. Consecutive public self-builds produce the byte-identical 6,580,736-byte
compiler at SHA-256
`bd86520db0452478b953aaaebbea4218e919c0adbce4bf403de868d2a623c978`.
The 20-generation public chain closes exactly on every generation. Its
fully validating build median is 11.406 seconds and its semantic-validation
median is 5.677 seconds, below the unchanged 25-second and exclusive
15-second thresholds. Peak private memory is 170,627,072 bytes and peak
working set is 57,749,504 bytes, below the 256 MiB and 64 MiB ceilings.

The final required evidence passes 278/278 conformance fixtures, 5/5
maintained/runtime programs, 475/475 required repository paths, 39/39 pinned
hashes, 466/466 active rules, 174/174 grammar productions, the retained 16/16
PE audit, 42/42 framed LSP audit, 31/31 public contract audit, 9/9 daily
workflow, and 14/14 full workflow. `openc release` produces byte-identical
standalone and source ZIP pairs and verifies the relocated package through
self-build closure, daily workflow, contract, conformance, and the 40/40
PE/COFF ecosystem gate.

All benchmark build records declare no Python, D, C compiler, TinyCC,
assembler, or external linker. Measured children alone use a bounded high
priority class to prevent unrelated desktop scheduling from redefining the
wall-clock gate; normal `process.run`, public program execution, and emitted
OpenC applications retain the normal Windows priority class.

Linux and freestanding remain optional future targets. The 93 historical
rule-ID compatibility matches remain explicitly disclosed. SH-23 optional COM
and WinRT projection support is the next engineering milestone.
