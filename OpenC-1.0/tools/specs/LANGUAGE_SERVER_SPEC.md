# OpenC Language Server Specification

The language server implements incremental UTF-8 document synchronization,
diagnostics, completion, hover, definition, references, safe rename, document
symbols, and formatting. The required transport is JSON-RPC 2.0 over stdio with
`Content-Length` framing.

Document versions must increase strictly. Stale changes are ignored. The server
accepts `$/cancelRequest`, returns error `-32800` for a remembered cancelled
numeric request ID, and follows `workspace/didChangeWorkspaceFolders` project
root changes. State is fixed at eight open documents, four MiB per source/frame,
and eight remembered cancellation IDs.

The first-party client is `editors/vscode`. It uses no npm dependency and caps
headers at 8 KiB, pending requests at 128, synchronized documents at eight, and
automatic restart attempts at three. After a restart it reinitializes and
resends the current open-document snapshots.

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
