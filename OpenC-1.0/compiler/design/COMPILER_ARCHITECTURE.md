# Compiler Architecture Contract

The recommended compiler is a deterministic multi-phase pipeline. Each phase consumes an immutable result from the previous phase and emits structured diagnostics without mutating normative source meaning.

```text
source bytes
→ UTF-8 decoder and source map
→ lexer
→ concrete syntax / parser
→ lossless AST
→ logical module composition
→ declaration tables
→ type resolution
→ constant evaluation
→ overload resolution
→ typed AST
→ CFG
→ flow/status-out analysis
→ ownership/resource analysis
→ borrow/lifetime analysis
→ unsafe/provenance validation
→ typed Core IR
→ interpreter or target backend
```

## Phase boundaries

- The lexer does not perform name or type lookup.
- The parser recognizes every syntactically valid form, including forms later rejected semantically.
- Module composition precedes full name resolution.
- Constant evaluation uses the same exact numeric model as runtime.
- Flow facts are attached to CFG edges, not inferred from source indentation.
- Ownership obligations are tracked independently from address bits.
- Unsafe validation never disables typing, flow, ownership, or target checks.
- Lowering preserves left-to-right evaluation, transactional commits, and complete LIFO cleanup.

A compiler may combine phases for performance, but evidence and diagnostics must remain attributable to the normative phase taxonomy.
