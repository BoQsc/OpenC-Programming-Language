# SH-23 optional COM and WinRT projection plan

Status: **PASS**

Target: Windows x86-64 Hosted. Linux and freestanding remain optional future
targets and are not gates.

## Required surface

- `windows.com`: packed 16-byte GUID values, signed `HRESULT` interpretation,
  apartment resources, `IUnknown` pointers, vtable-ordered `QueryInterface`,
  `AddRef`, and `Release`, plus ownership-preserving clone/destruction.
- `windows.winrt`: runtime apartment resources, UTF-8-to-UTF-16 `HSTRING`
  construction, deterministic destruction, `IActivationFactory` GUIDs,
  `RoGetActivationFactory`, runtime-instance activation, and `IInspectable`
  runtime-class/trust queries.
- optional Windows policy: no COM or WinRT concept enters Core, and ordinary
  binaries acquire no new static DLL dependency.
- native ownership: the compiler emits every Microsoft x64 call directly and
  uses its existing secure `LoadLibraryExW`/`GetProcAddress` boundary.

## Acceptance gates

The OpenC-native `com-winrt-audit` command must pass all 33 records in
`tests/SH23_COM_WINRT_AUDIT_PLAN.tsv`. It builds the projection test twice,
requires byte-identical PE32+ images, executes real COM and WinRT operations,
audits unwind/import/CRT properties, and checks the projection and metadata
contracts. Daily, full, contract, relocated-release, fixed-point,
conformance, throughput, and memory gates must remain green.

No required SH-23 command may invoke Python, D, C, TinyCC, an assembler, or an
external linker. The SDK and C headers are not build dependencies.
