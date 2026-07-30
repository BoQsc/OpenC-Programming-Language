# Legacy D bootstrap/reference compiler source

Status: **RETAINED HISTORICAL BOOTSTRAP AND COMPARISON MATERIAL**

This directory contains the earlier D source for the compiler:

```text
source management and diagnostics
UTF-8 lexer and Core parser
AST and module composition
symbols, types, constants, overloads and type checking
CFG and flow analysis
status/out proof tracking
resources and ownership
borrowing and cleanup
pointer provenance and unsafe checking
reference Core IR and lowering
D bootstrap and JSON-IR backends
Native candidate parser
compiler driver and conformance adapter
```

This implementation was written against the OpenC 1.0 standard and
uses D's standard library plus the first-party OpenC runtime and
standard-library packages. It is the stage-0 implementation for the separately
tracked compiler-in-OpenC self-hosting work.

Its historical build and conformance evidence remains recorded. It is not the
current compiler authority, is not required by native build or conformance,
and is not packaged in the standalone distribution. The canonical compiler is
the OpenC source under `compiler/selfhost/source/`.
