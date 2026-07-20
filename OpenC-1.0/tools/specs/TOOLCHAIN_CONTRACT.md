# OpenC Toolchain Contract

The first-party tool family is one coherent interface:

```text
openc check
openc build
openc run
openc test
openc fmt
openc info
openc explain
openc validate
openc lsp
```

Classical CLI flags are primary:

```text
--name value
--name=value
--flag
```

OpenC-aware parenthesis invocation may normalize to the same command model:

```text
openc build(profile="strict", target="linux-x86_64")
```

The parenthesis form is a tooling parser, not Core source syntax. When ambiguous, classical CLI parsing wins. Every command supports `--diagnostics=json` and `--context-record=PATH` where applicable.
