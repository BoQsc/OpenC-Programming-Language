# Local Build, Test, and Release Runbook

No remote repository is required.

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
11. Extract archives into a clean directory and reverify all manifests.
12. Generate mandatory SHA-256 checksums and any optional detached signatures.
13. Verify the committed legal/governance authorization.
14. Mark artifacts RELEASE_READY only after every required gate passes.
15. Publish immutable artifacts and then mark RELEASED.

A script existing is not evidence that a gate ran. Every executed gate retains commands, versions, hashes, results, and failures.

Independent third-party review is recommended post-release assurance work for
1.0 and does not block the owner-maintained initial publication.
