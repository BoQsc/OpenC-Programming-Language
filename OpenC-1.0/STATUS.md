# OpenC canonical mainline status

```text
version:                            1.0.0-rc.6
canonical development tree:         YES
release scope:                      WINDOWS X86-64 HOSTED

Core specification:                 1.0 RELEASE-CANDIDATE AUTHORITY
Hosted specification:               1.0 RELEASE-CANDIDATE AUTHORITY
Linux/freestanding/Native sources:   EXPERIMENTAL; OUT OF 1.0 SUPPORT SCOPE

canonical D compiler source:         SOURCE-COMPLETE; BUILT AND TESTED
informative Python bootstrap source: SOURCE-COMPLETE; TESTED
official OpenC source extension:      .p; 281 MIGRATED, 286 TOTAL `.p` SOURCES
compiler-in-OpenC lexer:              SH-2A/SH-2B PASS; 302/302 EXACT PARITY
compiler-in-OpenC parser:             SH-2C PASS; 301/301 EXACT PARITY
project/module frontend:              SH-2D PASS; 22/22 EXACT PARITY
full syntactic/project frontend:      SH-2 PASS
self-hosting next milestone:           SH-3 SEMANTIC/IR PARITY
self-hosted compiler:                 NO; SH-3 THROUGH SH-4 PENDING
DMD-independent standalone compiler: NO; SH-5 THROUGH SH-6 PENDING
runtime and Hosted library source:   SOURCE-COMPLETE; WINDOWS EXECUTED
first-party tool source:             SOURCE-COMPLETE; BUILT AND TESTED
build/test/release source:           SOURCE-COMPLETE; EXECUTED

D targets compiled/linked:           9/9 DEBUG; 9/9 RELEASE ON WINDOWS
implementation tests:               8/8 D COMMANDS; 4/4 PYTHON TESTS
conformance fixtures:                268/268 PASS; 0 INFRASTRUCTURE FAILURES
diagnostic matching:                 EXACT CURRENT EXPECTATIONS; 0 COMPATIBILITY
runtime fixtures:                    35/35 BUILT AND EXECUTED
maintained programs:                 4/4 CHECKED, BUILT, AND RUN
active rules with dedicated fixture: 331/466
dedicated-fixture backlog:           135 ACTIVE RULES, DISCLOSED/NONBLOCKING
dedicated grammar-production pairs: INCOMPLETE, DISCLOSED/NONBLOCKING

Windows behavior verified:           YES, WITH LOCAL RECORDED TOOLCHAIN
standalone C providers compiled:     NO; OUTSIDE CLAIMED 1.0 IMPLEMENTATION
Linux/freestanding verified:         NO; OPTIONAL FUTURE TARGETS
independent third-party review:       NOT PERFORMED; RECOMMENDED/NONBLOCKING
maintainer release review:            PASS; NO OPEN P0/P1 FINDINGS

licensing/governance:                HD-012 RATIFIED
software license:                    0BSD
specification/docs/assets:           CC0-1.0
release authority:                   OPENC PROJECT OWNER
formal release ready:                YES FOR DECLARED WINDOWS HOSTED SCOPE
published/released:                  NO
```

`RELEASE_READY` means the declared local gates pass and artifacts may be
presented to the project owner for publication. It does not mean published,
independently certified, or verified on targets outside the declared scope.
