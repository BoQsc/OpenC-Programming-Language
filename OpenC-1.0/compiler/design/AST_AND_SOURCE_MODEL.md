# AST and Source Model

The AST preserves authored source structure and spans. It is not a normalized IR.

Every node has:

```text
stable node ID within one compilation
node kind
primary source span
children in source order
optional resolved type
attributes needed by later phases
```

The exchange schema is `schemas/AST.schema.json`. Implementations may use richer internal types, but tooling exports should preserve equivalent information.

## Required distinctions

- declarations versus reassignment;
- ordinary, `ref`, `ptr`, `optional`, and `storage` types;
- `own` and `out` as boundary modes, not types;
- ordinary versus ownership aggregate fields;
- checked cast versus reinterpretation;
- safe versus unsafe context;
- source `when` bodies regardless of selection;
- literal spelling and exact mathematical value;
- authored parentheses where formatter round-tripping requires them.
