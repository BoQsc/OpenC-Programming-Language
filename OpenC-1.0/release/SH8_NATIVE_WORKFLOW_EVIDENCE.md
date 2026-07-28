# SH-8 native developer and release workflow evidence

Status: **PASS**  
Required target: **Windows x86-64 Hosted**

SH-8 makes the verified OpenC-native compiler the default
compiler-under-test for ordinary Windows development and release work. The
retained D compiler remains separately invocable through `audit-seed`; it is
not executed by the required daily, full, or release workflows.

## Native toolchain

Install a closed standalone distribution once:

```text
python scripts/native_toolchain.py install --distribution PATH/TO/DISTRIBUTION
python scripts/native_toolchain.py status
```

The resolver requires `openc.exe.build.json` to record the
`c11-tinycc-win64` backend, `PASS`, and false values for DMD, DUB, and Python
invocation. It also requires the runtime, native shim, and vendored TinyCC
beside the compiler. The installed compiler source fingerprint must equal the
exact current compiler/library/runtime/backend input fingerprint.

The SH-8 reference compiler is:

```text
SHA-256  9b59bb94d516a50285fe3d0c882ef47c1977ad570cb6b041c9f251c39f0a1ab2
source   91 canonical compiler .p files
```

## Native daily workflow

```text
python scripts/windows_native_workflow.py daily
```

The first reference run executed 278/278 native conformance fixtures in
30.598 seconds. An identical-input second run reused the exact report in
0.001 seconds and executed zero fixtures. The cache key covers the compiler,
complete fixture tree, Windows runtime, native runtime, and TinyCC bytes.
Changed bytes invalidate the entry. Full and release workflows never use the
cache.

Every daily run still executes structure, source completeness, coverage, all
10 Python source tests, all 4 maintained programs, and all 6 demo projects.
The compiler-under-test for maintained programs and demos is the native
OpenC compiler.

## Regression budgets

Budgets are authored in
`compiler/selfhost/WINDOWS_NATIVE_BUDGETS.json`.

| Path | Measured baseline | Required ceiling |
| --- | ---: | ---: |
| complete 278-fixture validation | 35.489 s | 50.0 s |
| validation peak private memory | 6,414,336 bytes | 16,777,216 bytes |
| validation peak working set | 8,372,224 bytes | 16,777,216 bytes |
| native compiler self-rebuild | 494.985 s | 620.0 s |
| rebuild peak private memory | 175,722,496 bytes | 268,435,456 bytes |
| rebuild peak working set | 12,238,848 bytes | 33,554,432 bytes |
| unchanged conformance cache lookup | 0.001 s, 0 fixtures | 2.0 s, 0 fixtures |

The budgeted validation rerun passed 278/278 in 39.754 seconds. The measured
self-rebuild produced an executable byte-identical to its native input at
SHA-256
`9b59bb94d516a50285fe3d0c882ef47c1977ad570cb6b041c9f251c39f0a1ab2`;
its generated C is
`124f7a42356fd468fa2c0b244c0580bcdca3345b3937e4f1d8d3139a800a7fbb`.

Run both budgeted paths with:

```text
python scripts/windows_native_workflow.py full
```

## Native release workflow

```text
python release/windows_native_release.py --force
```

The command resolves the verified native compiler by default, builds two
deterministic standalone archives, and runs the relocated packaged
Stage-2/Stage-3, 278-fixture, and 4-program verifier. It does not pass
`--audit-seed`. Exact package hashes are written outside the authored source
snapshot to
`build-output/selfhost-sh8/release/native-release-workflow-result.json`.

The optional D comparison is explicit and separate:

```text
python scripts/windows_native_workflow.py audit-seed
```

## Result

SH-8 is complete:

- native OpenC is the default Windows compiler-under-test;
- validation and rebuild time/memory regressions have enforceable budgets;
- unchanged daily validation avoids all 278 redundant fixture executions;
- full and release evidence force fresh native validation;
- the D oracle is optional and absent from required execution;
- Linux and freestanding remain optional future targets.

## Next engineering milestone

SH-9 is native CLI and diagnostic usability:

1. add public native `openc check` and `openc run` workflows;
2. provide concise human diagnostics alongside stable machine records;
3. expose native version, target, and rule-explanation commands;
4. make the demo projects directly usable through that public CLI.

Independent review remains welcome and nonblocking.
