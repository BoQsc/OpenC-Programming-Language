# Build Record Specification

Every `openc build` can emit `schemas/BUILD_RECORD.schema.json`.

The record contains:

```text
candidate and implementation identity
active-context hash
target and profile
exact commands
input and generated-source hashes
output hashes and kinds
structured diagnostics
result category
start/end timestamps and duration where recorded
```

Timestamps are evidence metadata and never influence the deterministic artifact bytes unless an explicitly declared provider requires them. A critical or release build requires the record.
