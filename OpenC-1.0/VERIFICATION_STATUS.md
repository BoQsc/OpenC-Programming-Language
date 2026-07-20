# OpenC 1.0 verification status

Date: 2026-07-20
Host: Windows 10.0.19045, x86_64

## Source receipt

- Original source archive SHA-256: `99fbd28310505fbab94d07ad995d38e9781def46e9b3cb31d4bd4f876be2d6a5`.
- The 897-member archive passed its internal SHA-256 manifest and path-safety checks before extraction.
- The completeness contract names 142 required files; none are missing or empty.
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
- Informative Python bootstrap tests: 4 of 4 passed; bytecode compilation and CLI help smoke tests also passed.
- Conformance fixtures: 268 of 268 passed with zero infrastructure failures.
- Runtime fixtures: all 35 built and executed to their expected exit/output or checked/target-fault contract.
- Maintained programs: all 4 checked, built, and executed to their authored exit/output contracts.
- Structure and source-completeness validators passed.

The conformance report identifies 93 successful historical-edition rule-ID compatibility matches and 175 native/exact matches. Compatibility is explicit because these fixtures retain OpenC 0.10 Draft identities while the compiler emits the Current/Core Candidate 2 diagnostic taxonomy.

## Reproduction commands

```text
python build/build_all.py --build debug --tools --compiler dmd
python build/build_all.py --build release --tools --compiler dmd
python tests/run_all.py
PYTHONPATH=compiler/bootstrap/python python -m unittest discover -s tests/python
compiler/openc validate --manifest=conformance/fixtures/MANIFEST.json
python tests/run_maintained.py
python scripts/validate_structure.py
python scripts/source_completeness.py
```

## Evidence boundary

This is a locally reproducible engineering conformance milestone for the complete authored executable manifest. It is not a claim of complete active-rule coverage, independent validation, native Linux behavior, freestanding behavior, or public release authorization.

Formal `RELEASE_READY` remains blocked by independent grammar, semantic, security, and usability reviews; native target verification selected by the release authority; and HD-012 licensing, governance, signing, and publication authority. Those decisions cannot be inferred from passing implementation tests.
