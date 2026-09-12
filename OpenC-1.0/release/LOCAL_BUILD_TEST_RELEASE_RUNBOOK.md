# Local Build, Test, and Release Runbook

No remote repository is required.

This is the SH-21 OpenC-native runbook. A previous OpenC compiler owns required
build, test, validation, benchmark, audit, archive creation, and relocated
release verification. Python, D, C, and TinyCC are optional historical or
differential-audit tools only; see
`compiler/selfhost/SH21_COMPLETION_EVIDENCE.md`.

Before generating `MANIFEST.sha256`, run
`python scripts/update_authority_index.py` so every authoritative byte count and
hash corresponds to the candidate tree.

Place a pinned previous `openc.exe` on the path or invoke it by absolute path:

```text
PATH/TO/openc.exe version
PATH/TO/openc.exe target
```

Use `openc workflow --mode=daily --root=. --output=REPORT.json` for ordinary
work and `openc workflow --mode=full --root=. --output=REPORT.json` for forced
conformance, exact 20-build closure, and performance/RAM gates. The required
release path is:

```text
openc release --root=. --output=build-output/release-native
```

The D comparison oracle is not part of these commands. It is available only
through `python scripts/windows_native_workflow.py audit-seed`.

1. Verify the source-package manifest and checksums.
2. Validate the authoritative standard, grammar, rule index, and schemas.
3. Build the implementation with a recorded toolchain.
4. Execute implementation gates I0–I5 in order.
5. Execute the complete conformance matrix.
6. Build and run all maintained programs on the declared Windows x86-64 target.
7. Complete the internal maintainer grammar, semantic, security, and usability review.
8. Resolve all known P0/P1 findings and rerun affected evidence.
9. Generate standard, rationale, diagnostic, and API books.
10. Create deterministic source and binary archives.
11. Run `openc release`; it builds two archive pairs, compares their bytes,
    extracts the standalone into a neutral directory, and executes the native
    relocated-package verifier.
12. Generate mandatory SHA-256 checksums and any optional detached signatures.
    Use `release/build_release_artifacts.py` twice with the same explicit
    release commit and authorization timestamp, then require
    `release/verify_release_artifacts.py` to report byte equality.
13. Verify the committed legal/governance authorization.
14. Mark artifacts RELEASE_READY only after every required gate passes.
15. Publish immutable artifacts and then mark RELEASED.

A script existing is not evidence that a gate ran. Every executed gate retains commands, versions, hashes, results, and failures.

Independent third-party review is recommended post-release assurance work for
1.0 and does not block the owner-maintained initial publication.
