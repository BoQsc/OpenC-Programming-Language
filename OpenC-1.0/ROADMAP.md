# OpenC roadmap

The Windows x86-64 Hosted D-bootstrap release candidate is release-ready and
remains unpublished. Linux, freestanding, Native, and standalone C-provider
verification are optional future target work; they do not block this release.

## Self-hosting critical path

1. **SH-3 — semantic and canonical IR parity (next)**
   - port types, constants, overloads, flow, ownership, cleanup, unsafe
     checking, and deterministic IR lowering.
   - compare semantic outcomes and canonical JSON IR across the authored
     fixture set.
2. **SH-4 — bootstrap closure**
   - stage 0 builds stage 1; stage 1 builds stage 2; stage 2 builds stage 3;
   - require reproducibly equivalent stage-2 and stage-3 outputs.
3. **SH-5 — DMD-independent Windows backend**
   - emit/link Windows x86-64 programs without a separately installed DMD,
     DUB, or Python runtime.
4. **SH-6 — standalone self-hosted release**
   - rebuild the compiler, runtime, and library from the shipped standalone
     distribution and record artifacts and checksums.

SH-2A through SH-2D and full SH-2 pass. Lexer evidence covers 286 canonical
`.p` sources plus 16 probes (302/302). Parser evidence covers those canonical
sources plus 15 parser probes (301/301), all 52 parser-produced syntax kinds,
and all 15 reachable parser/recovery rules. Project/module evidence covers 7
checked-in projects plus 15 focused probes (22/22), including all 3 observed
composition diagnostic rules.

## Nonblocking quality work

- add dedicated fixtures for the 135 active rules that lack one;
- complete positive/rejection pairs for all 174 grammar productions;
- obtain independent grammar, semantic, security, and usability reviews;
- add separately scoped Linux, freestanding, Native, and provider target
  records only when those targets become active priorities.

Future language changes continue through the proposal and accepted-change
process. Provisional concurrency remains outside the Core 1.0 blocking path.
