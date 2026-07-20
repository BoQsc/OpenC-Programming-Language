# OpenC project governance

## Authority

OpenC is currently owner-maintained. The project owner controlling the
canonical source tree is the final authority for normative changes, accepted
contributions, errata, security handling, release authorization, and
publication. Authority may be delegated only through a committed governance
record naming the delegate and scope.

## Normative changes

A normative change must update every affected standard rule, grammar
production, rule index, diagnostic contract, conformance fixture, rationale,
and compatibility record together. Accepted changes are recorded in the
canonical tree. Uncommitted discussion and remote forge metadata are not
authority.

## Releases

The project owner authorizes releases after the required gates in
`release/RELEASE_GATES.md` pass for the declared release scope. SHA-256
checksums and the release record are mandatory. A detached cryptographic
signature is optional; the 1.0 process does not depend on a third-party signing
service or an unpublished key.

## Contributions

Contribution terms are defined in `CONTRIBUTING.md`. No contributor license
agreement is required. The owner may reject or defer a change even when its
license is compatible.

## Errata and support

The project owner classifies and publishes errata according to
`release/ERRATA_POLICY.md`. Support is best-effort as described in
`release/SUPPORT_POLICY.md`.
