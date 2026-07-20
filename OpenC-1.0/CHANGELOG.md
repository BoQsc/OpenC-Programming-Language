# OpenC development changelog

## 1.0.0-rc.1 — owner-certified Windows Hosted release candidate

- selected 0BSD for software and CC0-1.0 for specifications, documentation,
  metadata, diagrams, and artwork;
- ratified HD-012 with owner governance, contribution, security, errata,
  support, checksum, release, and publication authority;
- defined Windows x86-64 Hosted as the supported 1.0 implementation scope and
  moved Linux, freestanding, Native, standalone C providers, script/live, and
  Concurrent work outside the blocking path;
- separated normative fixture rules from exact compiler diagnostic
  expectations, migrated the imported corpus to Current, and removed the
  93-case edition-compatibility fallback;
- corrected active dedicated-fixture coverage to 331 of 466 rules and retained
  the 135-rule backlog as an explicit nonblocking evidence limitation;
- retained 268/268 conformance, 35/35 runtime fixtures, 4/4 maintained programs,
  and the complete debug/release build and implementation-test gates;
- marked the declared candidate `RELEASE_READY` but not published or released.

## 1.0-dev.4 — executable conformance milestone

- implemented current Core parser, name/type/constant, flow/status, ownership/borrow, storage/pointer/unsafe, diagnostic, IR, and D-backend behavior exercised by the authored suite;
- executed all 268 conformance fixtures successfully with zero infrastructure failures, including all 35 runtime fixtures;
- retained 93 explicit historical-edition rule-ID compatibility matches rather than presenting them as exact Current taxonomy matches;
- checked, built, and executed all four maintained programs to their authored exit/output contracts;
- compiled and linked all nine canonical D targets in debug and release modes and passed all eight D test commands plus four Python bootstrap tests;
- added reproducible maintained-program execution reporting and deterministic release-archive verification;
- retained non-release status because active-rule coverage, native Linux/freestanding execution, independent reviews, and HD-012 licensing/governance/signing remain pending.

## 1.0-dev.3 — local verification baseline

- corrected D language compatibility, packaging, imports, reserved identifiers, parser progress, control-condition parsing, and validator report handling;
- compiled and linked all nine canonical D targets in debug and release modes on Windows;
- executed all eight authored D test commands successfully;
- integrated runtime fixture build-and-run execution and modeled invalid UTF-8 as a source diagnostic;
- executed all 268 conformance fixtures, recording 41 passes, 227 implementation failures, and zero infrastructure failures;
- checked all four maintained projects and recorded that none are accepted, built, or run yet;
- retained explicit non-conforming, platform-unverified, independently unreviewed, and non-release status.

## 1.0-dev.2 — implementation source complete by authored inventory

- authored the canonical D reference compiler across frontend, semantic, safety, IR, backend, toolchain, and driver stages;
- preserved a standard-library-only Python bootstrap compiler and deterministic C11 backend as informative source;
- authored common, Linux, Windows, and freestanding runtime providers;
- authored minimum Hosted OpenC and D standard-library modules;
- authored standalone formatter, language-server, explanation, validation, information, runner, package, and release tool source;
- authored D and Python test source plus 268 current/historical Core fixtures whose complete rule dependencies remain active;
- authored Hosted, Freestanding, Native, and Tooling component baselines;
- added target/provider/API indexes, maintained projects, source-completeness contracts, build orchestration, and local release source;
- corrected Windows allocation metadata, bootstrap reinterpret lowering, standard-library module loading, and canonical fixture handling;
- kept compilation, linking, execution, conformance, platform verification, independent review, licensing, and release status explicitly pending.

## 1.0-dev.0 — canonical-mainline consolidation

- established one canonical long-term development tree;
- separated current standards, proposals, accepted changes, and history;
- promoted CC2 Implementation Readiness Revision 1 as the current Core development baseline;
- incorporated compiler, tooling, conformance, maintenance, and release authoring contracts;
- added local-only source-release and history-archive procedures;
- made the non-execution and non-release status explicit.
