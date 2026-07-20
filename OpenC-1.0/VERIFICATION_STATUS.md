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
- Conformance fixtures: 268 executed; 41 passed, 227 failed, and none had infrastructure failures.
- Runtime fixtures: 11 built and executed successfully; 24 remain rejected before code generation.
- Maintained programs: 0 of 4 accepted; none built or run.
- Python bootstrap: modules passed bytecode compilation and the CLI help smoke test; no authored Python test files were present.

Runtime fixture build-and-run integration is active. Invalid UTF-8 is now reported through the normative source diagnostic. Every remaining conformance failure is classified as an implementation finding rather than a harness infrastructure failure.

## Evidence boundary

This is a reproducible local verification baseline, not a conformance or release claim. OpenC 1.0 remains non-conforming, Linux- and freestanding-unverified, behaviorally unverified on Windows, independently unreviewed, and not release-ready.
