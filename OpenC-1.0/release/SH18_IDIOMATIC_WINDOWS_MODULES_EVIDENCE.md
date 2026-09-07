# SH-18 idiomatic Windows modules evidence

Status: PASS. Measured on Windows x86-64, 2026-09-07.

Twelve hand-authored OpenC modules cover foundation, file, memory, process,
thread, console, window, graphics, resources, network, registry, and shell.
Seven import their matching generated raw packages. The initial supported
interfaces and cleanup/lifetime rules are in `standard_library/WINDOWS_MODULES.md`.
This milestone is an initial systems API surface, not a complete Windows SDK
projection or application framework.

## Verified results

- Dedicated module verifier: 27/27. The compiled program prints Unicode text,
  converts UTF-8/UTF-16, round-trips a Unicode file path, allocates/resizes/frees
  heap memory, waits for a child exit code, signals/waits for an event, obtains
  desktop/GDI resources, loads a module, queries Winsock host name, opens the
  current-user registry, resolves Local AppData, and performs matching cleanup.
- Native conformance: 278/278; maintained programs: 4/4.
- Existing full Windows workflow: 15/15. The final integrated SH-18 workflow
  passes 16/16, including the dedicated module gate and 42 Python source tests.
- Five clean OpenC self-rebuilds: 9.498, 10.542, 7.488, 10.103, 12.219 seconds.
  Median 10.103 seconds; maximum 12.219 seconds. Pinned same-host D reference
  median 20.995 seconds; ratio 0.481. All absolute and relative gates pass.
- Every repeated compiler output and generated source is byte-identical.
- Module-private calls and passing const references to mutable-reference
  parameters remain rejected. These existing fixtures exposed regressions
  during implementation and passed after the call-validation fixes.

This measures the maintained compiler workloads on this host. It does not
establish universal C/D performance parity or a new runtime-performance claim.

## Reproduction

```text
python compiler/selfhost/bootstrap_windows_closure.py --stage1 build-output/native-toolchain/sh18-distribution/openc.exe --use-existing-stage1 --output build-output/selfhost-sh18/closure-regression-fix3
python scripts/verify_sh18_windows_modules.py --compiler build-output/selfhost-sh18/closure-regression-fix3/stage3/openc.exe --output build-output/selfhost-sh18/regression-fixed3/sh18-verification.json
python scripts/windows_native_workflow.py full --compiler build-output/native-toolchain/sh18-regression-fixed/openc.exe --output build-output/selfhost-sh18/full-workflow-sh18-final --force-conformance
python compiler/selfhost/benchmark_throughput_suite.py --compiler build-output/native-toolchain/sh18-regression-fixed/openc.exe --output build-output/selfhost-sh18/throughput-final.json --runs 5 --enforce
```

Stage-2 and Stage-3 executable SHA-256:
`0f7a345e5093a3f0d6b67d3dc088f1220f84adb5a238126d75df636852f40118`.
Normalized PE SHA-256:
`1539ca2739a1d865f4bbbd5d361da7d2b13d26a893c83b8e331057be811a99e7`.
Generated C SHA-256:
`a41c3a09f4963027bd306c4e17c21efeb20a4948ca1ccae45521cfd3780adf1e`.

The distribution includes runtime, standard library, compiler sources for
fingerprint verification, and canonical rule metadata for `openc explain`.
Machine-readable reports are under the paths above in `build-output`.

## Dependency boundary and next milestone

The SH-18 probe imports `kernel32.dll` and `msvcrt.dll`. Optional Windows
subsystems load through documented system-directory DLL loading. No UCRT,
vcruntime, or msvcp import is introduced. The general build still uses TinyCC,
generated C, and the C provider. SH-19 must replace those paths, compile the
whole OpenC compiler through the first-party backend, reproduce closure, and
retain conformance and throughput gates. The SH-16 direct-PE proof remains
CRT-free but is not the general compiler backend.

No D/DUB/Python process is required inside the native compiler build.
Python runs the external verification harness; D runs only the explicit
performance comparator. Required workflow replacement remains SH-20. The 93
historical rule-ID compatibility matches remain disclosed. Linux and
freestanding verification remain optional future work. No new release artifact
has been published by this milestone.
