# OpenC reference compiler source

Status: **SOURCE-AUTHORED; NOT COMPILED OR EXECUTED**

This directory now contains concrete D source for the reference compiler:

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

The implementation is written against the OpenC 1.0 development standard and uses only D's standard library plus the first-party OpenC runtime and standard-library packages.

No compilation, unit test, conformance run, platform execution, or release claim is made in this package.
