# SH-22 PE/COFF ecosystem completeness

Status: **IMPLEMENTED; FINAL RELEASE GATES IN PROGRESS**.

SH-22 extends the OpenC-owned Windows x86-64 backend from complete direct
PE32+ executables to the normal Windows binary ecosystem. The implementation
remains in OpenC and does not invoke Python, D, TinyCC, a C compiler, an
assembler, or an external linker.

## Delivered compiler surface

The public compiler command is:

```text
openc artifact --project=PROJECT --kind=KIND --output=FILE
  [--subsystem=console|windows]
  [--manifest=FILE] [--resource=FILE]
  [--dll-name=NAME] [--report=REPORT.json]
```

Supported artifact kinds are `exe`, `coff-object`, `dll`, `static-library`,
and `import-library`. The writers provide:

- AMD64 COFF objects with `.text`, `.rdata`, `.data`, `.pdata`, and `.xdata`;
- `REL32` code relocations and `ADDR32NB` unwind relocations;
- deterministic COFF archives and Microsoft short-import objects;
- PE32+ DLL images, deterministic export directories, and DLL initialization;
- manifest and `RCDATA` resource trees;
- console and Windows GUI subsystem selection;
- documented secure run-time linking through `LoadLibraryExW`,
  `GetProcAddress`, and `FreeLibrary`;
- C-ABI export names and import-library symbols without C source or headers.

The raw artifact layer is a general backend component. Windows handle policy,
UTF conversion, typed ownership, and safer APIs remain in the optional
`windows.*` standard-library modules. `windows.resources` now provides
absolute-path loading and symbol resolution in addition to System32-only
loading.

## Required acceptance gate

```text
openc pe-coff-audit --root=ROOT --artifacts=DIR --output=REPORT.json
```

The OpenC-native audit performs 40 checks. It creates every artifact twice,
requires byte determinism, validates COFF sections/symbols/relocations and
archives, validates PE32+ DLL/export/resource/unwind/subsystem fields, rejects
CRT marker imports, and exercises both interoperability directions:

1. a generated PE imports `openc_add` from the OpenC DLL at load time and must
   exit with code 42;
2. the OpenC compiler securely loads the DLL by absolute path, resolves
   `openc_add`, calls it using the Microsoft x64 ABI, and must receive 42.

All child processes remain under the SH-21 256 MiB private/job, 64 MiB working
set, 4 MiB captured-output, and timeout guards. Compiler allocation budgets
remain unchanged: 512 MiB live allocations, 256 MiB per allocation, and the
existing per-phase native section limits.

## Completion gates

SH-22 closes only when all of the following pass from the final source tree:

- 40/40 native PE/COFF ecosystem audit;
- 31/31 native CLI and Windows-module contracts;
- 9/9 daily and 14/14 full native workflows;
- 278/278 conformance;
- 20/20 exact native rebuild benchmark under unchanged RAM limits;
- Stage-2/Stage-3 byte-exact fixed point;
- deterministic source and standalone archives with relocated verification.

Linux and freestanding remain optional future targets and are not an SH-22
gate. The 93 historical rule-ID compatibility matches remain explicitly
disclosed. SH-23 optional COM and WinRT projection work follows SH-22.
