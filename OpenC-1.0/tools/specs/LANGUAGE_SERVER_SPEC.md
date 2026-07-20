# OpenC Language Server Specification

The language server implements standard document synchronization, diagnostics, completion, hover, definition, references, rename, symbols, semantic tokens, formatting, and code actions.

OpenC extensions:

```text
openc/ruleExplanation
openc/activeContext
openc/moduleResolution
openc/canonicalExpansion
openc/ownershipState
openc/flowState
openc/implementationLimits
```

Responses use stable rule IDs and normative source spans. The server never invents semantics from editor configuration that are absent from the active project/target context.
