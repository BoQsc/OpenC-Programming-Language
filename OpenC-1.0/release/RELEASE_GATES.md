# OpenC 1.0 release gates

Required gates for the declared Windows x86-64 Hosted scope:

```text
G1  owner semantic decisions HD-001 through HD-012       PASS
G2  grammar/structure maintainer audit and validators     PASS
G3  semantic implementation tests and conformance suite  PASS
G4  safety/security regression suite and boundary review PASS
G5  implementation I0-I5 debug/release builds            PASS 9/9 + 9/9
G6  complete authored conformance manifest               PASS 278/278; exact
G7  maintained programs on claimed target                PASS 4/4 WINDOWS
G8  maintainer documentation/usability release review    PASS
G9  deterministic clean source rebuild/archive checks    PASS
G10 licensing/governance/checksum/publication authority  PASS
G11 standalone self-hosted distribution (SH-6)           PASS
G12 native default workflow and regression budgets (SH-8) PASS
G13 native public CLI and diagnostic usability (SH-9)    PASS 12/12
G14 native project workflow completeness (SH-10)         PASS 21/21
G15 native language-service completeness (SH-11)         PASS 19/19
G16 native semantic language intelligence (SH-12)        PASS 23/23
G17 native throughput/authority evidence (SH-13/SH-14)   PASS 20/20 STABILITY
G18 Windows x64 ABI and machine-code substrate (SH-15)   PASS 25/25
G19 PE32+ and CRT-free runtime (SH-16)                    PASS 34/34
G20 WinMD raw + idiomatic Windows projections (SH-17/18) PASS 30/30 + 27/27
G21 compiler-capable native backend and TinyCC exit       PASS 20/20 RELEASE
```

There are no open P0/P1 findings in the maintainer release review. Independent
third-party grammar, semantic, security, and usability reviews remain strongly
recommended, but they are post-release assurance work and not mandatory for the
owner-maintained initial 1.0 release.

Linux, freestanding, Native, script/live, and Concurrent sources are outside
the claimed 1.0 implementation scope. Their verification cannot fail a
Windows Hosted release gate.

G6 covers the entire authored 278-fixture manifest with zero compatibility
fallback in the current run; the former 93 historical rule-ID compatibility
matches remain disclosed in `CHANGELOG.md`. Dedicated fixtures cover all 466
active Core rules, and every one of the 174 grammar productions names an
executed accepting/rejecting pair. The authoring backlog is empty.

The `.p` source-convention gate, executable SH-1 compiler-in-OpenC seed, SH-2A
exact lexer-parity subgate, SH-2B owned single-pass lexer-state subgate, SH-2C
exact parser-parity subgate, SH-2D project/module subgate, and full syntactic
and project frontend SH-2 gate pass. SH-3A declaration, symbol, and type-table
parity also passes. SH-3B name/constant/overload, SH-3C flow/safety, and SH-3D
semantic-outcome/canonical-IR parity pass, completing SH-3. SH-4 bootstrap
self-compilation and closure now pass as well: Stage 1 builds Stage 2
and Stage 2 builds an equivalent Stage 3. SH-5 DMD independence also passes:
native Stage 2 builds a byte-identical native Stage 3 through the historical
public `openc build`, deterministic C11, and shipped TinyCC Win64 path with
DMD, DUB, and Python hidden. SH-6 standalone packaging also passes: two
independent package builds are byte-identical, the extracted compiler is
relocatable, and packaged Stage 2 and Stage 3 are byte-identical.

SH-8 makes the native compiler the default release compiler-under-test. Native
validation and self-rebuild elapsed time and memory are budgeted, unchanged
daily conformance may use an exact-input cache, and the required full/release
paths force fresh 278-fixture validation. The D seed is not executed.

SH-9 requires the relocated native Stage 3 to pass all 12 public CLI
contracts: `check`, `run`, version, target, active/historical rule
explanation, concise human failures, stable `openc.check.v1` machine records,
and program-argument forwarding. All six demos execute through the public
native CLI. The D seed remains absent.

SH-10 requires relocated native Stage 3 to pass all 21 native project-workflow
contracts: syntax-preserving formatter check/write, deterministic context
views, name-sorted test discovery/execution, stable machine records, and
distinct language, assertion, and infrastructure outcomes. The D seed remains
absent.

SH-11 requires relocated native Stage 3 to pass all 19 native
language-service contracts: JSON-RPC lifecycle/capabilities, full-document
synchronization, stable rule-ID diagnostics, SH-10 formatting, negative
protocol states, shutdown/exit behavior, bounded UTF-8 framing, and
byte-identical independent transcripts. The D seed remains absent.

SH-12 requires relocated native Stage 3 to pass all 23 project-semantic
contracts: document symbols and typed hover, cross-document definition and
references, name-sorted completion, validated collision-safe rename,
project-root isolation, synchronized close, published transcript-schema
validation, and byte-identical semantic transcripts under opposite document
open orders. The D seed remains absent.

SH-13/SH-14 establish OpenC implementation authority, bounded phase evidence,
competitive performance for the former already-validated C/TinyCC path, exact
incremental dependency behavior, and 20 consecutive byte-identical closures.
SH-15 passes 25/25 Microsoft x64 ABI, LLP64, encoder, relocation, and unwind
checks. SH-16 passes 34/34 direct PE32+, CRT-free runtime, import, relocation,
TLS, unwind, heap, file, and execution checks. SH-17 and SH-18 pass their raw
WinMD projection and twelve friendly Windows-module gates.

SH-19 makes that first-party backend compiler-capable. The normal public build
directly lowers OpenC to x64 and writes PE32+ without generated C, TinyCC, D,
Python, a C runtime, an assembler, or an external linker. The 116-source
compiler reaches a byte-identical fixed point; 63/63 lowering/runtime checks,
6/6 memory guards, 278/278 conformance, 4/4 maintained programs, and all 20
standalone release checks pass. The package contains no C, C-header, D,
Python, or TinyCC payload and imports no Microsoft CRT.

This closes the SH-19 independence gate but not the compilation-speed goal.
The fully validating public self-build still takes 109.328 seconds, including
97.828 seconds in semantic validation. SH-20 public throughput convergence is
therefore the next mandatory engineering milestone; OpenC-native replacement
of the external Python evidence workflows follows in SH-21. Linux and
freestanding verification remain optional future scope.

The SH-6 268-fixture package count is the immutable RC8 historical result.
RC9 completes the mandatory successor gate: the relocated package executes the
current 278-fixture corpus plus all 4 maintained programs before owner
authorization. The verified set is published as `v1.0.0-rc.9`.
