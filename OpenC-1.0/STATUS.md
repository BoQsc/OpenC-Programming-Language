# OpenC canonical mainline status

```text
version:                            1.0.0-rc.8
canonical development tree:         YES
release scope:                      WINDOWS X86-64 HOSTED

Core specification:                 1.0 RELEASE-CANDIDATE AUTHORITY
Hosted specification:               1.0 RELEASE-CANDIDATE AUTHORITY
Linux/freestanding/Native sources:   EXPERIMENTAL; OUT OF 1.0 SUPPORT SCOPE

canonical D compiler source:         SOURCE-COMPLETE; BUILT AND TESTED
informative Python bootstrap source: SOURCE-COMPLETE; TESTED
official OpenC source extension:      .p; 281 MIGRATED, 373 TOTAL `.p` SOURCES
compiler-in-OpenC lexer:              SH-2A/SH-2B PASS; 304/304 EXACT PARITY
compiler-in-OpenC parser:             SH-2C PASS; 303/303 EXACT PARITY
project/module frontend:              SH-2D PASS; 22/22 EXACT PARITY
full syntactic/project frontend:      SH-2 PASS
declaration/symbol/type tables:       SH-3A PASS; 17/17 EXACT PARITY
name/constant/overload resolution:    SH-3B PASS; 10/10 EXACT PARITY
flow/safety semantics:                SH-3C PASS; 232 SEMANTIC COMPARISONS
semantic outcomes/canonical IR:       SH-3D PASS; 149 REJECT + 117 IR MATCHES
full semantic/IR pipeline:            SH-3 PASS; 33/33 REACHABLE IR OPCODES
bootstrap D-source backend:           SH-4A PASS; 4 PROJECTS, 28/28 FILES EXACT
stage-1 self-compilation:             SH-4B PASS; STAGE 1 BUILDS STAGE 2
bootstrap closure:                    SH-4C PASS; STAGE 2/STAGE 3 STABILIZED
self-hosted compiler:                 YES; SH-6 PASS, STANDALONE WINDOWS
self-hosting next milestone:          POST-SH-6 PUBLICATION/PERFORMANCE
DMD-independent self-host compiler:  YES; PUBLIC `openc build`, VENDORED TCC
standalone compiler distribution:    YES; RELOCATABLE, REPRODUCIBLE, VERIFIED
runtime and Hosted library source:   SOURCE-COMPLETE; WINDOWS EXECUTED
first-party tool source:             SOURCE-COMPLETE; BUILT AND TESTED
build/test/release source:           SOURCE-COMPLETE; EXECUTED

D targets compiled/linked:           9/9 DEBUG; 9/9 RELEASE ON WINDOWS
implementation tests:               8/8 D COMMANDS; 4/4 PYTHON TESTS
conformance fixtures:                268/268 PASS; 0 INFRASTRUCTURE FAILURES
diagnostic matching:                 EXACT CURRENT; PRIOR 93 COMPATIBILITY DISCLOSED
runtime fixtures:                    35/35 BUILT AND EXECUTED
maintained programs:                 4/4 CHECKED, BUILT, AND RUN
active rules with dedicated fixture: 331/466
dedicated-fixture backlog:           135 ACTIVE RULES, DISCLOSED/NONBLOCKING
dedicated grammar-production pairs: INCOMPLETE, DISCLOSED/NONBLOCKING

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
published/released:                  NO
```

`RELEASE_READY` means the declared local gates pass and artifacts may be
presented to the project owner for publication. It does not mean published,
independently certified, or verified on targets outside the declared scope.
