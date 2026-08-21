# SH-17 OpenC Win32 Metadata reader and raw projection evidence

Status: **PASS (2026-08-21)**

Scope: Windows x86-64 Hosted. Linux and freestanding remain optional future
targets and are not gates for this milestone.

## Outcome

SH-17 adds a purpose-built OpenC reader for the PE/CLI and ECMA-335 structures
needed by Win32 Metadata. It consumes the pinned real metadata image and emits
seven deterministic, checked-in raw OpenC modules:

```text
windows.raw.foundation
windows.raw.file
windows.raw.memory
windows.raw.process
windows.raw.thread
windows.raw.window
windows.raw.graphics
```

The generated source contains 71,425 selected exact records. It preserves
TypeRef/TypeDef, fields, method signatures, parameters, interface
implementations, DLL/import mappings, constants, class layout, field offsets,
and the custom attributes needed for architecture, Unicode/ANSI, arrays and
lengths, retained pointers, handle cleanup, invalid values, bitfields, sizes,
and documentation references.

This is a raw projection, not the SH-18 friendly API. Records use stable row
IDs plus exact lowercase-hex strings and signature/attribute blobs, so no C
declaration or preprocessor interpretation is involved.

## Pinned input

The exact acquisition contract is
`compiler/targets/windows-win32-metadata.json`:

```text
package:       Microsoft.Windows.SDK.Win32Metadata
version:       71.0.14-preview
package SHA:   d698e1d0e28d3b1fbdc36842092eb680d22ab147f4f61c6eb1eea59efbe60fa2
member:        Windows.Win32.winmd
member bytes:  24,355,840
member SHA:    b64ee4818a7ed9f9d135038d58c51bd08369184d4d5ed428f20e9de55df8121d
license:       MIT
license SHA:   0e97876eaa1fc79558e0d51dc0bee286d36dca8e95f7876259ffdf947396bca1
```

The input is projection-time material only. It is not a normal compilation or
runtime dependency. `scripts/acquire_sh17_winmd.py` downloads the exact NuGet
package and rejects any package, metadata member, size, or license hash drift.

## Real metadata observation

The OpenC reader reports the following real input shape:

```text
PE magic:          0x10b
metadata bytes:    24,354,248
#~ bytes:          10,456,972
#Strings bytes:     6,665,680
#Blob bytes:        7,231,468
#GUID bytes:               16
TypeRef rows:          16,516
TypeDef rows:          37,311
Field rows:           247,642
MethodDef rows:        70,707
Param rows:           219,381
CustomAttribute:      152,119
ImplMap rows:          18,321
```

Recognized attribute counts include 59,584 documentation, 14,877 supported-OS,
692 architecture, 3,023 ANSI, 2,852 Unicode, 5,347 native-array, 18 retained,
209 RAII-free, 398 invalid-handle-value, 2,747 native-bitfield, 2,582 memory-size,
and 464 structure-size-field records. All selected custom-attribute blobs are
also preserved exactly, including attributes outside the named counter set.

## Determinism and compiler closure

The final compiler contains 112 canonical OpenC compiler sources. Starting
from the disclosed one-generation raw-binary-read intrinsic bridge:

```text
Stage 2 compiler SHA-256: 027bd3258579bdac8aab5451cab13d1c1e4b5102b9fd1f15fb2907ac5df9a6b6
Stage 3 compiler SHA-256: 027bd3258579bdac8aab5451cab13d1c1e4b5102b9fd1f15fb2907ac5df9a6b6
generated C SHA-256:      350a5a29e2190fe3faf5c1c83cb4bce0fc5b09ca61935b396735382794d51ce5
```

Stage 2 and Stage 3 executables and generated C are byte-identical. Compiler
child builds execute no DMD, DUB, or Python. TinyCC remains the disclosed
general C backend until SH-19; it is not a metadata parser.

The enforced five-run clean self-rebuild median is 6.111 seconds with a
6.170-second maximum, versus the pinned same-host D median of 18.085 seconds
(0.338x). Peak private memory is 253,460,480 bytes and peak working set is
28,917,760 bytes. All five compiler and generated-C outputs are identical and
every SH-14 throughput/memory gate remains satisfied.

Two independent projections of the real pinned input took 156.402 and 162.180
seconds, both within the 240-second generator-only budget. Their seven source
files and manifest were byte-identical to each other and to the checked-in
projection. This offline regeneration time is not in `openc check` or `openc
build`: ordinary builds consume the generated `.p` files and never parse or
hash the WinMD.

## Commands and gates

```text
python scripts/acquire_sh17_winmd.py --output build-output/selfhost-sh17/input
python compiler/selfhost/bootstrap_sh17_binary_read_intrinsic.py --compiler build-output/selfhost-sh16/closure/stage4/openc.exe
python compiler/selfhost/bootstrap_windows_closure.py --stage1 build-output/selfhost-sh17/bootstrap-bridge/openc.exe --use-existing-stage1 --output build-output/selfhost-sh17/closure-final
python scripts/verify_sh17_winmd_projection.py --compiler build-output/selfhost-sh17/closure-final/stage3/openc.exe --input build-output/selfhost-sh17/input/Windows.Win32.winmd --regenerate --repeat 2 --output build-output/selfhost-sh17/final/sh17-verification.json
python scripts/windows_native_workflow.py full --compiler build-output/selfhost-sh17/closure-final/stage3-distribution/openc.exe --output build-output/selfhost-sh17/full-workflow-final --force-conformance
```

Final results:

```text
SH-17 projection verification: 30/30 PASS
native conformance:            278/278 PASS
maintained programs:               4/4 PASS
Python source tests:              42/42 PASS
full native workflow:             15/15 PASS
retained D seed executed:         false
C headers parsed:                 false
third-party metadata library:     false
ordinary build parses WinMD:      false
```

## Next milestone

SH-18 is active. It will layer hand-reviewed `windows.*` modules over this raw
projection, beginning with typed handles and exact cleanup, UTF-8/UTF-16
boundaries, slices, optionals, error results, and safer file/memory/process/
thread/console APIs. SH-19 remains the compiler-capable first-party backend and
TinyCC exit milestone.
