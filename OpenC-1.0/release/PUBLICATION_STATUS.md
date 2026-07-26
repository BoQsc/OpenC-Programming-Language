# OpenC 1.0.0-rc.8 publication status

Status: **OWNER-AUTHORIZED AND PUBLICLY TAGGED; RELEASE ASSET UPLOAD PENDING**

The project owner authorized the deterministic Core and Windows Hosted
artifact set on 2026-07-26 at 09:17:49 UTC.

```text
release commit:
aa8a247c7eac95d64ea9ef1a5e4bf325d1ccce3c

public tag:
v1.0.0-rc.8

owner authorization record SHA-256:
f01b56e962dc8eabb1e7d5d42de2a4c3509a3d03a0d949ee4cb7366ea3e978c4

artifact count:
13
```

The tag is published to
`https://github.com/BoQsc/OpenC-Programming-Language/tree/v1.0.0-rc.8`
and resolves to the recorded commit. The GitHub release page itself does not
yet exist because no release-asset upload endpoint was available to the
operator environment. Accordingly, `published` and `released` remain false;
the repository does not misrepresent a tag as completed artifact publication.

Two independent artifact builds compare byte-for-byte and pass
`release/verify_release_artifacts.py`. The authorized files and
machine-readable verification report are under:

```text
build-output/release/OpenC-1.0.0-rc.8-authorized-a/
build-output/release/OpenC-1.0.0-rc.8-authorized-b/
build-output/release/OpenC-1.0.0-rc.8-authorized-verification.json
```

Mandatory checksums are in
`OpenC-Core-1.0-SHA256SUMS.txt` inside either artifact directory. Detached
signatures remain optional because no public signing key has been established.

The next operator action is to create a GitHub prerelease for
`v1.0.0-rc.8`, attach every file from the authorized artifact directory, and
only then mark the project `published` and `released`.
