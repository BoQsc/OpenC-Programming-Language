# OpenC development changelog

## 1.0.0-rc.9 — expanded standalone conformance candidate

- advanced the canonical compiler, Core metadata, release templates, and
  authored evidence to `1.0.0-rc.9`;
- raised standalone-package and publication-artifact verification from the
  immutable RC8 268-fixture baseline to the complete 278-fixture corpus;
- preserved `v1.0.0-rc.8`, its standalone archive, and its SH-6 evidence as
  historical release-candidate records;
- retained Windows x86-64 Hosted as the only required implementation target;
  Linux, freestanding, and Native-provider verification remain optional future
  work.
- closed the RC9 standalone semantic-parity gaps for text member typing,
  `when`-context lowering, and owned resource aggregate initializers;
- made qualified owning-field consumption retain the required
  `OPENC-OWN-USE-AFTER-MOVE-001` rejection behavior while aggregate `own`
  initializers move their source owner exactly once;
- made the OpenC-authored compiler's UTF-8 BOM helper conform to the status/out
  contract, allowing the canonical compiler source to build cleanly again;
- passed the complete self-host bootstrap with 383 canonical sources, 240
  flow/safety comparisons, 123 canonical-IR comparisons, and 153 exact
  rejection comparisons.

- completed the conformance-evidence granularity milestone with 466/466 active
  rules covered by executed dedicated fixtures and 174/174 grammar productions
  mapped to executed accepting/rejecting fixture pairs;
- expanded the Windows Hosted conformance corpus from 268 to 278 fixtures and
  passed 278/278 with zero failures and zero infrastructure failures;
- corrected initial UTF-8 BOM removal in the D reference compiler, informative
  Python bootstrap, and OpenC-owned self-hosted source loaders, with explicit
  accepted and repeated-BOM rejection fixtures;
- added direct recursion, struct equality, text-value, `when`-context, and
  unterminated-comment evidence, plus a named resource-initializer lifecycle,
  and made the coverage generator reject stale rule mappings;
- re-proved DMD-independent native Stage-2/Stage-3 closure after the source
  changes, with byte-identical generated C and executables plus equal
  normalized PE, lexer behavior, and canonical IR;
- made an RC9 standalone candidate refresh with the 278-fixture corpus the
  explicit successor engineering milestone;

- reduced a full native compiler self-rebuild from 698.918 to 381.049 seconds
  on the recorded host (45.5%) by avoiding noncompetitive full-syntax parent
  scans in the lowering hot path;
- replaced unbounded repeated native path-join allocation and linear file
  caching with deterministic content-safe caches, reducing measured peak
  working set to 11.37 MiB and peak private memory to 161.55 MiB;
- added a reproducible Windows native-rebuild benchmark with a clean child
  tool PATH and PSAPI peak-memory sampling;
- re-proved byte-identical native Stage-2/Stage-3 closure, exact semantic/IR
  and flow/safety parity, 268/268 conformance, 4/4 Python bootstrap tests, and
  native build/execution of all 4 maintained programs;
- completed the native-rebuild performance milestone and made dedicated
  active-rule and grammar-production fixture coverage the next engineering
  milestone;

- added deterministic complete-release assembly and verification covering the
  declared Core artifact layout, Windows Hosted standalone distribution,
  source/conformance bundles, implementation evidence, mandatory SHA-256 list,
  and owner authorization record;
- repaired the release-record contract by aligning its schema, template, and
  example on `openc.release_record.v2` and adding the completed SH-6 gate;
- completed SH-6 with two byte-identical relocatable standalone archives;
- proved packaged OpenC-native compiler → Stage 2 → Stage 3 closure from a
  foreign working directory while DMD, DUB, and Python were unavailable to the
  native builds;
- recorded byte-identical packaged/stage executables, generated C, normalized
  PE comparison, bootstrap-seed/backend hashes, and an internal 1,140-entry
  package manifest;
- passed native semantic/IR parity across 263 authored fixtures, all 268
  conformance fixtures, and all 4 maintained programs from the extracted
  package;
- made public `openc build` locate its runtime, native shim, and shipped backend
  relative to `openc.exe`, and made runtime path joining preserve absolute
  right-hand paths;
- corrected native C emission for cleanup argument modes, named-type
  declaration order, and identity integer casts, and corrected negative
  integer contextual typing and signed parse overflow handling exposed by the
  complete native semantic suite;
- retained the D implementation as an audit/conformance bootstrap seed rather
  than a native build dependency, and kept Linux, freestanding, and the
  authored Native provider explicitly outside the Windows Hosted gate.

- added deterministic single-file C11 emission in canonical OpenC `.p` source
  and exposed it through public
  `openc build --project=PROJECT --output=OUTPUT-EXE`;
- vendored the official TinyCC 0.9.27 Win64 binary distribution as the Windows
  compiler/linker backend, with LGPL-2.1 and bundled MIT/public-domain notices,
  integrity hashes, and the complete corresponding source archive;
- proved clean-path native Stage-2/Stage-3 closure with DMD, DUB, and Python
  hidden: generated C is byte-identical at SHA-256
  `ae3c4929bf874ae8c23416a9966c26788a8a294a53853628880fef848a28bbec`
  and raw executables are byte-identical at SHA-256
  `b42892ed15f944049eefd6b91206dd283de5ce38fef97d6667a1131dc955be5f`;
- matched lexer behavior and canonical IR across the native stages and built
  and executed a standalone OpenC smoke program through public `openc build`;
- completed SH-5 as the DMD-independent foundation used by SH-6;

- added deterministic OpenC-owned bootstrap D emission and proved 28 of 28
  generated files byte-exact across the canonical compiler and A/B/C projects;
- added the Hosted bootstrap toolchain driver and build-record path, allowing
  Stage 1 to invoke configured DMD and build Stage 2 from the canonical `.p`
  compiler;
- proved Stage-2/Stage-3 bootstrap closure across the 7-file generated tree,
  lexer behavior, canonical IR, and normalized PE artifacts with hash
  `e1776ad8492ea4181dff91885ea45d371f1288abbdad8423cb2e4a16ef6c9e65`;
- retained SH-4 as the auditable D-bootstrap closure beneath the new SH-5
  DMD-independent Windows path;
- retained explicit historical disclosure of the former 93 rule-ID
  compatibility matches while current conformance execution uses exact Current
  expectations with zero compatibility fallback.

### Complete semantic and canonical IR parity

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
