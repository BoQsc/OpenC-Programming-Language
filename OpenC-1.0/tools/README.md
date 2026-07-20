# First-party OpenC tool source

Status: **D TOOLS BUILT AND TESTED ON WINDOWS**

Authored implementations now exist for:

```text
openc check/build/run/test/eval/live
openc fmt
openc info
openc explain
openc validate
openc adapter
openc lsp --stdio
```

The unified driver is `compiler/source/app/main.d`. Reusable tool modules are in `tools/source/openc/tools/`.
