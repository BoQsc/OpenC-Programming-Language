# `openc test` Specification

`openc test` discovers only tests declared by project context or explicit paths. Core itself defines no test annotation syntax; the first tooling version treats a test program as a source set plus an expected semantic/runtime record.

SH-10 accepts `--manifest=openc.tests.json` or one explicit
`--project=openc.project.json`. `--report=PATH` writes the
`openc.test_result.v1` record defined by `schemas/TEST_RESULT.schema.json`.
The explicit manifest uses `openc.test_manifest.v1` as defined by
`schemas/TEST_MANIFEST.schema.json`.
Discovery and execution are name-sorted. `--jobs=N` is retained in the record
for forward-compatible scheduling while this deterministic implementation
executes sequentially.

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
