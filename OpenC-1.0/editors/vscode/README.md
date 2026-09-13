# OpenC for Visual Studio Code

This dependency-free first-party extension starts the native OpenC compiler as
`openc.exe lsp --stdio`. The compiler packaged at the root of an OpenC release
is selected automatically; set `openc.compilerPath` only for a development
build or another installation.

The client provides diagnostics, formatting, document symbols, hover,
definition, references, completion, and rename. It synchronizes `.p` documents
with incremental UTF-8 edits and monotonically increasing versions, propagates
cancellation, tracks workspace-folder changes, and performs bounded recovery
after an unexpected server exit. Positions are translated between VS Code's
UTF-16 columns and the server's negotiated UTF-8 byte columns.

Resource limits are deliberately fixed: 4 MiB per protocol message, 128 pending
requests, 8 synchronized documents, an 8 KiB header, and 3 restart attempts.
No npm package or C/C++ language-service dependency is used.

The release extension is shipped as a deterministic `.vsix` containing its
own OpenC-native `openc.exe`. Install it with **Extensions: Install from
VSIX...** or with `code --install-extension OpenC-vscode-1.0.0.vsix`. The
packaged compiler is preferred automatically, so a separate compiler-path
setting is not required.
