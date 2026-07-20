# OpenC Core 1.0 — Owner Ratification Record R2

## Result

The project owner ratifies HD-001 through HD-012 for the OpenC 1.0 release
candidate.

```text
semantic and project decisions ratified: 12
pending owner decisions:                  0
HD-012 legal/governance status:           RATIFIED
release-candidate scope:                  WINDOWS X86-64 HOSTED
release ready:                            YES
published/released:                       NO
```

## Decision status

| ID | Decision | Status |
|---|---|---|
| HD-001 | Recoverable failure model | RATIFIED_FOR_1_0 |
| HD-002 | Absence type spelling and semantics | RATIFIED_FOR_1_0 |
| HD-003 | Compile-time condition power | RATIFIED_FOR_1_0 |
| HD-004 | Resource and ownership syntax | RATIFIED_FOR_1_0 |
| HD-005 | Fallible cleanup policy | RATIFIED_FOR_1_0 |
| HD-006 | Native boundary syntax status | RATIFIED_FOR_1_0 |
| HD-007 | Minimum Hosted 1.0 library | RATIFIED_FOR_1_0 |
| HD-008 | Source-file extension policy | RATIFIED_FOR_1_0 |
| HD-009 | 1.0 conformance-set boundary | RATIFIED_FOR_1_0 |
| HD-010 | Script and live mode status | RATIFIED_FOR_1_0 |
| HD-011 | Concurrency publication status | RATIFIED_FOR_1_0 |
| HD-012 | Licensing and project authority | RATIFIED_FOR_1_0 |

## HD-008 selection

- `.p` is the official OpenC source-file extension; its name is derived from
  the word "open" in OpenC.
- First-party source, examples, templates, generated-source names, and default
  source discovery use `.p`.
- The extension remains outside Core language semantics. Explicit source paths
  are accepted independent of extension, and filenames never create logical
  module identity.

## HD-012 selection

- 0BSD covers software, standalone code, tests, tools, examples, and executable
  conformance fixture source.
- CC0-1.0 covers specifications, documentation, schemas, metadata, diagrams,
  artwork, and other non-code assets.
- Contributions arrive under the applicable outbound terms without a CLA.
- The project owner controlling the canonical tree is the normative, errata,
  security, release, checksum, and publication authority.
- SHA-256 checksums and an owner-authorized release record are mandatory;
  detached cryptographic signatures are optional.
- No exclusive OpenC word or original-artwork trademark claim is asserted and
  no endorsement is implied.
- Support is best-effort for the Windows x86-64 Hosted 1.0 scope.

The controlling terms are local to the source package in `LICENSE`,
`LICENSES/CC0-1.0.txt`, `LICENSE_POLICY.md`, `GOVERNANCE.md`, `SECURITY.md`,
`TRADEMARKS.md`, and `release/`.

## Effect

Ratified decisions may be changed only through the recorded normative-change
and errata process. `RELEASE_READY` authorizes candidate artifact preparation;
publication remains a distinct owner action.
