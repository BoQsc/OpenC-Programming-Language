
# Release source and operations

A release is generated from one recorded state of the canonical tree. Release archives are never edited as development sources.

The release process must distinguish:

```text
source release       complete canonical source snapshot
binary/tool release  compiled artifacts and runtime packages
design-history archive  optional non-normative historical collection
```

OpenC 1.0 uses the Windows x86-64 Hosted scope in `RELEASE_SCOPE_1.0.md`.
Licensing/governance is ratified and all required candidate gates pass.
`RELEASE_READY` authorizes artifact preparation; only a subsequent owner
publication act marks an immutable artifact `RELEASED`.
