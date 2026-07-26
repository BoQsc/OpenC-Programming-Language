# OpenC roadmap

The Windows x86-64 Hosted standalone self-hosted release candidate is
release-ready and remains unpublished. Linux, freestanding, Native, and
standalone Native-provider verification are optional future target work; they
do not block this release.

## Completed self-hosting path

SH-0 through SH-6 pass. The deterministic standalone package is relocatable,
rebuilds the OpenC-native compiler through byte-identical Stage 2 and Stage 3,
validates its internal manifest, passes native semantic/IR parity, passes all
268 conformance fixtures, and builds and executes all 4 maintained programs.
The package and complete evidence are recorded in
`release/SH6_STANDALONE_EVIDENCE.md`.

SH-4 is complete. SH-4A matches all 28 generated D files across the canonical
compiler and A/B/C projects byte for byte. SH-4B has Stage 1 invoke the
configured D compiler and build Stage 2 from the canonical `.p` compiler.
SH-4C has Stage 2 build Stage 3 and proves equal generated source, lexer
behavior, canonical IR, and normalized Windows PE artifacts. The compiler is
self-hosted through the retained bootstrap D backend.

SH-5 is complete. The compiler emits deterministic C11 and uses the shipped
TinyCC 0.9.27 Win64 backend. With DMD, DUB, and Python hidden from the build
environment, native Stage 2 builds native Stage 3 through `openc build`.
Generated C, raw Windows executables, lexer behavior, and canonical IR reach
closure; a compiled smoke program executes successfully.

SH-6 is complete. Two independently assembled archives are byte-identical.
The extracted compiler locates its runtime and backend relative to its own
executable, rebuilds from a foreign working directory, and reaches exact
packaged/Stage-2/Stage-3 executable closure. The supported package mode is
Windows x86-64 Hosted with the six compiler-provided system modules.

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

## What comes next

1. **Publish the owner-authorized 1.0 artifact set**
   - perform the explicit owner publication act, record immutable artifact
     hashes, and create the release tag; mandatory SHA-256 records are ready,
     while detached signing remains optional until a public signing key is
     deliberately established.
2. **Improve native compiler performance**
   - reduce compiler-sized native rebuild time and peak memory while retaining
     exact generated-C, executable, normalized-PE, semantic, conformance, and
     maintained-program closure gates.
3. **Increase evidence granularity**
   - add dedicated fixtures for the 135 active rules that lack one, complete
     positive/rejection pairs for all 174 grammar productions, and seek
     independent grammar, semantic, security, and usability reviews.

Linux, freestanding, Native, and Native-provider target records remain optional
future work and begin only when those targets become active priorities.

Future language changes continue through the proposal and accepted-change
process. Provisional concurrency remains outside the Core 1.0 blocking path.
