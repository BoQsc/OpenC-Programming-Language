# OpenC canonical mainline status

```text
version:                            1.0-dev.3-verification
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
conformance fixtures:                268 AUTHORED; FULL-RULE COVERAGE INCOMPLETE

canonical D targets compiled:        YES; DEBUG AND RELEASE ON WINDOWS
canonical D targets linked:          YES; DEBUG AND RELEASE ON WINDOWS
standalone C providers compiled:     NO; C TOOLCHAIN UNAVAILABLE
implementation tests executed:      YES; 8 OF 8 D COMMANDS PASSED
conformance fixtures executed:       YES; 29 PASS, 203 FAIL, 36 INFRASTRUCTURE
maintained programs accepted:        0 OF 4
maintained programs built/run:       0 OF 4
Linux behavior verified:            NO
Windows behavior verified:          NO; LOCAL BUILD/TEST EVIDENCE ONLY
freestanding behavior verified:     NO
independent review:                  PENDING
licensing/governance:                HD-012 PENDING
release ready:                       NO
published:                           NO
```

`SOURCE-COMPLETE BY INVENTORY` means every source file named by `SOURCE_COMPLETENESS_CONTRACT.json` exists and contains authored implementation. The executed build and test evidence is narrower than platform or language conformance and does not imply the implementation is safe to deploy.

See `VERIFICATION_STATUS.md` for the current evidence boundary and `SOURCE_COMPLETE_BUT_UNVERIFIED.md` for the original handoff boundary.
