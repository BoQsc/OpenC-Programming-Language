# OpenC self-hosting and standalone compiler gates

The long-term canonical compiler is written in OpenC and builds OpenC programs
without DMD, DUB, Python, or another language compiler at execution time. The
existing D implementation remains the auditable stage-0 bootstrap seed; it is
not deleted when bootstrap closure is achieved.

The supported initial target is Windows x86-64 Hosted. Linux and freestanding
do not gate this program.

## Gates

### SH-0 — canonical source convention

- `.p` is ratified as the official tooling extension.
- Canonical compiler, library, maintained-program, example, and conformance
  source uses `.p`.
- Explicit paths remain extension-independent.

Status: **PASS**

### SH-1 — compiler-in-OpenC frontend seed

- Stage 0 builds a native executable from `compiler/selfhost/source/main.p`.
- The executable reads UTF-8 `.p` source through Hosted APIs.
- It lexically scans its own source and emits a versioned observation protocol.
- Evidence is produced by `python compiler/selfhost/bootstrap.py`.

Status: **PASS**

This is not a self-hosting claim: the seed does not yet compile source.

### SH-2A — exact lexer parity

- The OpenC implementation covers stage-0 keywords, identifiers, numeric and
  text literals, comments, symbols, UTF-8 source rejection, and all lexical
  diagnostics.
- Stage 0 and stage 1 match process outcome, token kind and byte span,
  diagnostic rule and byte span, source line and byte column, and token/error
  totals.
- The parity harness covers all 288 canonical `.p` sources plus 16 focused
  probes: 304 of 304 comparisons pass and all 12 source/lexical diagnostic
  rules are observed. The focused set includes CRLF and lone-CR positions.
- Evidence is produced by `python compiler/selfhost/bootstrap.py` and recorded
  in `build-output/selfhost/lexer-parity-result.json`.

Status: **PASS**

### SH-2B — owned single-pass lexer state

- Stage 1 performs one lexical pass and stores tokens and diagnostics in
  separate OpenC-owned packed buffers.
- Both allocations are released by ownership-checked scoped cleanup.
- Every stored token and diagnostic carries a byte offset, byte length,
  one-based line, and one-based byte column.
- Observation protocol 2 compares all stored fields against stage 0 across
  the complete 304-case SH-2A corpus.

Status: **PASS**

### SH-2C — exact parser parity

- Stage 1 reads the owned token records through parser-facing lookahead and
  matching APIs and stores final syntax records in a third owned buffer.
- Declarations, types, blocks, statements, precedence/assignment expressions,
  postfix operations, initializers, intrinsics, and recovery execute in OpenC.
- Parser observation protocol 1 compares process outcome, syntax-node creation
  order, all 52 parser-produced node kinds and final byte spans, diagnostic
  rule/span/position, node totals, and error totals.
- All 288 canonical `.p` sources plus 15 focused parser probes match exactly:
  303 of 303 comparisons pass and all 15 reachable parser/recovery diagnostic
  rules are observed.

Status: **PASS**

### SH-2D — exact project/module frontend parity

- Stage 1 parses `openc.project.json`, sorts logical modules deterministically,
  preserves source-list order, resolves project-relative source paths, and
  processes multiple source units.
- Project observation protocol 1 compares module/unit/source/import records,
  per-source parser totals and diagnostics, compiler-provided Hosted modules,
  missing imports, ambiguous short qualifiers, direct cycles, and summary
  totals.
- All 7 checked-in projects plus 15 focused project/module probes match
  exactly: 22 of 22 comparisons pass and all 3 composition diagnostic rules
  are observed.

Status: **PASS**

### SH-2 — full frontend parity

- SH-2A through SH-2D jointly cover the lexical, syntactic, recovery, project,
  multi-source, and module-composition frontend.
- Every canonical `.p` fixture source participates in lexer/parser comparison;
  checked-in projects and focused graph cases participate in project parity.
- Matching process outcomes, exact diagnostic rule IDs and locations, syntax
  records, module ordering, imports, graph diagnostics, and totals are required.

Status: **PASS**

This gate does not include types, name resolution beyond module composition,
ownership, flow, lowering, or IR; those are explicitly SH-3.

### SH-3A — declaration, symbol, and type-table parity

- Stage 1 predeclares aggregate/resource/enum types, interns built-in, named,
  qualified, const, view, slice, and fixed-array types, and records top-level
  functions, aggregates, enum items, module constants, fields, parameter
  modes, visibility, resource state, and source spans in OpenC-owned storage.
- Semantic declaration observation protocol 1 compares exact declaration and
  member order, symbol attributes, canonical type IDs and structure, and
  declaration-layer duplicate diagnostics.
- The canonical compiler-in-OpenC project plus 16 focused multi-source and
  multi-module projects match exactly: 17 of 17 comparisons pass, observing
  264 declarations and 385 complete type-table records.
- Evidence is produced by `python compiler/selfhost/bootstrap.py` and recorded
  in `build-output/selfhost/semantic-declaration-parity-result.json`.

Status: **PASS**

### SH-3 — semantic and IR parity

SH-3B establishes the resolution layer:

- Stage 1 owns lexical and module binding tables, local/parameter/field/enum
  target selection, constant-domain results, function signatures, and
  deterministic overload ranking.
- Semantic resolution observation protocol 1 compares exact use and target
  spans, symbol identities, resolved types, constant domains/values, selected
  overloads, call results, and resolution diagnostics.
- The maintained computation project plus 9 focused projects match exactly:
  10 of 10 comparisons pass, observing 32 bindings, 10 constants, 4 selected
  calls, and exact unknown-name, no-match, ambiguity, and divide-by-zero rules.
- Evidence is recorded in
  `build-output/selfhost/semantic-resolution-parity-result.json`.

SH-3B status: **PASS**

SH-3C owns flow, status/out, ownership, borrowing, cleanup, pointer, and unsafe
analysis in OpenC. Semantic flow/safety observation protocol 1 matches exact
function spans, CFG block/edge counts, cleanup order, diagnostic phases/rules,
and diagnostic spans across 3 maintained projects and 263 authored source
fixtures. It compares 232 semantic cases, delegates 34 frontend-error cases to
SH-2, and observes 313 functions, 733 blocks, 464 edges, 34 cleanups, and 19
flow/safety rules.

SH-3C status: **PASS**

SH-3D owns semantic acceptance and deterministic canonical JSON IR lowering.
Across the same maintained/authored corpus, stage 0 and stage 1 match all 149
frontend/semantic rejection outcomes and compare exact IR for 117 accepted
programs: 183 functions, 275 blocks, 1,489 instructions, and all 33 reachable
canonical opcodes. Matching includes module/function/block/instruction order,
types, values, text, byte spans, operands, and target-fault records.

SH-3D status: **PASS**

Status: **PASS**

Evidence is produced by `python compiler/selfhost/bootstrap.py` and recorded
in `semantic-flow-safety-parity-result.json` and
`semantic-ir-parity-result.json` under `build-output/selfhost`.

### SH-4 — bootstrap self-compilation

- SH-4A: port deterministic bootstrap D-source emission and prove generated
  source parity from the canonical IR.
- SH-4B: add the Hosted toolchain driver so stage 1 can invoke the configured D
  compiler and build stage 2 from the same canonical `.p` project.
- SH-4C: have stage 2 build stage 3 and require normalized generated-source,
  semantic-IR, behavior, and artifact equivalence.
- Stage 0 builds stage 1 from `.p`; stage 1 builds stage 2 from the same `.p`.
- Stage 2 builds stage 3; stage 2 and stage 3 are reproducibly equivalent.

Status: **PENDING**

Next subgate: **SH-4A — bootstrap D-source backend parity**

### SH-5 — DMD-independent Windows backend

- Implement deterministic Windows x86-64 object emission and the required
  runtime/link step in OpenC, or integrate an owner-approved redistributable
  backend whose bits ship inside the standalone distribution.
- `openc build` succeeds on a clean Windows host without DMD, DUB, or Python.

Status: **PENDING**

### SH-6 — standalone self-hosted release

- The standalone compiler rebuilds itself and all supported runtime/library
  inputs.
- It passes the full conformance and maintained-program gates.
- The source, bootstrap seed, stage artifacts, normalized comparison, and
  checksums are recorded in the release evidence.

Status: **PENDING**

## Required enabling libraries

SH-3 now supplies owned frontend, semantic, safety, acceptance, and canonical
IR stages. Bootstrap closure next needs deterministic D-source writing and
Hosted process invocation. SH-5 later replaces the installed D compiler with
the standalone Windows object/link backend. These may be specialized compiler
libraries; generics are not required to begin.

No gate advances from `PENDING` based only on authored source. Each gate names
an executable command and evidence result before it becomes `PASS`.
