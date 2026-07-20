# Local Build, Test, and Release Runbook

No remote repository is required.

1. Verify the source-package manifest and checksums.
2. Validate the authoritative standard, grammar, rule index, and schemas.
3. Build the implementation with a recorded toolchain.
4. Execute implementation gates I0–I5 in order.
5. Execute the complete conformance matrix.
6. Build and run all maintained programs on every claimed target.
7. Complete independent grammar, semantic, security, and usability reviews.
8. Resolve all P0/P1 findings and rerun affected evidence.
9. Generate standard, rationale, diagnostic, and API books.
10. Create deterministic source and binary archives.
11. Extract archives into a clean directory and reverify all manifests.
12. Generate checksums and signatures.
13. Complete legal/governance authorization.
14. Mark artifacts RELEASE_READY only after every required gate passes.
15. Publish immutable artifacts and then mark RELEASED.

A script existing is not evidence that a gate ran. Every executed gate retains commands, versions, hashes, results, and failures.
