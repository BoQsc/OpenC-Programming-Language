# `openc test` Specification

`openc test` discovers only tests declared by project context or explicit paths. Core itself defines no test annotation syntax; the first tooling version treats a test program as a source set plus an expected semantic/runtime record.

Required behavior:

```text
parse/check every test before execution
isolate output paths
record target, implementation, source hashes, command, result, and diagnostics
separate language failure from test assertion failure and infrastructure failure
support --list, --filter, --jobs, --target, --report, and --no-run
never infer tests from build outputs or hidden global folders
```

Runtime test execution is available only for implementations/targets that support execution. Semantic-only Core tests can run through `openc check`.
