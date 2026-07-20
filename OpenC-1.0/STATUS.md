# OpenC canonical mainline status

```text
version:                            1.0-dev.4-conformance
canonical development tree:         yes
Core specification:                 AUTHOR-FINAL DEVELOPMENT BASELINE
Hosted specification:               AUTHOR-FINAL SOURCE-HANDOFF BASELINE
Freestanding specification:         AUTHOR-FINAL SOURCE-HANDOFF BASELINE
Native specification:               AUTHOR-FINAL SOURCE-HANDOFF BASELINE
Tooling specification:              AUTHOR-FINAL SOURCE-HANDOFF BASELINE

canonical D compiler source:         SOURCE-COMPLETE BY INVENTORY
informative Python bootstrap source: SOURCE-COMPLETE BY INVENTORY
runtime implementation source:       SOURCE-COMPLETE BY INVENTORY
Hosted library source:               SOURCE-COMPLETE BY INVENTORY
first-party tool source:             SOURCE-COMPLETE BY INVENTORY
build/test/release source:           SOURCE-COMPLETE BY INVENTORY
conformance fixtures:                268 EXECUTED PASS; FULL-RULE COVERAGE INCOMPLETE

canonical D targets compiled:        YES; 9/9 DEBUG AND 9/9 RELEASE ON WINDOWS
canonical D targets linked:          YES; DEBUG AND RELEASE ON WINDOWS
standalone C providers compiled:     NO; C TOOLCHAIN UNAVAILABLE
implementation tests executed:      YES; 8/8 D COMMANDS AND 4/4 PYTHON TESTS PASSED
conformance fixtures executed:       YES; 268 PASS, 0 FAIL, 0 INFRASTRUCTURE
historical rule compatibility:       93 EXPLICIT EDITION-ID MATCHES; 175 EXACT/NATIVE
runtime fixtures built/run:          YES; 35/35
maintained programs accepted:        4/4
maintained programs built/run:       4/4 ON WINDOWS BOOTSTRAP HOST
Linux behavior verified:             NO
Windows behavior verified:           LOCAL D BUILD/TEST/RUNTIME EVIDENCE ONLY
freestanding behavior verified:      NO
independent review:                  PENDING
licensing/governance:                HD-012 PENDING
engineering conformance milestone:   YES FOR COMPLETE AUTHORED EXECUTABLE MANIFEST
formal release ready:                NO; EXTERNAL REVIEW/AUTHORITY GATES PENDING
published:                           NO
```

`SOURCE-COMPLETE BY INVENTORY` means every source file named by `SOURCE_COMPLETENESS_CONTRACT.json` exists and contains authored implementation. Passing the complete authored executable manifest is strong local implementation evidence, but it is not complete active-rule coverage or verification on untested targets.

See `VERIFICATION_STATUS.md` for the evidence boundary and `release/RELEASE_GATES.md` for the remaining release-authority work.
