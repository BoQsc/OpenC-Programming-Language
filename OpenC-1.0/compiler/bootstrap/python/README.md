# OpenC Python bootstrap compiler

Status: **INFORMATIVE SOURCE; FOUR TESTS, BYTECODE CHECK, AND CLI SMOKE PASS**

The canonical reference implementation is the D source under `compiler/source/`. This Python implementation is a standard-library-only bootstrap and cross-check path. It implements source loading, lexing, parsing, semantic analysis, flow and ownership checks, Core IR, deterministic C11 generation, Hosted runtime linking, formatter, diagnostics, conformance runner, and a basic LSP server.

Run from the canonical tree:

```text
PYTHONPATH=compiler/bootstrap/python python -m openc check path/to/openc.project.json
PYTHONPATH=compiler/bootstrap/python python -m openc generate path/to/openc.project.json
PYTHONPATH=compiler/bootstrap/python python -m openc build path/to/openc.project.json
```

The recorded candidate verifies the Python unit suite, bytecode compilation,
and command-line help. It does not claim Python bootstrap parity with the
canonical D compiler.
