
# CC2 Correction 001 — Grammar production coverage

## Classification

```text
change class: correction
normative grammar change: none
semantic rule change: none
source compatibility impact: none
conformance metadata impact: yes
validator impact: yes
```

## Defect

The normative EBNF contains 166 unique productions. The original CC2 validator
matched only lowercase production identifiers and therefore omitted the lexical
production `ASCII_letter`. The grammar coverage record and status documents
reported 165 productions.

## Correction

- count production identifiers using `[A-Za-z_][A-Za-z0-9_]*`;
- add `ASCII_letter` to grammar coverage in normative order;
- report 166 productions in status and evidence documents;
- regenerate authority hashes, validation evidence, and the candidate manifest.

This correction does not change the accepted OpenC source language.
