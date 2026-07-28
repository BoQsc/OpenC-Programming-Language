# OpenC Demo Programs

A collection of demo programs showcasing various features of the OpenC programming language.

## Demos

| Demo | Topic |
|------|-------|
| [hello](hello/) | Basic Hosted I/O — a classic "Hello, World!" |
| [calculator](calculator/) | Arithmetic operators — `+`, `-`, `*`, `/`, `%` |
| [types](types/) | Structs, enums, switch, nested types |
| [strings](strings/) | String and value printing with `io.print`/`io.println` |
| [ownership](ownership/) | Resources, `own`, `scope`, cleanup, `status`/`out` |
| [unsafe](unsafe/) | `storage`, `construct`/`destroy`, raw pointers, `unsafe` blocks |

## Building and running

Install a verified native standalone compiler, then build and execute all
demos with exact output checks:

```
python scripts/native_toolchain.py install --distribution PATH/TO/DISTRIBUTION
python demos/run_all.py
```

Build one demo directly with the public native compiler:

```
openc.exe build --project=demos/hello/openc.project.json --output=hello.exe
hello.exe
```

`run-all.cmd` and `run-all.ps1` are thin compatibility launchers for the
Python harness. No script contains a machine-specific compiler path.

## Structure

Each demo contains:
- `main.p` — the source file
- `openc.project.json` — project configuration
- `EXPECTED.md` — expected console output and exit code
