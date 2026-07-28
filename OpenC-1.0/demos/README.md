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

Each demo is a standalone OpenC project. From the demo directory:

```
openc run main.p
```

Or with the full path to the compiler:

```
<openc-root>/compiler/openc.exe run main.p
```

## Structure

Each demo contains:
- `main.p` — the source file
- `openc.project.json` — project configuration
- `EXPECTED.md` — expected console output and exit code