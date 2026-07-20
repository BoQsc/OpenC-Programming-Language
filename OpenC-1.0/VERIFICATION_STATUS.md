# OpenC 1.0 verification status

Date: 2026-07-20
Host: Windows 10.0.19045, x86_64

## Source receipt

- Original source archive SHA-256: `99fbd28310505fbab94d07ad995d38e9781def46e9b3cb31d4bd4f876be2d6a5`.
- The 897-member archive passed its internal SHA-256 manifest and path-safety checks before extraction.
- The completeness contract names 140 required files; none were missing or empty.
- The canonical structure includes 466 active Core rules and 174 grammar productions.

## Local toolchain

- DMD 2.112.0
- DUB 1.41.0
- DMD-bundled `lld-link`
- Python 3.13.7

No MSVC, Clang, or GCC C compiler was available on this host, so the standalone C runtime and platform-provider sources have not been compiled.

## Executed evidence

- Debug builds: 9 of 9 canonical D targets compiled and linked.
- Release builds: 9 of 9 canonical D targets compiled and linked.
- Authored D tests: 8 of 8 commands passed.
- Conformance fixtures: 268 executed; 29 passed, 203 failed, and 36 had infrastructure failures.
- Maintained programs: 0 of 4 accepted; none built or run.
- Python bootstrap: modules passed bytecode compilation and the CLI help smoke test; no authored Python test files were present.

The 36 conformance infrastructure failures consist of 35 runtime fixtures without build-and-run provider integration and one invalid-encoding fixture that currently fails during source loading. The remaining failures are implementation findings.

## Evidence boundary

This is a reproducible local verification baseline, not a conformance or release claim. OpenC 1.0 remains non-conforming, Linux- and freestanding-unverified, behaviorally unverified on Windows, independently unreviewed, and not release-ready.
