# Finding and Errata Process

Every finding records severity, track, affected rule/production IDs, evidence, recommended correction, compatibility impact, owner, status, and resolution evidence.

```text
P0: contradiction, safety hole, unimplementable grammar/semantics, false conformance
P1: significant ambiguity, missing contract, portability or usability blocker
P2: bounded clarity or tooling issue
P3: editorial improvement
```

P0/P1 corrections block freeze. Errata after release may clarify without changing valid-program meaning; semantic changes follow the published compatibility policy.
