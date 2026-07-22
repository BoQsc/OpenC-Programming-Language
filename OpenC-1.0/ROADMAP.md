# OpenC roadmap

The Windows x86-64 Hosted D-bootstrap release candidate is release-ready and
remains unpublished. Linux, freestanding, Native, and standalone C-provider
verification are optional future target work; they do not block this release.

## Self-hosting critical path

1. **SH-5 — DMD-independent Windows backend (next)**
   - emit/link Windows x86-64 programs without a separately installed DMD,
     DUB, or Python runtime.
2. **SH-6 — standalone self-hosted release**
   - rebuild the compiler, runtime, and library from the shipped standalone
     distribution and record artifacts and checksums.

SH-4 is complete. SH-4A matches all 28 generated D files across the canonical
compiler and A/B/C projects byte for byte. SH-4B has Stage 1 invoke the
configured D compiler and build Stage 2 from the canonical `.p` compiler.
SH-4C has Stage 2 build Stage 3 and proves equal generated source, lexer
behavior, canonical IR, and normalized Windows PE artifacts. The compiler is
self-hosted through the bootstrap D backend; eliminating that external DMD
dependency is specifically SH-5.

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
SH-3C flow/safety evidence covers 3 maintained projects and 263 authored
source fixtures: 232 semantic comparisons plus 34 SH-2 frontend cases, with
313 functions, 733 blocks, 464 edges, 34 cleanups, and 19 observed rules.
SH-3D matches all 149 rejection outcomes and exact canonical IR for 117
accepted programs: 183 functions, 275 blocks, 1,489 instructions, and all 33
reachable opcodes. Full SH-3 passes.
SH-4 closure produces 7 stable generated modules and identical normalized
Stage-2/Stage-3 PE hash
`e1776ad8492ea4181dff91885ea45d371f1288abbdad8423cb2e4a16ef6c9e65`.

## Nonblocking quality work

- add dedicated fixtures for the 135 active rules that lack one;
- complete positive/rejection pairs for all 174 grammar productions;
- obtain independent grammar, semantic, security, and usability reviews;
- add separately scoped Linux, freestanding, Native, and provider target
  records only when those targets become active priorities.

Future language changes continue through the proposal and accepted-change
process. Provisional concurrency remains outside the Core 1.0 blocking path.
