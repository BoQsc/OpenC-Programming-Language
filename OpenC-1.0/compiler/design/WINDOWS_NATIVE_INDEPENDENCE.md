# Windows native independence architecture

Status: **ACTIVE; SH-16 PASSED, SH-17 ACTIVE**

OpenC's Windows path must preserve a strict separation:

```text
OpenC language and typed Core IR
    -> Windows x64 target and machine-code encoder
    -> PE32+ / COFF artifact writers
    -> generated Win32 raw bindings
    -> small idiomatic OpenC Windows modules
    -> documented Windows system DLL APIs
```

OpenC is not a C dialect, does not copy Windows C headers into the language,
and does not place `HANDLE`, `DWORD`, `HWND`, COM, or WinRT concepts in Core.
C ABI interoperability remains valuable, but C headers, the C standard
library, the Microsoft CRT, and a C compiler are not permanent requirements.

## Dependency boundary

The intended final normal-development loop is:

```text
OpenC source -> OpenC compiler -> OpenC runtime/tooling -> Windows binaries
```

A pinned prior OpenC compiler or one isolated historical bootstrap route may
be retained solely to create the first compiler binary from a source-only
environment. It must not participate in ordinary builds, tests, conformance,
package verification, or releases.

| Component | Current role | Exit condition |
| --- | --- | --- |
| TinyCC | required C compile/link backend | SH-19 self-hosts through the first-party x64/PE backend |
| Python | external evidence orchestration | SH-20 replaces required workflows with OpenC-native tools |
| D | historical bootstrap/audit material | SH-20 isolates it to an optional first-binary bootstrap lane |
| C runtime/shim | still used by the general generated-C backend; absent from the SH-16 direct-PE proof | SH-19 moves all compiler-reachable native paths to the OpenC runtime |
| Windows SDK | optional verification oracle | never a normal build or runtime dependency |

## SH-15: Windows x64 ABI and machine-code substrate

Status: **PASS**. The canonical target record carries the Microsoft x64/LLP64
contract, and 104 OpenC compiler source units now include the typed encoder,
relocations, ABI classifier/layout engine, unwind generator, and deterministic
probe emitter. The executable verifier passes 25/25 checks, including integer,
floating, aggregate, callback, variadic, stack-alignment, nonvolatile-register,
layout, relocation, and registered-unwind observations. Evidence is in
`release/SH15_WINDOWS_X64_ABI_MACHINE_CODE_EVIDENCE.md`.

The target record must encode Microsoft's x64 ABI, including:

- integer/pointer arguments in `RCX`, `RDX`, `R8`, and `R9`;
- floating arguments in the positional `XMM0` through `XMM3` registers;
- caller-provided 32-byte shadow space;
- 16-byte stack alignment outside prologs, epilogs, and leaf exceptions;
- volatile and nonvolatile integer/vector registers;
- scalar, aggregate, hidden-pointer, and return-value classification;
- varargs duplication rules and stack arguments;
- callback and function-pointer calls;
- natural structure alignment, explicit layout, unions, and bitfields;
- Windows LLP64 data layout: pointers are 64-bit while `int` and `long`-class
  Windows values remain 32-bit;
- `.pdata`/`.xdata` unwind descriptions for every non-leaf function.

The language-facing facility should be a general target ABI declaration,
consistent with OpenC's existing external-function model, for example a future
form such as `external(windows, "CreateFileW")`. Exact syntax requires an
accepted language/tooling change. Windows names and types belong in libraries,
not in the Core grammar or primitive type system.

The backend begins with a typed x64 instruction encoder, register/stack
assignment, relocations, and deterministic byte emission. A general-purpose
text assembler is not an initial dependency. A small OpenC assembler may be
added later if hand-authored startup, intrinsics, or interoperability tests
demonstrate a real need; it should reuse the same instruction encoder rather
than become a second code generator.

SH-15 passes with ABI probes for scalars, floats, aggregates, callbacks,
variadics, stack alignment, nonvolatile preservation, layout, and unwindable
non-leaf calls. Microsoft-produced objects or SDK probes may act as test
oracles but are not shipped dependencies.

## SH-16: minimal PE32+ executable and OpenC runtime

Status: **PASS**. The canonical 107-source OpenC compiler writes a complete
deterministic PE32+ image directly. The dedicated parser/execution verifier
passes 34/34 checks. Evidence is in
`release/SH16_PE32_PLUS_CRT_FREE_RUNTIME_EVIDENCE.md`.

Implement a deterministic PE32+ image writer with the minimum complete set:

- DOS/PE/COFF and optional headers;
- `.text`, read-only data, writable data, import tables, and base relocations;
- console and graphical subsystem selection;
- documented system-DLL imports and an explicit OpenC entry point;
- `.pdata` and `.xdata` for non-leaf x64 code;
- deterministic section/RVA layout and reproducible timestamps/checksums.

The first OpenC-owned runtime supplies:

- executable entry and exit;
- global/static initialization and normal cleanup;
- UTF-16 command-line decoding into OpenC UTF-8 text;
- environment access;
- allocator initialization using `GetProcessHeap`, `HeapAlloc`,
  `HeapReAlloc`, and `HeapFree`;
- panic/crash reporting;
- the initial thread-local-storage contract.

The completed blocking proof is one OpenC source program compiled by OpenC to a
self-contained PE32+ executable that imports only documented Windows system
DLLs, prints UTF-8 text, allocates/reallocates/frees memory, and reads/writes a
file. It uses no C headers, C compiler, Microsoft CRT, external assembler, or
external linker. The import audit rejects `ucrtbase.dll`, `vcruntime*.dll`,
`msvcp*.dll`, and `msvcrt.dll`.

The proof image is 6,144 bytes and imports only 15 functions from
`KERNEL32.dll`. It contains deterministic `.text`, `.rdata`, `.data`,
`.pdata`, `.xdata`, `.tls`, and `.reloc` sections, active TLS, version-one x64
unwind records, `DIR64` relocations, and ASLR/NX/high-entropy flags. It executes
Unicode-to-UTF-8 command-line conversion, environment access, process-heap
allocation, file write/read, normal cleanup, and the panic path. Console and
GUI subsystem selection are both verified.

The direct backend is intentionally bounded to the SH-16 runtime-proof source
profile. General compiler-reachable Core IR lowering remains SH-19 work, so
ordinary compiler builds still use the disclosed generated-C/TinyCC route.
This boundary prevents the milestone from implying that TinyCC has already
left the normal toolchain.

## SH-17: purpose-built Win32 Metadata reader and raw projection

Status: **ACTIVE**.

Write the reader in OpenC. It consumes a pinned, checksummed
`Windows.Win32.winmd` and implements only the ECMA-335 PE/CLI metadata streams,
tables, signatures, coded indexes, and custom attributes needed by the Win32
projection. It is not a general .NET runtime or IL executor.

The reader and generator must preserve:

- source DLL and export symbol;
- calling convention and architecture restrictions;
- `GetLastError` behavior;
- input, output, optional, pointer, and array/length relationships;
- ANSI/Unicode variants;
- asynchronous pointer-retention requirements;
- typed handles, cleanup functions, and invalid values;
- enums, constants, explicit unions, bitfields, packing, and field offsets;
- documentation identifiers/references present in the metadata.

Normal compilation never parses C preprocessor headers and does not parse the
entire `.winmd` on every build. The generator produces versioned deterministic
OpenC `.p` source under raw modules such as:

```text
windows.raw.foundation
windows.raw.file
windows.raw.memory
windows.raw.process
windows.raw.thread
windows.raw.window
windows.raw.graphics
```

Generated-source manifests record the metadata version/hash, generator
version/hash, architecture filter, declarations, and output hashes.

## SH-18: idiomatic Windows modules

Hand-reviewed OpenC modules wrap, but do not replace or distort, the raw
projection:

```text
windows.file
windows.memory
windows.process
windows.thread
windows.window
windows.graphics
```

The friendly layer provides typed handles, scope cleanup, slices instead of
pointer/length pairs, initialized size/version fields, explicit optional
parameters, OpenC status/error results, and safer defaults. Cleanup metadata
maps each owned resource to the correct release operation, such as
`CloseHandle`, `DeleteObject`, or `HeapDestroy`; resources are never all
treated as one interchangeable handle type.

OpenC text remains UTF-8. Friendly APIs use Unicode `W` entry points and make
temporary, lifetime-bounded UTF-16 conversions at the Windows boundary. Raw
modules may retain both `A` and `W` declarations for exactness, but friendly
modules do not silently depend on the active ANSI code page.

SH-18 covers files, memory, processes, threads, console I/O, error capture,
and cleanup first; windowing, graphics, resources, sockets, registry, and shell
modules follow under the same raw/friendly separation.

## SH-19: compiler-capable first-party backend and TinyCC exit

Expand the x64/PE backend until it compiles the complete canonical OpenC
compiler and runtime. Required gates are:

- all reachable Core IR operations lower through first-party code;
- compiler -> Stage 2 -> Stage 3 reaches byte-identical closure;
- 278/278 conformance and 4/4 maintained programs pass;
- exceptions, stack walking, callbacks, imports, relocations, and TLS pass;
- the standalone package contains no TinyCC binary, C headers, generated C,
  C runtime, external assembler, or external linker;
- the legacy C/TinyCC backend remains optional for differential audit only.

Direct complete PE emission is the first supported artifact path. It keeps the
initial linker scope bounded and proves independence sooner.

## SH-20: OpenC-native build, test, release, and bootstrap boundary

Rewrite every required Python evidence/release orchestrator in OpenC or move
its indispensable logic into the compiler. The OpenC-native workflow must
build, test, benchmark, validate, package, hash, inspect PE imports/unwind
data, and reproduce archives without Python or D.

A clean normal release environment contains only the pinned previous OpenC
compiler and project source. D and Python may be retained in a separately
named historical bootstrap/audit kit, but required workflows must prove they
were unavailable and not invoked. This is the point at which OpenC no longer
needs TinyCC, Python, D, C headers, a C compiler, a C runtime, an assembler, or
an external linker for ordinary Windows development.

## SH-21: PE/COFF ecosystem completeness

After direct executable closure is stable, add:

- COFF `.obj` files and relocations;
- OpenC DLL imports and exports;
- Windows DLL generation and initialization rules;
- static and import libraries;
- resources and application manifests;
- console and GUI subsystem completeness;
- load-time imports plus secure run-time linking with `LoadLibraryExW` and
  `GetProcAddress`;
- optional C-ABI libraries in both directions without requiring C source or
  headers.

The PE/COFF and ABI layers remain general compiler components; Win32 policy
remains in the Windows libraries.

## SH-22 and later: COM, WinRT, editor, and ARM64

SH-22 adds optional `windows.com` and `windows.winrt` projections: GUIDs,
interface pointers/vtables, `IUnknown`, `QueryInterface`, reference counting,
`HRESULT`, apartment initialization, metadata projection, and ordering tests.
They do not complicate SH-15 through SH-20.

SH-23 contains the deferred native editor integration and language-service
resilience work. ARM64 begins only after the x64 ABI, backend, runtime, raw
bindings, and release loop are stable and independent.

## Verification policy

Every raw-binding or native-backend release automatically checks:

- structure size/alignment, field/union/bitfield offsets, and constants;
- scalar, aggregate, variadic, callback, and function-pointer calls;
- imported DLL/symbol names and `GetLastError` capture timing;
- handle invalid values, ownership transfer, and exact cleanup function;
- UTF-8/UTF-16 conversion, embedded NUL, invalid text, and lifetime behavior;
- PE sections, protections, imports/exports, relocations, TLS, resources, and
  subsystem flags;
- sorted x64 runtime-function records and valid unwind behavior;
- deterministic bytes and absence of unintended CRT/toolchain imports;
- differential SDK-oracle results without making the SDK a build dependency.

Documented system DLL APIs are the normal Windows boundary. Direct Windows
syscalls and undocumented exports are forbidden in the supported backend; any
future experiment must live in an explicitly unsupported low-level module.

## Authoritative references

- Microsoft x64 calling convention:
  https://learn.microsoft.com/en-us/cpp/build/x64-calling-convention
- Microsoft x64 ABI conventions:
  https://learn.microsoft.com/en-us/cpp/build/x64-software-conventions
- Windows LLP64 model:
  https://learn.microsoft.com/en-us/windows/win32/winprog64/abstract-data-models
- Microsoft PE/COFF format:
  https://learn.microsoft.com/en-us/windows/win32/debug/pe-format
- Microsoft x64 exception/unwind format:
  https://learn.microsoft.com/en-us/cpp/build/exception-handling-x64
- Microsoft Win32 Metadata project:
  https://github.com/microsoft/win32metadata
- ECMA-335 CLI metadata format:
  https://ecma-international.org/publications-and-standards/standards/ecma-335/
- Windows UTF-8/UTF-16 boundary guidance:
  https://learn.microsoft.com/en-us/windows/apps/design/globalizing/use-utf8-code-page
- Windows allocation-method comparison:
  https://learn.microsoft.com/en-us/windows/win32/memory/comparing-memory-allocation-methods
- Windows run-time dynamic linking:
  https://learn.microsoft.com/en-us/windows/win32/dlls/run-time-dynamic-linking
