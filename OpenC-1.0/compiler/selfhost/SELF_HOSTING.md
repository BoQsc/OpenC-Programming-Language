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
- The parity harness covers all 284 canonical `.p` sources plus 16 focused
  probes: 300 of 300 comparisons pass and all 12 source/lexical diagnostic
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
  the complete 300-case SH-2A corpus.

Status: **PASS**

### SH-2 — full frontend parity

- Retain SH-2A/SH-2B lexer parity while porting parser, diagnostic
  rendering/collections, module composition, and project loading to `.p`.
- Run every accepted/rejected frontend fixture through both implementations.
- Require matching acceptance and exact diagnostic rule IDs.

Status: **PENDING**

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

The compiler-in-OpenC implementation next needs parser-facing token and syntax
types, declaration/type/expression/statement parsing, recovery, and structured
diagnostic collections. Later stages need byte and text builders, stable string
tables/maps, JSON parsing and writing, deterministic sorting, project-file
access, process invocation, and Windows object/link support. These may be
specialized compiler libraries; generics are not required to begin.

No gate advances from `PENDING` based only on authored source. Each gate names
an executable command and evidence result before it becomes `PASS`.
