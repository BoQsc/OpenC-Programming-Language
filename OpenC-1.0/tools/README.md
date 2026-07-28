# First-party OpenC tool source

Status: **NATIVE OPENC FMT/INFO/TEST BUILT AND TESTED ON WINDOWS; D TOOL
SOURCES RETAINED**

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

The self-hosted public driver is
`compiler/selfhost/source/main_driver.p`. SH-10 implements `openc fmt`,
`openc info`, and `openc test` in canonical OpenC `.p` source and verifies
them from the relocated standalone compiler. `openc lsp --stdio` remains the
SH-11 engineering milestone.
