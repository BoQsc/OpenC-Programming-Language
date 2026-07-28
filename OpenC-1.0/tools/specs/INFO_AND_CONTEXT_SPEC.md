# `openc info` and Active Context

`openc info --context` emits `schemas/TOOL_CONTEXT.schema.json` and a human summary containing:

```text
candidate and component claim
implementation and toolchain version
canonical source extension (`.p`)
project and source roots
logical module map
build-context values and their origins
target record and hash
profile and extensions
implementation limits
generated-source inputs
command-line overrides
environment inputs actually consulted
```

`openc info --sources`, `--modules`, `--types`, `--limits`, and `--dependencies` are filtered views of the same resolved context. The output is deterministic after path normalization.

The SH-10 native implementation also exposes `--target`; `--json` writes the
selected view to standard output, and `--output=PATH` preserves the same
`openc.tool_context.v1` record.
