# OpenC

OpenC is a new open systems language: C-shaped, not C-compatible; safe by
default; explicit about unsafe memory; and designed around referenceable rules,
strong diagnostics, deterministic tooling, and executable conformance.

This directory is the single canonical development tree for the 1.0 release
candidate.

Canonical OpenC source files use `.p`, derived from the word "open" in OpenC.
The extension is an official tooling convention; explicit source paths and
logical module identity remain extension-independent.

## 1.0 release scope

The supported reference-implementation target is Windows x86-64 Hosted. Linux,
freestanding, Native, script/live, and Concurrent sources remain available as
experimental future work and do not block or enlarge the 1.0 claim. See
`release/RELEASE_SCOPE_1.0.md`.

## Verified state

- all 9 canonical D targets build and link in debug and release modes;
- all 8 D test commands and all 4 Python bootstrap tests pass;
- all 268 authored conformance fixtures pass, including 35 runtime fixtures;
- all 4 maintained programs check, build, and run successfully;
- all 281 canonical OpenC library, program, and fixture sources use `.p`;
- the compiler-in-OpenC frontend builds and passes SH-2A/SH-2B exact owned
  lexer parity on 287 canonical `.p` sources plus 16 probes (303/303), SH-2C
  exact parser parity on those sources plus 15 parser probes (302/302), and
  SH-2D exact project/module parity on 7 checked-in projects plus 15 probes
  (22/22); full SH-2 passes, and SH-3A declaration/symbol/type-table parity
  passes on the canonical compiler project plus 16 focused projects (17/17);
  SH-3B name, constant, and overload resolution parity is next;
- all diagnostic expectations use exact current matches; the historical
  compatibility fallback has been removed;
- 331 of 466 active Core rules have dedicated executable fixture coverage;
  the 135-rule dedicated-fixture backlog remains an explicit quality backlog,
  not an unimplemented-rule assertion;
- licensing and governance are resolved: 0BSD for software and CC0-1.0 for
  specifications, documentation, metadata, diagrams, and artwork.

The owner-certified Windows x86-64 Hosted release candidate is `RELEASE_READY`,
but it is not published or marked `RELEASED`. Independent third-party review
remains welcome and may produce errata; it is not a prerequisite for the
owner-maintained initial release.

Start with `AUTHORITY.md`, `STATUS.md`, `VERIFICATION_STATUS.md`,
`LICENSE_POLICY.md`, `standard/core/OpenC_Core_Current.md`, and
`release/LOCAL_BUILD_TEST_RELEASE_RUNBOOK.md`.
