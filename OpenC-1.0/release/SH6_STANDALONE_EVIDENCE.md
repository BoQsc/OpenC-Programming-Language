# SH-6 standalone self-hosted release evidence

Status: **PASS**

Target: Windows x86-64 Hosted

Date: 2026-07-26

## Contract and result

The deterministic standalone distribution contains the OpenC-native compiler,
complete canonical source, supported Windows runtime/library inputs, the
shipped TinyCC backend and corresponding source, the retained D audit seed,
licenses, release metadata, and an internal SHA-256 manifest.

Two independently built archives are byte-identical. After extraction into a
clean tree, the compiler is executed from a foreign working directory. It
locates its runtime, native shim, and backend relative to its executable,
builds Stage 2 from the canonical `.p` compiler project, and Stage 2 builds
Stage 3. DMD, DUB, and Python are unavailable to both native builds.

The extracted distribution passes native semantic/IR parity, the complete
268-fixture conformance manifest, and all 4 maintained programs.

## Final evidence

```text
standalone archive SHA-256:
6adf2254263cc11ae8a2f31ee883923021397942237ffb6fd64f0742a1b0eaac

package manifest entries:
1140

packaged compiler / Stage 2 / Stage 3 SHA-256:
c2a26a1d286354f4e4b5ed2192e9008a5fffb2a667c4e4b9ba3f4a4afc76ed75

generated C SHA-256:
5851bde4caebb5cb4142966ce650db51ccf55983e1a3888e15ff0cd573c3a966

normalized Stage 2 / Stage 3 PE SHA-256:
cb8c75fc9e364608d61cdb062c58180f8899b99c7f1fb9396b9c8f2c1ff4b8e8

retained bootstrap seed SHA-256:
ac10fad15aa032d22ac56a632e9977477bdd8c87f56c9924a21a231a64dfafcf

TinyCC executable SHA-256:
e9cb3e89e20a9efead83cc9e6b100314275634c2f705056da71f424ea9b0cdf0
```

Native semantic/IR parity covers 263 authored source fixtures: 117 exact IR
comparisons, 149 exact semantic rejections, 183 functions, 275 blocks, 1,489
instructions, and all 33 reachable opcodes. Packaged conformance is 268/268
with zero failures. Maintained-program execution is 4/4 with exact exit codes
and stdout.

The machine-readable result is
`build-output/selfhost-sh6/final/standalone-release-result.json`. The two final
archives are:

```text
build-output/release/OpenC-1.0.0-rc.8-windows-x86_64-standalone-a.zip
build-output/release/OpenC-1.0.0-rc.8-windows-x86_64-standalone-b.zip
```

## Reproduction

Build the package twice with identical inputs:

```text
python release/build_standalone_windows.py --tree . --compiler COMPILER --bootstrap-seed compiler/openc.exe --version 1.0.0-rc.8 --output-tree OUTPUT_TREE --archive OUTPUT_ZIP --force
```

Verify the two archives:

```text
python release/verify_standalone_windows.py --archive build-output/release/OpenC-1.0.0-rc.8-windows-x86_64-standalone-a.zip --comparison-archive build-output/release/OpenC-1.0.0-rc.8-windows-x86_64-standalone-b.zip --output build-output/selfhost-sh6/final --force
```

## Scope and component roles

- `openc.exe` is the compiler under test and is written in OpenC.
- The six supported system modules are compiler-provided and backed by the
  packaged Windows C runtime and compiler native shim.
- `bootstrap/openc-stage0.exe` is the retained D audit/conformance seed. Native
  `openc build` does not invoke it.
- Python is an external evidence orchestrator. Native `openc build` and its
  TinyCC child do not invoke Python.
- Authored Native-provider `.p` sources are packaged but outside the supported
  Windows Hosted gate.
- Linux and freestanding are optional future targets and do not gate SH-6.

## Post-SH-6 work

The next release work is the explicit owner publication act and immutable
release/tag/hash record. Detached signing is optional until the owner
establishes a public signing key. Engineering then focuses on native
self-rebuild time and peak-memory reduction without weakening closure checks,
followed by the disclosed fixture/evidence and independent-review backlog.
