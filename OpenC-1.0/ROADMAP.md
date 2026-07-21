# OpenC roadmap

The Windows x86-64 Hosted D-bootstrap release candidate is release-ready and
remains unpublished. Linux, freestanding, Native, and standalone C-provider
verification are optional future target work; they do not block this release.

## Self-hosting critical path

1. **SH-2D — project/module frontend in OpenC (next)**
   - load `openc.project.json` and resolve explicit source/module paths;
   - compose multiple source units with import visibility and cycle handling;
   - retain exact lexer/parser observations per source while producing a
     deterministic project-level frontend observation;
   - execute every accepted and rejected frontend fixture in both compilers.
2. **SH-2 — full frontend parity**
   - finish source/module composition and project loading;
   - pass every accepted and rejected frontend fixture in both compilers.
3. **SH-3 — semantic and canonical IR parity**
   - port types, constants, overloads, flow, ownership, cleanup, unsafe
     checking, and deterministic IR lowering.
4. **SH-4 — bootstrap closure**
   - stage 0 builds stage 1; stage 1 builds stage 2; stage 2 builds stage 3;
   - require reproducibly equivalent stage-2 and stage-3 outputs.
5. **SH-5 — DMD-independent Windows backend**
   - emit/link Windows x86-64 programs without a separately installed DMD,
     DUB, or Python runtime.
6. **SH-6 — standalone self-hosted release**
   - rebuild the compiler, runtime, and library from the shipped standalone
     distribution and record artifacts and checksums.

SH-2A exact lexical parity, SH-2B owned single-pass lexer state, and SH-2C
exact parser parity already pass. Lexer evidence covers 285 canonical `.p`
sources plus 16 probes (301/301). Parser evidence covers the same canonical
sources plus 15 parser probes (300/300), all 52 parser-produced syntax kinds,
and all 15 reachable parser/recovery rules.

## Nonblocking quality work

- add dedicated fixtures for the 135 active rules that lack one;
- complete positive/rejection pairs for all 174 grammar productions;
- obtain independent grammar, semantic, security, and usability reviews;
- add separately scoped Linux, freestanding, Native, and provider target
  records only when those targets become active priorities.

Future language changes continue through the proposal and accepted-change
process. Provisional concurrency remains outside the Core 1.0 blocking path.
