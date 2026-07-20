# Compiler bootstrap area

Bootstrap implementations are retained here as supporting source. They are not normative and are not the canonical reference implementation.

- `python/` contains the earlier standard-library-only Python bootstrap.
- The canonical reference implementation is the D source under `../source/`.

A bootstrap implementation may be used to bring up or cross-check OpenC, but its behavior never overrides the current standard, grammar, rule index, or diagnostic catalog.
