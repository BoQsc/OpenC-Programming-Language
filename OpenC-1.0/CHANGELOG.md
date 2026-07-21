# OpenC development changelog

## Unreleased — complete semantic and canonical IR parity

- added stage-0 and OpenC-owned SH-3C flow/safety observation paths covering
  CFG structure, cleanup order, status/out, ownership, borrowing, pointer, and
  unsafe diagnostics; 232 semantic comparisons match exactly, alongside 34
  frontend cases already covered by SH-2;
- added OpenC-owned semantic acceptance and deterministic canonical JSON IR
  lowering for all 33 reachable opcodes;
- matched all 149 frontend/semantic rejection outcomes and exact IR for 117
  accepted programs, covering 183 functions, 275 blocks, and 1,489
  instructions across the complete authored source-fixture corpus and three
  maintained projects;
- integrated SH-3C/SH-3D into the bootstrap evidence command, completed SH-3,
  and made SH-4A bootstrap D-source backend parity the next milestone.

## 1.0.0-rc.8 — exact name, constant, and overload resolution parity

- added a deterministic stage-0 semantic resolution observation protocol for
  name-use bindings, target symbol identities and spans, resolved types,
  constant domains and values, selected overloads, call results, and exact
  resolution diagnostics;
- added OpenC-owned lexical/module binding, function-signature, constant
  evaluation, and deterministic overload-selection state in canonical `.p`
  source;
- matched the maintained computation project plus 9 focused semantic projects
  exactly (10/10), observing 32 bindings, 10 constant results, 4 selected
  calls, and exact unknown-name, call-no-match, call-ambiguity, and
  divide-by-zero diagnostics;
- retained exact declaration/type parity across 17/17 projects, now observing
  264 declarations and 385 type records, lexer parity across 288 canonical
  sources plus 16 probes (304/304), parser parity plus 15 probes (303/303), and
  project/module parity across 22/22 comparisons;
- promoted SH-3B and made SH-3C flow/safety parity the explicit next milestone.

## 1.0.0-rc.7 — exact declaration, symbol, and type-table parity

- added a deterministic stage-0 semantic declaration observation protocol for
  module/source order, top-level symbols, aggregate and enum members, function
  signatures, visibility, ownership flags, source spans, interned canonical
  types, and declaration-layer duplicate diagnostics;
- added OpenC-owned declaration, symbol, diagnostic, and canonical type tables
  supporting built-ins, named/qualified/resource types, const qualification,
  references, pointers, optionals, storage, slices, and fixed arrays;
- matched the canonical compiler-in-OpenC project plus 16 focused semantic
  projects exactly (17/17), observing 213 declarations and 376 type-table
  records across overload, multi-source, multi-module, ownership, and
  diagnostic cases;
- retained exact lexer parity across 287 canonical sources plus 16 probes
  (303/303), parser parity plus 15 probes (302/302), and project/module parity
  across 22/22 comparisons;
- promoted SH-3A and made SH-3B name, constant, and overload resolution parity
  the explicit next milestone.

## 1.0.0-rc.6 — exact project/module frontend parity

- added a deterministic stage-0 project observation protocol over sorted
  logical modules, ordered units, resolved paths, imports, per-source parser
  results, graph diagnostics, and totals;
- added a specialized JSON project loader and multi-source/module composer in
  canonical OpenC `.p` source;
- matched all 7 checked-in projects plus 15 focused project/module probes
  exactly (22/22), covering missing imports, ambiguous short qualifiers, and
  direct import cycles;
- retained exact lexer parity across 286 canonical sources plus 16 probes
  (302/302) and parser parity plus 15 probes (301/301);
- promoted SH-2D and full syntactic/project frontend SH-2, making SH-3
  semantic and canonical IR parity the explicit next milestone.

## 1.0.0-rc.5 — exact compiler-in-OpenC parser parity

- added parser-facing access over the OpenC-owned token buffer and a third
  OpenC-owned buffer for final syntax records;
- ported top-level declarations, types, blocks, statements, precedence and
  assignment expressions, postfix operations, initializers, intrinsics, and
  parser recovery to canonical `.p` source;
- added a stage-0 parser observation command covering creation-order syntax
  kinds/final spans, diagnostics with positions, node totals, and error totals;
- passed exact parser parity over 285 canonical `.p` sources plus 15 focused
  probes (300/300), covering all 52 parser-produced syntax kinds and all 15
  reachable parser/recovery rules;
- retained exact lexical parity across the expanded corpus: 285 canonical
  sources plus 16 probes (301/301);
- promoted SH-2C and made SH-2D multi-source project/module frontend work the
  explicit next milestone.

## 1.0.0-rc.4 — owned single-pass compiler-in-OpenC lexer state

- replaced the stage-1 lexer's two observation passes with one lexical pass
  and separate OpenC-owned token and diagnostic buffers;
- added ownership-checked scoped cleanup for both buffers and packed record
  access that does not fabricate typed lifetimes over raw allocation storage;
- attached one-based source line and byte-column positions to every stored
  token and diagnostic;
- upgraded the lexical observation protocol so stage 0 and stage 1 compare
  positions as well as outcomes, kinds, rules, byte spans, and totals;
- expanded focused coverage with CRLF and lone-CR positioning and passed all
  284 canonical `.p` sources plus 16 probes (300/300);
- promoted SH-2B and made SH-2C parser implementation the explicit next
  self-hosting milestone.

## 1.0.0-rc.3 — exact compiler-in-OpenC lexer parity

- replaced the structural self-host scanner with the complete stage-0 lexer in
  canonical OpenC `.p` source;
- added a versioned lexical observation protocol and proved exact outcome,
  token kind/span, diagnostic rule/span, source-encoding, and total parity
  across all 284 canonical `.p` sources plus 15 focused probes (299/299);
- added byte-length and checked byte-access Hosted text primitives needed for
  byte-exact compiler source spans;
- corrected the D bootstrap backend so `ref T` function parameters are emitted
  with reference ABI semantics instead of value copies;
- promoted SH-2A while keeping full SH-2, semantics/IR, self-compilation, the
  DMD-independent Windows backend, and standalone release explicitly pending.

## 1.0.0-rc.2 — `.p` convention and executable self-host seed

- ratified `.p`, derived from the word "open" in OpenC, as the official
  tooling extension while preserving extension-independent explicit paths and
  module identity;
- migrated all 281 canonical OpenC library, maintained-program, and
  conformance source files plus their project/fixture records to `.p`;
- added whole-file Hosted text I/O and checked Unicode-scalar access needed by
  compiler implementations;
- added the first compiler-in-OpenC `.p` source and executable bootstrap gate:
  stage 0 builds it, it scans its own UTF-8 source, and malformed-source probes
  are rejected;
- recorded the remaining frontend, semantic/IR, self-compilation, native
  backend, and standalone release gates without claiming they already pass;
- retained 268/268 conformance, 35/35 runtime fixtures, and 4/4 maintained
  programs after the source migration.

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
