# Local Build, Test, and Release Runbook

No remote repository is required.

Before generating `MANIFEST.sha256`, run
`python scripts/update_authority_index.py` so every authoritative byte count and
hash corresponds to the candidate tree.

Install or confirm the verified OpenC-native toolchain:

```text
python scripts/native_toolchain.py install --distribution PATH/TO/DISTRIBUTION
python scripts/native_toolchain.py status
```

Use `python scripts/windows_native_workflow.py daily` for ordinary work and
`python scripts/windows_native_workflow.py full` for the forced validation and
self-rebuild budget gate. The required release path is:

```text
python release/windows_native_release.py --force
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
11. Run `release/windows_native_release.py`; it builds two archives, compares
    their bytes, extracts one into a foreign working directory, and executes
    the complete native relocated-package verifier.
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
