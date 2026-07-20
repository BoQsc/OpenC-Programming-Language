# Compiler Driver Specification

## `openc check`

Parses and semantically validates without producing a runnable artifact.

## `openc build`

Builds one declared project context or explicit source set, writes artifacts only beneath the selected output root, and emits a build record.

## `openc run`

Builds and runs only when the target is executable in the active environment. Program arguments follow `--`.

Required common options:

```text
--candidate PATH
--project PATH
--source-root PATH
--module-map PATH
--target PATH
--profile standard|strict|critical
--output PATH
--diagnostics human|json|jsonl
--context-record PATH
--implementation-limits PATH
--extension NAME
```

No hidden global source path, host ABI, environment variable, or cached extension may influence plain-Core validity without appearing in the context record.
