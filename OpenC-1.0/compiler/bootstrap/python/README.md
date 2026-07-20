# OpenC Python bootstrap compiler

Status: **INFORMATIVE SOURCE-AUTHORED; NOT COMPILED OR EXECUTED**

The canonical reference implementation is the D source under `compiler/source/`. This Python implementation is a standard-library-only bootstrap and cross-check path. It implements source loading, lexing, parsing, semantic analysis, flow and ownership checks, Core IR, deterministic C11 generation, Hosted runtime linking, formatter, diagnostics, conformance runner, and a basic LSP server.

Run from the canonical tree when a future maintainer chooses to execute it:

```text
PYTHONPATH=compiler/bootstrap/python python -m openc check path/to/openc.project.json
PYTHONPATH=compiler/bootstrap/python python -m openc generate path/to/openc.project.json
PYTHONPATH=compiler/bootstrap/python python -m openc build path/to/openc.project.json
```

These commands are documented only; no execution is claimed by the source package.
