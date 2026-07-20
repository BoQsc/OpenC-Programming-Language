# OpenC reference compiler source

Status: **WINDOWS X86-64 DEBUG/RELEASE BUILD, TEST, AND CONFORMANCE PASS**

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

The bootstrap implementation is written against the OpenC 1.0 standard and
uses D's standard library plus the first-party OpenC runtime and
standard-library packages. It is the stage-0 implementation for the separately
tracked compiler-in-OpenC self-hosting work.

The owner-certified Windows x86-64 Hosted source candidate builds in debug and
release modes and passes the recorded unit, conformance, runtime, and maintained
program gates. It still emits D source for executable builds and therefore is
not yet a DMD-independent or self-hosted compiler.
