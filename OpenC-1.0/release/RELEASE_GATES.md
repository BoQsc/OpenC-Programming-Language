# OpenC 1.0 release gates

Required gates for the declared Windows x86-64 Hosted scope:

```text
G1  owner semantic decisions HD-001 through HD-012       PASS
G2  grammar/structure maintainer audit and validators     PASS
G3  semantic implementation tests and conformance suite  PASS
G4  safety/security regression suite and boundary review PASS
G5  implementation I0-I5 debug/release builds            PASS 9/9 + 9/9
G6  complete authored conformance manifest               PASS 268/268; exact
G7  maintained programs on claimed target                PASS 4/4 WINDOWS
G8  maintainer documentation/usability release review    PASS
G9  deterministic clean source rebuild/archive checks    PASS
G10 licensing/governance/checksum/publication authority  PASS
```

There are no open P0/P1 findings in the maintainer release review. Independent
third-party grammar, semantic, security, and usability reviews remain strongly
recommended, but they are post-release assurance work and not mandatory for the
owner-maintained initial 1.0 release.

Linux, freestanding, Native, standalone C providers, script/live, and
Concurrent sources are outside the claimed 1.0 implementation scope. Their
verification cannot fail a Windows Hosted release gate.

G6 covers the entire authored 268-fixture manifest with zero compatibility
fallback in the current run; the former 93 historical rule-ID compatibility
matches remain disclosed in `CHANGELOG.md`. Dedicated fixtures cover 331 of
466 active Core rules; the remaining
135-rule authoring backlog is disclosed and tracked but is not a release gate.
The normative rules remain binding regardless of dedicated-fixture presence.
Likewise, the parser and grammar validators pass even though dedicated
positive/rejection pairs are not complete for every one of the 174 productions.

The `.p` source-convention gate, executable SH-1 compiler-in-OpenC seed, SH-2A
exact lexer-parity subgate, SH-2B owned single-pass lexer-state subgate, SH-2C
exact parser-parity subgate, SH-2D project/module subgate, and full syntactic
and project frontend SH-2 gate pass. SH-3A declaration, symbol, and type-table
parity also passes. SH-3B name/constant/overload, SH-3C flow/safety, and SH-3D
semantic-outcome/canonical-IR parity pass, completing SH-3. SH-4 bootstrap
self-compilation and closure now pass as well: Stage 1 builds Stage 2
and Stage 2 builds an equivalent Stage 3. SH-5 DMD independence and SH-6
standalone packaging remain future compiler work and do not alter that release
boundary.
