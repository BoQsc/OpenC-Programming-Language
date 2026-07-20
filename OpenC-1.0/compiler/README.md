
# OpenC compiler

The compiler source tree is intentionally separated from the language authority.

```text
source/     implementation work
bootstrap/  explicitly temporary bootstrap paths
backends/   target-independent and target-specific code generation
 targets/   target records and platform integration
 design/    authored implementation algorithms
 matrices/  rule and grammar work queues
```

The compiler must implement the current standard and report specification defects. It may not silently redefine OpenC.
