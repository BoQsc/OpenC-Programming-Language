# Independent Review Handoff

Reviewers receive the corrected candidate, the 23-finding correction register, rule and grammar matrices, security model, algorithms, and evidence schemas.

Required independent reviews:

```text
grammar: every production, lexical choice, ambiguity, and precedence row
semantic: every rule, cross-rule interaction, and implementation algorithm
security: no-UB taxonomy, ownership, cleanup, borrowing, provenance, representation, optimizer boundaries
usability: ordinary syntax, status/out diagnostics, error recovery, canonical examples
```

Reviewers declare independence and do not mark a finding resolved without changed artifacts and validation evidence.
