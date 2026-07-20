# Project and Build Context Specification

Tooling uses a data-only project record such as `openc.project.json`; the filename is a tool convention, not language semantics.

Canonical OpenC source files use the `.p` extension. The name comes from the
word "open" in OpenC. Default discovery and generated-source naming use `.p`,
while explicitly mapped source paths remain valid independent of extension.

The record declares:

```text
candidate revision
source roots
logical module mapping
build-context values
selected target record
validation profile
output root
implementation limits
enabled extensions
generated-source inputs
```

A lock record pins exact dependencies, generators, tools, and integrity hashes. Reading project configuration executes no code. Command-line overrides are recorded in the active context rather than silently replacing configuration.
