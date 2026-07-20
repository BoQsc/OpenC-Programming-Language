# Internal Review Corrections Integrated in IR1

The internal adversarial pre-freeze review found 23 issues. IR1 integrates every immediate P0/P1/P2 correction into one candidate revision.

Notable corrections include:

- normative operator precedence;
- exact construct target and placement rules;
- safe no-fail cleanup wrappers with internal proven unsafe implementation;
- representation byte-write restrictions;
- code-point-explicit lexical grammar;
- deterministic maximal-munch and word classification;
- scope argument grammar/prose agreement;
- complete switch and loop algorithms;
- uniform literal defaults;
- portable source-span coordinates;
- closed type-query and address-of domains;
- corrected no-UB wording;
- exact BOM behavior;
- closed wrapping/saturating intrinsic set;
- expanded terminology;
- const-field and pointer-binding clarification;
- case-complete grammar coverage.

PF-022 remains a required independent usability review rather than a semantic correction. The strict status/out model is retained pending that review.
