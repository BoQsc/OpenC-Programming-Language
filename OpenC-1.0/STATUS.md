# OpenC canonical mainline status

```text
version:                            1.0.0-rc.9
canonical development tree:         YES
release scope:                      WINDOWS X86-64 HOSTED

Core specification:                 1.0 RELEASE-CANDIDATE AUTHORITY
Hosted specification:               1.0 RELEASE-CANDIDATE AUTHORITY
Linux/freestanding/Native sources:   EXPERIMENTAL; OUT OF 1.0 SUPPORT SCOPE

canonical OpenC compiler source:     96 `.p` UNITS; SELF-HOSTED
legacy D reference source:           OPTIONAL AUDIT; NOT AUTHORITY
legacy Python bootstrap source:      OPTIONAL AUDIT; NOT AUTHORITY
official OpenC source extension:      .p; 281 MIGRATED, 395 TOTAL `.p` SOURCES
compiler-in-OpenC lexer:              SH-2A/SH-2B PASS; 304/304 EXACT PARITY
compiler-in-OpenC parser:             SH-2C PASS; 303/303 EXACT PARITY
project/module frontend:              SH-2D PASS; 22/22 EXACT PARITY
full syntactic/project frontend:      SH-2 PASS
declaration/symbol/type tables:       SH-3A PASS; 17/17 EXACT PARITY
name/constant/overload resolution:    SH-3B PASS; 10/10 EXACT PARITY
flow/safety semantics:                SH-3C PASS; RC9 CURRENT 240 COMPARISONS
semantic outcomes/canonical IR:       SH-3D PASS; RC9 153 REJECT + 123 IR MATCHES
full semantic/IR pipeline:            SH-3 PASS; 33/33 REACHABLE IR OPCODES
bootstrap D-source backend:           SH-4A PASS; 4 PROJECTS, 28/28 FILES EXACT
stage-1 self-compilation:             SH-4B PASS; STAGE 1 BUILDS STAGE 2
bootstrap closure:                    SH-4C PASS; STAGE 2/STAGE 3 STABILIZED
self-hosted compiler:                 YES; SH-13 PASS, OPENC IMPLEMENTATION AUTHORITY
self-host performance milestone:     PASS; SH-13 REBUILD 28.5% FASTER THAN SH-12
compiler throughput readiness:       BLOCKING; 500.311 S CLEAN REBUILD IS NOT D/C-CLASS
preliminary D-reference comparison:  25.462 S FORCED RELEASE; FORMAL HARNESS REQUIRED
coverage-granularity milestone:      PASS; 466/466 RULES, 174/174 GRAMMAR PAIRS
native validation budget:            PASS; 32.612 S <= 90 S, 278/278
native self-rebuild budget:          PASS; 500.311 S <= 900 S, BYTE-IDENTICAL
unchanged daily conformance:         PASS; 0.002 S, 0 FIXTURES RE-EXECUTED
public native CLI:                    SH-9 PASS; CHECK/RUN/VERSION/TARGET/EXPLAIN
native project workflow:              SH-10 PASS; FMT/INFO/TEST, 21/21
native language service:              SH-11 PASS; LIFECYCLE/DIAGNOSTICS/FMT, 19/19
native semantic language service:     SH-12 PASS; SYMBOLS/NAV/COMPLETE/RENAME, 23/23
human + machine diagnostics:          PASS; `openc.check.v1` + STABLE STREAMS
completed engineering milestone:     SH-13 THROUGHPUT + IMPLEMENTATION INDEPENDENCE
next engineering milestone:          SH-14 THROUGHPUT CONVERGENCE + STABILITY
SH-14 clean self-rebuild gate:        MEDIAN <=30 S; EVERY RUN <=45 S; 20-RUN CLOSURE
post-SH-14 critical path:             X64 ABI -> PE/RUNTIME -> WINMD -> NATIVE BACKEND
DMD-independent self-host compiler:  YES; PUBLIC `openc build`, VENDORED TCC
standalone compiler distribution:    YES; RELOCATABLE; NO D/PYTHON SOURCE
normal toolchain fully independent:   NO; TINYCC + EXTERNAL PYTHON EVIDENCE REMAIN
runtime and Hosted library source:   SOURCE-COMPLETE; WINDOWS EXECUTED
first-party tool source:             SOURCE-COMPLETE; BUILT AND TESTED
build/test/release source:           SOURCE-COMPLETE; EXECUTED

legacy D audit targets:              9/9 DEBUG; 9/9 RELEASE ON WINDOWS
external evidence tests:            8/8 D AUDITS; 29/29 PYTHON TESTS
conformance fixtures:                NATIVE 278/278 PASS; 0 INFRASTRUCTURE FAILURES
diagnostic matching:                 EXACT CURRENT; PRIOR 93 COMPATIBILITY DISCLOSED
runtime fixtures:                    35/35 BUILT AND EXECUTED
maintained programs:                 4/4 CHECKED, BUILT, AND RUN
active rules with dedicated fixture: 466/466
dedicated-fixture backlog:           0
dedicated grammar-production pairs: 174/174 ACCEPTING + REJECTING

Windows behavior verified:           YES, WITH LOCAL RECORDED TOOLCHAIN
Windows Hosted C providers compiled: YES; SH-5 TINYCC BUILD AND EXECUTION PASS
Linux/freestanding verified:         NO; OPTIONAL FUTURE TARGETS
independent third-party review:       NOT PERFORMED; RECOMMENDED/NONBLOCKING
maintainer release review:            PASS; NO OPEN P0/P1 FINDINGS

licensing/governance:                HD-012 RATIFIED
software license:                    0BSD
specification/docs/assets:           CC0-1.0
vendored TinyCC backend:             LGPL-2.1 + BUNDLED MIT/PUBLIC-DOMAIN TERMS
release authority:                   OPENC PROJECT OWNER
formal release ready:                YES FOR DECLARED WINDOWS HOSTED SCOPE
owner authorization:                 RC9 AUTHORIZED 2026-07-26T15:06:20Z
public release tag:                  v1.0.0-rc.9 -> 0535ad08bd54e74e76a3879d57afb4f1bd0f9835
GitHub release assets:               14/14 UPLOADED; REMOTE DIGEST AUDIT PASS
published/released:                  YES; PRERELEASE PUBLISHED 2026-07-26T15:09:50Z
```

`RELEASE_READY` means the declared local gates pass. Owner authorization,
immutable source tagging, and release-asset publication are distinct actions.
This does not imply independent certification or verification on targets
outside the declared scope.

The RC8 tag and standalone archive remain an immutable 268-fixture historical
release-candidate record. RC9 reproduces the expanded 278-fixture corpus and
native compiler closure from the relocated package and is published at
`https://github.com/BoQsc/OpenC-Programming-Language/releases/tag/v1.0.0-rc.9`.

SH-8 makes the OpenC-native compiler the default Windows Hosted
compiler-under-test, enforces measured validation/rebuild budgets, and skips
unchanged daily corpus work using an exact-input cache. Full and release gates
force fresh native evidence. The retained D seed is only available through the
separate optional audit command. SH-9 adds public native `check`/`run`,
human diagnostics with stable machine records, version/target/rule
explanation, and direct CLI execution of all six demos. SH-10 adds the native
formatter, project inspection, and deterministic test workflows, with all 21
contracts in the relocated standalone gate. SH-11 adds native
`openc lsp --stdio` lifecycle, full-document synchronization, stable rule-ID
diagnostics, SH-10 formatting, and deterministic transcripts, with all 19
contracts in the relocated standalone gate. SH-12 adds a bounded synchronized
project workspace, native symbols, typed hover, definition/references,
name-sorted completion, collision-checked rename, and 23/23 deterministic
project-semantic contracts. SH-13 addresses native build throughput, canonical
OpenC-only implementation authority, and removal of D/Python source from the
standalone compiler, but its 500.311-second clean rebuild remains unacceptable.
SH-14 is now the blocking throughput/stability milestone and no editor or new
platform implementation precedes it. After SH-14, the critical path is the
Windows x64 ABI and machine encoder, CRT-free PE32+ runtime, Win32 Metadata raw
projection, friendly Windows modules, compiler-capable native backend, TinyCC
exit, and OpenC-native replacement of required Python/D tooling. The former
editor-integration milestone is deferred to SH-23. Linux, freestanding, and
ARM64 remain optional later targets.
