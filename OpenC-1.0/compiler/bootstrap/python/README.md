# OpenC Python bootstrap compiler

Status: **INFORMATIVE SOURCE; FOUR TESTS, BYTECODE CHECK, AND CLI SMOKE PASS**

The canonical compiler is the OpenC source under
`compiler/selfhost/source/`. This Python implementation is a
standard-library-only legacy bootstrap and optional cross-check path. It
implements source loading, lexing, parsing, semantic analysis, flow and
ownership checks, Core IR, deterministic C11 generation, Hosted runtime
linking, formatter, diagnostics, conformance runner, and a basic LSP server.

Run from the canonical tree:

```text
PYTHONPATH=compiler/bootstrap/python python -m openc check path/to/openc.project.json
PYTHONPATH=compiler/bootstrap/python python -m openc generate path/to/openc.project.json
PYTHONPATH=compiler/bootstrap/python python -m openc build path/to/openc.project.json
```

The recorded candidate verifies the Python unit suite, bytecode compilation,
and command-line help. It does not claim Python bootstrap parity with the
canonical OpenC compiler. It is not required by `openc` and is excluded from
the standalone compiler distribution.
