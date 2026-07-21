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
- The parity harness covers all 286 canonical `.p` sources plus 16 focused
  probes: 302 of 302 comparisons pass and all 12 source/lexical diagnostic
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
  the complete 302-case SH-2A corpus.

Status: **PASS**

### SH-2C — exact parser parity

- Stage 1 reads the owned token records through parser-facing lookahead and
  matching APIs and stores final syntax records in a third owned buffer.
- Declarations, types, blocks, statements, precedence/assignment expressions,
  postfix operations, initializers, intrinsics, and recovery execute in OpenC.
- Parser observation protocol 1 compares process outcome, syntax-node creation
  order, all 52 parser-produced node kinds and final byte spans, diagnostic
  rule/span/position, node totals, and error totals.
- All 286 canonical `.p` sources plus 15 focused parser probes match exactly:
  301 of 301 comparisons pass and all 15 reachable parser/recovery diagnostic
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

### SH-3 — semantic and IR parity

- Port types, constants, overloads, flow, status/out, ownership, borrowing,
  cleanup, unsafe checking, and lowering.
- Emit the canonical JSON IR deterministically.
- Require semantic and IR parity across the complete authored fixture set.

Status: **PENDING**

### SH-4 — bootstrap self-compilation

- Implement the bootstrap D-source backend and required process invocation in
  OpenC.
- Stage 0 builds stage 1 from `.p`; stage 1 builds stage 2 from the same `.p`.
- Stage 2 builds stage 3; stage 2 and stage 3 are reproducibly equivalent.

Status: **PENDING**

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

The compiler-in-OpenC implementation next needs SH-3 semantic tables, name and
type resolution, constants, overloads, flow, ownership/borrowing, cleanup,
unsafe checking, and canonical IR lowering. Later stages need stable string
tables/maps, JSON writing, process invocation, self-compilation, and Windows
object/link support. These may be specialized compiler libraries; generics are
not required to begin.

No gate advances from `PENDING` based only on authored source. Each gate names
an executable command and evidence result before it becomes `PASS`.
