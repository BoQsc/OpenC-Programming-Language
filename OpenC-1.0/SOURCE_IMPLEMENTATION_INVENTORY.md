# OpenC authored implementation-source inventory

Evidence state: **SOURCE-COMPLETE BY INVENTORY — EXECUTION EVIDENCE RECORDED
SEPARATELY**

## Canonical compiler

The canonical OpenC compiler contains the complete native Windows frontend,
semantic/IR pipeline, OpenC-owned x64/PE32+ backend, conformance runner, and the
SH-9 public `check`, `run`, version, target, rule-explanation, and
human/machine diagnostic surface plus the SH-10 native formatter,
project-context inspector, and deterministic test runner, and the SH-11 native
stdio JSON-RPC lifecycle, synchronized diagnostics, and document formatter in
canonical `.p` source. SH-12 adds the bounded synchronized project workspace,
document symbols, typed hover, project navigation/references, deterministic
completion, and validated safe rename in canonical `.p` source. SH-13 adds
native phase timing records and indexed lowering lookups. SH-15 through SH-18
add the Windows x64 ABI/encoder, PE writer/runtime, WinMD reader/projection, and
friendly Windows modules. SH-19 makes the direct backend compiler-capable and
removes C, TinyCC, D, Python, an assembler, and an external linker from normal
compilation while keeping the OpenC tree as sole compiler authority.

## Legacy bootstrap and comparison material

The earlier D implementation under `compiler/source/` and
standard-library-only Python implementation under
`compiler/bootstrap/python/` remain available for historical audit and
optional differential investigation. They cannot override the canonical
OpenC compiler or the standard, are not required by the native compiler, and
are excluded from the standalone distribution.

## Runtime

The OpenC-owned CRT-free Windows runtime covers startup, checked failures,
UTF-8/text, process-heap memory, console, files, environment, process state,
and cleanup. Legacy D and C provider sources remain optional audit material;
Linux and freestanding hooks remain optional future targets.

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
the 23-case native semantic-language-service verifier, the SH-19 63-check
native-backend and 6-check memory-guard verifiers, transcript schemas and
session fixtures,
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
