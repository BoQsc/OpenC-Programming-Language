# OpenC authored implementation-source inventory

Evidence state: **SOURCE-COMPLETE BY INVENTORY — EXECUTION EVIDENCE RECORDED
SEPARATELY**

## Canonical compiler

The canonical OpenC compiler contains the complete native Windows frontend,
semantic/IR pipeline, deterministic C11 backend, conformance runner, and the
SH-9 public `check`, `run`, version, target, rule-explanation, and
human/machine diagnostic surface plus the SH-10 native formatter,
project-context inspector, and deterministic test runner, and the SH-11 native
stdio JSON-RPC lifecycle, synchronized diagnostics, and document formatter in
canonical `.p` source. SH-12 adds the bounded synchronized project workspace,
document symbols, typed hover, project navigation/references, deterministic
completion, and validated safe rename in canonical `.p` source. SH-13 adds
native phase timing records and indexed lowering lookups while keeping that
OpenC tree as the sole canonical compiler authority.

## Legacy bootstrap and comparison material

The earlier D implementation under `compiler/source/` and
standard-library-only Python implementation under
`compiler/bootstrap/python/` remain available for historical audit and
optional differential investigation. They cannot override the canonical
OpenC compiler or the standard, are not required by the native compiler, and
are excluded from the standalone distribution.

## Runtime

Legacy D runtime modules and current C provider sources cover common values, checked
failures, bounds, numeric checks, UTF-8/text, memory, console, files, process
state, Linux, Windows, and freestanding hooks.

## Standard library

Canonical OpenC provider source and legacy D source exist for:

```text
system.io
system.memory
system.file
system.path
system.process
system.text
```

## Tools

Concrete source exists for the unified `openc` driver, formatter, LSP,
explain, info, validation, executable runner, package
manifest/archive/verification tools, and classical/parenthesis command
normalization.

## Tests and conformance

Authored D and Python tests, 278 imported/current Core fixtures, four
maintained programs, six demo projects, native daily/full/release workflows,
performance budgets, the 12-case public native CLI verifier, the 21-case
native project-workflow verifier, the 19-case native language-service verifier,
the 23-case native semantic-language-service verifier, the 22-check SH-13
throughput/independence verifier, transcript schemas and session fixtures,
build scripts, test drivers, release scripts, schemas, and
source-completeness contracts are included.

## Machine-readable inventory

See:

```text
SOURCE_COMPLETENESS_CONTRACT.json
SOURCE_IMPLEMENTATION_INVENTORY.json
SOURCE_COMPLETENESS_REPORT.json
```

These records establish source presence only. They do not establish
compilation, execution, conformance, platform correctness, or release
readiness. Those claims require the separate executed evidence.
