# SH-21 OpenC-native PE audit tranche 4 evidence

Status: **PASS**.

## Boundary closed

The public OpenC-authored command

```text
openc pe-audit --input=FILE --output=REPORT.json
```

now owns the required first-party executable inspection that previously lived
in `scripts/verify_sh16_pe_runtime.py`. It reads the image as bounded bytes and
emits `openc.native_pe_audit.v1` JSON. The command invokes no Python, D, C,
TinyCC, Microsoft CRT, assembler, external linker, SDK header parser, or Windows
SDK tool.

This tranche audits OpenC's current Windows x86-64 Hosted executable contract.
It is not a claim that SH-22 COFF objects, DLLs, libraries, resources, or all
third-party PE variants are implemented.

## Native checks

The reader validates all of the following from PE structures rather than by
searching for strings:

- DOS and PE signatures, AMD64 machine, PE32+ optional header, subsystem,
  deterministic timestamp/checksum, and required dynamic-base/NX flags;
- the exact seven-section `.text`, `.rdata`, `.data`, `.pdata`, `.xdata`,
  `.tls`, `.reloc` layout, file/RVA bounds, alignment, and write-xor-execute;
- entry-point placement inside executable non-writable `.text`;
- the import descriptor and 64-bit thunk tables, one `KERNEL32.dll` provider,
  and all 28 expected documented symbols in canonical order;
- absence of UCRT, VCRuntime, MSVC++, MSVCRT, and every other non-allowlisted
  DLL as a consequence of the strict kernel32-only import rule;
- every relocation block and DIR64 entry, plus a valid TLS directory;
- every 12-byte `.pdata` runtime-function record, sorted non-overlapping text
  ranges, `.xdata` bounds, complete unwind-code storage, and version-one unwind
  headers without chained or handler data.

The fixed-point compiler report passes 16/16 checks and records:

```text
file bytes:          5,348,864
sections:            7
imports:             28
runtime functions:   1,337
DIR64 relocations:   4
subsystem:           3 (Windows console)
```

## Rejection evidence

Four independently corrupted copies were presented to the native command. All
returned a nonzero exit status and a `FAIL` report:

1. invalid DOS signature;
2. an out-of-file section size;
3. `MSVCRT.dll` substituted for the allowlisted DLL;
4. version 2 substituted for a referenced version-one unwind record.

The reports localized the failures to header, bounds/import/CRT, and
exception/unwind checks respectively.

## Closure, workflow, and resource evidence

The final 119-source, 1,679,762-byte compiler closes byte-exactly:

```text
Stage 2 SHA-256: 2a758dc5f8c70fa09e83bbd33ed69da90a456310e27b77860a849fc845f6f437
Stage 3 SHA-256: 2a758dc5f8c70fa09e83bbd33ed69da90a456310e27b77860a849fc845f6f437
```

Both closed images independently pass `openc pe-audit`. The native daily
workflow passes 6/6 tasks. The native full workflow passes 10/10 tasks,
278/278 conformance, 5/5 maintained/runtime programs, 4/4 adversarial process
guards, the 1,322-record repository audit, the new PE audit, two self-builds,
and exact fixed-point comparison. Its report records that no Python, D, C,
TinyCC, assembler, or external linker was invoked.

A copy renamed to `renamed-sh21-tranche4.exe` also passed the complete 6/6
daily workflow, proving that native self-location remains independent of the
historical `openc.exe` filename.

The measured PE audit completed in 0.161 seconds with 5,586,944 peak private
bytes and 9,789,440 peak working-set bytes. A fully validating compiler rebuild
completed in 14.526 seconds with 215,465,984 peak private bytes and 47,562,752
peak working-set bytes. These remain below the hard 25-second, 256 MiB private,
and 64 MiB working-set gates. The native daily workflow completed in 3.544
seconds with 16,977,920 peak private bytes and 8,134,656 peak working-set bytes.

## Remaining SH-21 work

The next engineering slice is the OpenC-native framed LSP client and transcript
audit. Native benchmark sampling/gates and deterministic release/archive
ownership follow it. Python copies remain optional external audit evidence until
those native replacements are individually proven.
