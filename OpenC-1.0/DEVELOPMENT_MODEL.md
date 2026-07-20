
# Long-term OpenC development model

OpenC uses one canonical source tree and one controlled change lifecycle.

```text
idea
  ↓
proposal in proposals/
  ↓
grammar/rule/compatibility/fixture/implementation work
  ↓
review and evidence
  ↓
accepted change in changes/
  ↓
integration into standard/, compiler/, tools/, and conformance/
  ↓
versioned source release snapshot
```

## Separation rules

- `standard/` contains only the current development language and component specifications.
- `proposals/` may not be cited as current OpenC behavior.
- `changes/` contains accepted work that has not yet been integrated into the current development baseline.
- `history/` is non-normative and append-only.
- Implementations report specification defects; they do not resolve them silently.

## Compatibility classes

```text
clarification   wording or explanation changes without intended behavior change
correction      fixes a defect in the current authority
additive        adds valid new behavior without intentionally invalidating old behavior
tightening      intentionally rejects behavior previously accepted
loosening       intentionally accepts behavior previously rejected
deprecation     remains valid for a stated period but is scheduled for removal
breaking        requires a major-version boundary
```

## Version discipline

```text
1.0.x   errata, clarifications, implementation corrections; no intentional source break
1.x     additive evolution with explicit compatibility records
2.0     deliberate breaking changes
```

No new folder, schema, process, or artifact is added unless it prevents a named maintenance, correctness, implementation, security, or release failure.
