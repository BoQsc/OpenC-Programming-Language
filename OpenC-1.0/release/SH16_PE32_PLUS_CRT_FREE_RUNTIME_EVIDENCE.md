# SH-16 PE32+ and CRT-free Windows runtime evidence

Status: **PASS**

Target: `windows-x86_64-hosted`

Compiler implementation: OpenC

Compiler source units: 107

Verification: 34/34 checks passed

SH-16 turns the SH-15 x64 machine-code substrate into a complete deterministic
PE32+ executable. The OpenC-authored compiler writes the image directly; the
proof-image path invokes no C compiler, C header parser, Microsoft CRT,
assembler, or external linker.

## Artifact and runtime proof

The 6,144-byte console proof image has SHA-256
`fcf01bf009bad01905cf1ed3ef3c14a1c2b137af1260d1c225e51ea7955b6d36`.
Two independent emissions, including their machine reports, are byte-identical.
Console and graphical subsystem selection differs only in the expected PE
subsystem field.

The verifier parses the image without an external PE library and checks:

- PE32+ AMD64 headers, deterministic zero timestamp/checksum, 512-byte file
  alignment, 4 KiB section alignment, and non-overlapping section ranges;
- `.text`, `.rdata`, `.data`, `.pdata`, `.xdata`, `.tls`, and `.reloc` with
  appropriate executable, writable, and non-executable protections;
- dynamic-base, NX-compatible, and high-entropy-VA characteristics;
- import, IAT, exception, TLS, and base-relocation directories;
- four `IMAGE_REL_BASED_DIR64` relocations, two sorted runtime-function
  records, and version-one x64 unwind information;
- an active TLS directory; and
- a single imported DLL, `KERNEL32.dll`, with 15 sorted documented functions.

The executable runs with a Unicode argument containing Cyrillic and a non-BMP
character, converts the Windows UTF-16 command line to UTF-8, initializes and
uses the process heap, allocates/reallocates/frees memory, acquires/releases
the environment block, writes and reopens a file, reads its exact payload,
prints UTF-8 output, runs normal cleanup, and exits through `ExitProcess`.
The standalone panic path writes a diagnostic and exits with status 70.

The import audit rejects Microsoft CRT families. The observed image imports no
`ucrtbase.dll`, `vcruntime*.dll`, `msvcp*.dll`, or `msvcrt.dll`.

## Compiler closure and correctness

Stage 3 and Stage 4 are byte-identical:

- compiler SHA-256:
  `590c54823693af5f115d123555225ab0ad5e8863d25ee7da21824d6969c475dd`;
- generated C SHA-256:
  `2557a5a967e9cee26b1bf32b5bc5ff47ced6a5da69b21f5c9ac1ae9f8708b84b`;
- native conformance: 278/278;
- maintained programs: 4/4;
- Python source tests: 38/38; and
- full Windows-native workflow: 14/14, with the SH-16 executable verifier a
  mandatory task and no retained D seed executed.

## Throughput regression gate

Five clean compiler rebuilds pass every existing SH-14 budget:

| Measurement | SH-16 result | Gate |
| --- | ---: | ---: |
| OpenC clean median | 6.665 s | <= 30 s |
| OpenC clean maximum | 7.302 s | <= 45 s |
| Pinned D clean median | 18.304 s | reference |
| OpenC/D median ratio | 0.364x | <= 1.25x |
| Peak private bytes | 220,303,360 | <= 268,435,456 |
| Peak working-set bytes | 26,693,632 | <= 33,554,432 |

The five OpenC outputs and generated sources are byte-identical. SH-14's best
4.137-second baseline remains recorded; SH-16 does not weaken a budget.

## Bootstrap and dependency boundary

Adding the arbitrary-binary file intrinsic required a one-generation bridge
because the SH-15 compiler inferred that new intrinsic's result temporary as
`void`. `compiler/selfhost/bootstrap_sh16_binary_intrinsic.py` performs one
checked transformation in generated bootstrap C, builds the first SH-16
compiler through the already disclosed vendored TinyCC path, and records the
temporary and hashes. The resulting OpenC compiler then builds Stage 3 and
Stage 4 without that bridge. The bridge is neither a normal build dependency
nor a runtime dependency; it invokes no D compiler or assembler.

The scope boundary remains explicit: the SH-16 direct PE path accepts the
bounded runtime-proof source profile. Arbitrary compiler-reachable Core IR is
not yet lowered by the native backend. General compiler builds still use the
generated-C/vendored-TinyCC backend until SH-19. Python remains external
evidence orchestration until SH-20. Linux and freestanding are not SH-16 gates.

## Reproduction

```text
python scripts/verify_sh16_pe_runtime.py --compiler build-output/selfhost-sh16/closure/stage4/openc.exe --output build-output/selfhost-sh16/final/sh16-verification.json
python compiler/selfhost/benchmark_throughput_suite.py --compiler build-output/selfhost-sh16/closure/stage4/openc.exe --runs 5 --enforce --output build-output/selfhost-sh16/final/throughput-suite.json
python scripts/windows_native_workflow.py full --compiler build-output/selfhost-sh16/closure/stage4-distribution/openc.exe --output build-output/selfhost-sh16/full-workflow-final --force-conformance
python -m unittest discover -s tests/python -p test_*.py
```

Primary machine records are under `build-output/selfhost-sh16/`. Generated
build output is local evidence and is intentionally not source-controlled.

## Next milestone

SH-17 is active: implement a purpose-built OpenC ECMA-335/Win32 Metadata reader
for a pinned `Windows.Win32.winmd`, then generate deterministic exact
`windows.raw.*` declarations without parsing C headers or using a third-party
metadata library.
