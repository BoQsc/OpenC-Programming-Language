# OpenC authored implementation-source inventory

Evidence state: **SOURCE-COMPLETE BY INVENTORY — EXECUTION EVIDENCE RECORDED
SEPARATELY**

## Canonical compiler

Concrete D modules cover source loading, lexing, parsing, AST, modules, names,
types, constants, overloads, type checking, CFG and flow, `status`/`out`,
resources, ownership, borrowing, cleanup, pointer provenance, unsafe checking,
Core IR, D bootstrap generation, JSON IR, Native candidate declarations,
diagnostics, conformance adaptation, toolchain integration, and the unified
command driver.

## Informative bootstrap

A standard-library-only Python implementation covers the same principal
front-end and safety stages and emits deterministic C11 through a first-party
runtime. It remains informative and cannot override the D source or standard.

## Runtime

Concrete D runtime modules and C provider sources cover common values, checked
failures, bounds, numeric checks, UTF-8/text, memory, console, files, process
state, Linux, Windows, and freestanding hooks.

## Standard library

Concrete OpenC and D source exists for:

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
performance budgets, build scripts, test drivers, release scripts, schemas,
and source-completeness contracts are included.

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
