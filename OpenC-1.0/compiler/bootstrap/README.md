# Compiler bootstrap area

Bootstrap implementations are retained here as supporting source. They are
not normative and are not the canonical compiler implementation.

- `python/` contains the earlier standard-library-only Python bootstrap.
- `../source/` contains the earlier D bootstrap/reference implementation.
- The canonical implementation is the OpenC source under
  `../selfhost/source/`.

A bootstrap implementation may be used to bring up or cross-check OpenC, but
its behavior never overrides the current standard, grammar, rule index,
diagnostic catalog, or canonical OpenC compiler.
