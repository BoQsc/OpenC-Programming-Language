# Release authorization and integrity

The OpenC project owner controlling the canonical source tree is the release
approver, release operator, checksum authority, and publication authority.

For the 1.0 line, authorization requires:

1. every required gate for the declared release scope is recorded as passing;
2. deterministic artifacts are generated twice and compare byte-for-byte;
3. every artifact is listed with a SHA-256 digest in the release record;
4. the owner changes the release record from `CANDIDATE` to `AUTHORIZED`;
5. published artifacts are immutable and match the authorized digests.

The SHA-256 release record is the mandatory integrity mechanism. Detached
cryptographic signatures may be added when the owner records a public key, but
they are optional and their absence does not block OpenC 1.0.

Publication is a distinct act. A tree or archive may be `RELEASE_READY` without
being `RELEASED` or published.
