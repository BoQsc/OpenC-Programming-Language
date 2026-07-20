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
- It lexically scans its own source and rejects authored malformed probes.
- Evidence is produced by `python compiler/selfhost/bootstrap.py`.

Status: **PASS**

This is not a self-hosting claim: the seed does not yet compile source.

### SH-2 — full frontend parity

- Port source management, lexer, parser, diagnostics, module composition, and
  project loading to `.p`.
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

The compiler-in-OpenC implementation needs purpose-built owned vectors, byte
and text builders, stable string tables/maps, JSON parsing and writing,
diagnostic collections, deterministic sorting, project-file access, and
eventually process invocation and Windows object/link support. These may be
specialized compiler libraries; generics are not required to begin.

No gate advances from `PENDING` based only on authored source. Each gate names
an executable command and evidence result before it becomes `PASS`.
