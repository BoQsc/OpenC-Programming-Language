# SH-23 optional COM and WinRT completion evidence

Status: **PASS**

SH-23 adds the optional `windows.com` and `windows.winrt` modules without
changing OpenC Core or the static import surface of ordinary binaries.

The native acceptance executable performs real Windows operations:

- initializes and uninitializes COM and WinRT apartments;
- creates an in-memory COM stream;
- calls the first three `IUnknown` vtable slots in ABI order;
- verifies `QueryInterface`, balanced reference counting, and owned cleanup;
- converts an OpenC UTF-8 class name to an `HSTRING`;
- obtains and releases an `IActivationFactory` for
  `Windows.Globalization.Calendar`;
- activates a real runtime instance and calls its `IInspectable`
  `GetRuntimeClassName` and `GetTrustLevel` slots.

`openc com-winrt-audit` passes 33/33 checks. Two native builds are
byte-identical. The PE32+ image has valid x64 unwind data, contains no CRT
imports, and statically imports only `KERNEL32.dll`. `ole32.dll` and
`combase.dll` are resolved only through the secure system-directory loader;
there are no C headers, direct syscalls, SDK build dependencies, or external
build tools.

The existing Win32 Metadata projection supplies the ECMA-335 interface and
signature backing. Checked-in COM and WinRT manifests record the idiomatic
projection decisions, while ordinary builds consume `.p` sources and never
parse metadata.

The final 219-source compiler is 6,767,616 bytes and reaches a byte-identical
fixed point at
`33554c3701d63caea0c708c94c34d955904a5d8a12f7fe238cec028b126a8d3f`.
The full workflow passes 15/15, including 278/278 conformance, 34/34 residual
contracts, 487/487 required repository paths, 39/39 pinned hashes, and 20/20
exact chained rebuilds. Build/validation medians are 15.063/7.729 seconds;
private/working-set peaks are 172,986,368/57,532,416 bytes.

The OpenC-native release proof passes with byte-identical 1,424-file
standalone archives and 1,714-file source archives. The extracted package
reaches the same compiler hash, reruns the 33/33 COM/WinRT audit, and passes
278/278 conformance without Python, D, C, TinyCC, an assembler, or an external
linker.

Final closure, workflow, benchmark, conformance, repository-audit, and
relocated-release measurements are recorded in
`compiler/selfhost/SELF_HOSTING_STATE.json` and `VERIFICATION_STATUS.md`.
