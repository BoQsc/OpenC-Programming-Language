# OpenC

OpenC is a new open systems language: C-shaped, not C-compatible; safe by default; explicit about unsafe memory; and designed around referenceable rules, strong diagnostics, deterministic tooling, and executable conformance.

This directory is the **single canonical development tree**.

## Source-complete handoff state

Concrete source is authored for:

```text
canonical D reference compiler
informative Python bootstrap compiler and C11 backend
Core/Hosted runtime
Linux, Windows, and freestanding providers
minimum Hosted standard library
unified compiler/tool driver
formatter
language server
rule explanation and context tools
conformance adapter and runner
local build, test, archive, and verification tools
authored test source and 268 conformance fixtures
maintained Core and Hosted acceptance programs
```

Nothing in this package is claimed as compiled, linked, executed, platform-verified, independently reviewed, release-ready, or published.

Start with:

```text
AUTHORITY.md
STATUS.md
SOURCE_COMPLETE_BUT_UNVERIFIED.md
standard/core/OpenC_Core_Current.md
compiler/IMPLEMENTATION_AUTHORITY.md
SOURCE_COMPLETENESS_CONTRACT.json
build/build_all.py
tests/run_all.py
release/LOCAL_BUILD_TEST_RELEASE_RUNBOOK.md
```

The optional design-history archive never overrides this tree.
