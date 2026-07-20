# OpenC development changelog

## 1.0-dev.3 — local verification baseline

- corrected D language compatibility, packaging, imports, reserved identifiers, parser progress, control-condition parsing, and validator report handling;
- compiled and linked all nine canonical D targets in debug and release modes on Windows;
- executed all eight authored D test commands successfully;
- executed all 268 conformance fixtures, recording 29 passes, 203 failures, and 36 infrastructure failures;
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
