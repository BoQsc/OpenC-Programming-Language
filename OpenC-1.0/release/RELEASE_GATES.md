# Core 1.0 Release Gates

```text
G1 semantic owner decisions ratified                 PASS except HD-012 legal/governance
G2 independent grammar review                        PENDING
G3 independent semantic review                       PENDING
G4 independent security review                       PENDING
G5 implementation I0–I5                              PASS on recorded Windows host
G6 complete authored fixture execution               PASS 268/268; 93 edition-compatibility matches
G7 maintained real programs                          PASS locally 4/4; native Linux target pending
G8 documentation/usability review                    PENDING
G9 deterministic clean rebuilds                      PASS locally; source archive rebuilt twice
G10 license/governance/signing/publication authority PENDING
```

No release candidate is created while G2–G8 contain unresolved P0/P1 findings. No public release is authorized until G10 is complete.

G6 records execution of the complete authored fixture manifest, not complete coverage of every active Current rule. The 93 compatibility matches are explicit translations from historical OpenC 0.10 fixture rule IDs and are not exact Current-taxonomy matches.
