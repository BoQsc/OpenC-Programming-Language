# OpenC development authority

## Current authority order

1. `standard/core/OpenC_Core_Current.md` — normative Core semantic development authority.
2. `standard/core/grammar/OpenC_Core_Grammar.ebnf` — normative Core source-structure authority.
3. `standard/core/metadata/OpenC_Core_Rule_Index.json` — active Core rule identities.
4. `standard/core/metadata/OpenC_Core_Diagnostic_Catalog.json` — Core diagnostic identity.
5. `standard/core/metadata/OpenC_Core_Term_Index.json` — canonical Core terminology.
6. `standard/core/security/OpenC_Core_Security_Model.md` — Core safety boundary.
7. `standard/hosted/OpenC_Hosted_Current.md` — minimum Hosted component authority.
8. `standard/freestanding/OpenC_Freestanding_Current.md` — Freestanding component authority.
9. `standard/native/OpenC_Native_Current.md` — Native interface component authority.
10. `standard/tooling/OpenC_Tooling_Current.md` — Tooling and diagnostics component authority.
11. `conformance/` — authored fixture contracts and evidence formats.
12. `compiler/design/` and `tools/specs/` — informative implementation guidance.

## Implementation authority

The canonical authored reference implementation is the D source under `compiler/source/`. The Python source under `compiler/bootstrap/python/` is an informative bootstrap and cross-check path. Neither implementation overrides the standard.

When implementation behavior conflicts with the standard, the implementation contains a defect. When implementation work reveals an ambiguity or contradiction, maintainers record a specification finding rather than silently choosing new language behavior.

## Non-authoritative locations

```text
proposals/    possible future changes
changes/      accepted changes not fully integrated
history/      superseded and explanatory material
examples/     informative unless explicitly incorporated by a rule
compiler/bootstrap/python/  informative bootstrap, not canonical implementation
```

## Release authority

A versioned source snapshot is generated from one recorded state of this tree. A source-complete snapshot is not a compiled or released product. Licensing, governance, evidence gates, signing, and publication authorization remain separate.
