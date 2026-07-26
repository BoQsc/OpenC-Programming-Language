
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

The SH-6 Windows standalone package is built by
`build_standalone_windows.py`, used as a relocated self-hosting environment,
and verified by `verify_standalone_windows.py`. Its exact commands, supported
roles, results, and hashes are in `SH6_STANDALONE_EVIDENCE.md`; package-user
instructions are in `STANDALONE_WINDOWS_README.md`.
