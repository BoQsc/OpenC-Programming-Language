
# Independent Review Program

## Purpose

The review program attempts to invalidate CC2 before it can become Core 1.0. Reviewers are expected to find ambiguity, contradiction, unsoundness, impracticality, missing evidence, and usability failure—not merely confirm the document.

## Review tracks

1. **Grammar:** independently implement the standalone EBNF and challenge every production boundary.
2. **Semantics:** review every active rule for completeness, consistency, implementability, and testability.
3. **Security:** attempt to violate each safe-code guarantee and audit every unsafe precondition.
4. **Implementation:** build a maintained implementation without silently inventing behavior.
5. **Conformance:** execute every required fixture and report infrastructure failures separately.
6. **Real programs:** maintain three programs covering ordinary Core, failure/resources, and unsafe wrapping.
7. **Usability/documentation:** ensure ordinary users can learn the active language without hidden context.
8. **Release audit:** verify authority, licenses, build reproducibility, manifests, and immutable artifacts.

## Independence

A review is independent only when the reviewer did not author the audited rules or implementation. Self-review is useful but must be labelled `INTERNAL_REVIEW`, never `INDEPENDENT_REVIEW`.

The grammar reviewer should initially implement from the standalone EBNF without using an existing parser as authority. The security reviewer should not be the sole implementer of the audited safety subsystem.

## OpenC 1.0 gate policy

For the owner-maintained initial Windows x86-64 Hosted release, the internal
maintainer review and executable gates are required. Independent reviews are
recommended post-release assurance activities and may produce versioned errata;
they are not publication prerequisites. No internal review may be relabelled as
independent.

## Finding classes

```text
P0 — contradiction, unsound safe behavior, undefined authority, or release-blocking defect
P1 — serious ambiguity, implementability failure, or missing required behavior
P2 — incomplete rule, weak diagnostic/evidence contract, or significant usability problem
P3 — editorial, organizational, or nonblocking clarity problem
```

## Finding lifecycle

```text
OPEN → TRIAGED → ACCEPTED / REJECTED → PATCHED → VERIFIED → CLOSED
```

Every accepted normative finding must identify affected rules, grammar productions, fixtures, diagnostics, compatibility impact, and security impact.
