# Maintainer Guide

A normative change is atomic. It updates together:

```text
standard wording
grammar when syntax changes
rule index
diagnostic catalog
term index
security model
rationale
conformance obligations
compatibility/change record
authority hashes
```

Rule IDs are stable. A changed meaning receives an explicit compatibility event; a split or retired rule retains successor links. Experimental or implementation-specific behavior never silently enters plain Core.
