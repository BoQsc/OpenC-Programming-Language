# OpenC 1.0 independent-review invitation

Status: **OPEN FOR EXTERNAL REVIEW**

OpenC invites reviewers who did not author the audited rules or implementation
to challenge the final Windows x86-64 Hosted 1.0 candidate. An internal review
is valuable, but it is never recorded as `INDEPENDENT_REVIEW`.

## Review tracks

- **Grammar:** implement or inspect the 174-production grammar independently,
  including precedence, recovery, and every accepting/rejecting fixture pair.
- **Semantics:** challenge the 466 active rules, their interactions, executable
  fixtures, diagnostics, and implementation algorithms.
- **Security:** attempt to violate safe-code guarantees, ownership, cleanup,
  borrowing, provenance, representation, and process/resource ceilings.
- **Editor:** install the deterministic VSIX in a clean profile and exercise
  diagnostics, formatting, symbols, hover, navigation, completion, rename,
  incremental edits, cancellation, workspace changes, and restart recovery.
- **Release:** reproduce compiler closure and archives, inspect PE/COFF and CRT
  independence, verify manifests/licenses/authority, and audit artifact hashes.

## Submission

Start from `review/REVIEW_FINDING_TEMPLATE.md`. Every submission must include an
independence declaration, track, severity, affected rule/production/artifact,
reproduction procedure, expected and actual result, and security/compatibility
impact. P0 and P1 findings are triaged before an owner-authorized final tag.
P2/P3 findings enter the ordinary errata and maintenance process.

The declared release scope is Windows x86-64 Hosted. Linux, freestanding,
Native-provider, and ARM64 claims are outside this review gate.
