# OpenC roadmap

The Windows x86-64 Hosted D-bootstrap release candidate is release-ready and
remains unpublished. Linux, freestanding, Native, and standalone C-provider
verification are optional future target work; they do not block this release.

## Self-hosting critical path

1. **SH-3C — flow and safety parity (next)**
   - SH-3A declaration/type and SH-3B name/constant/overload parity pass;
   - port flow, status/out, ownership, borrowing, cleanup, pointer, and unsafe
     checking with exact diagnostic outcomes.
2. **SH-3D — canonical IR parity**
   - port deterministic semantic lowering and canonical JSON IR emission;
   - compare semantic outcomes and canonical JSON IR across the authored
     fixture set.
3. **SH-4 — bootstrap closure**
   - stage 0 builds stage 1; stage 1 builds stage 2; stage 2 builds stage 3;
   - require reproducibly equivalent stage-2 and stage-3 outputs.
4. **SH-5 — DMD-independent Windows backend**
   - emit/link Windows x86-64 programs without a separately installed DMD,
     DUB, or Python runtime.
5. **SH-6 — standalone self-hosted release**
   - rebuild the compiler, runtime, and library from the shipped standalone
     distribution and record artifacts and checksums.

SH-2A through SH-2D and full SH-2 pass. Lexer evidence covers 288 canonical
`.p` sources plus 16 probes (304/304). Parser evidence covers those canonical
sources plus 15 parser probes (303/303), all 52 parser-produced syntax kinds,
and all 15 reachable parser/recovery rules. Project/module evidence covers 7
checked-in projects plus 15 focused probes (22/22), including all 3 observed
composition diagnostic rules.
SH-3A evidence covers the canonical compiler project plus 16 focused semantic
projects (17/17), with exact declaration, symbol, type-table, and duplicate
diagnostic parity.
SH-3B evidence covers one maintained canonical project plus 9 focused
projects (10/10), with 32 exact bindings, 10 constant results, 4 overload
selections, and 4 exact diagnostic rules.

## Nonblocking quality work

- add dedicated fixtures for the 135 active rules that lack one;
- complete positive/rejection pairs for all 174 grammar productions;
- obtain independent grammar, semantic, security, and usability reviews;
- add separately scoped Linux, freestanding, Native, and provider target
  records only when those targets become active priorities.

Future language changes continue through the proposal and accepted-change
process. Provisional concurrency remains outside the Core 1.0 blocking path.
