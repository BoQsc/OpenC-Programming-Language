# OpenC 1.0.0 publication status

Status: **ENGINEERING READY; OWNER AUTHORIZATION, TAG, AND PUBLICATION PENDING**

SH-25 freezes the Windows x86-64 Hosted final candidate at version `1.0.0`.
The native finalization audit passes 44/44, the fixed-point compiler is
byte-identical, the VSIX package is byte-reproducible, and a real clean-profile
VS Code run passes activation, server, diagnostics, cleanup, and memory guards.

The final `v1.0.0` tag does not exist and no final 1.0 release assets have been
published. SH-26 requires explicit project-owner authorization before either
action. Detached signatures remain optional because no public signing key has
been established.

## Latest published release

The latest public release remains the immutable `v1.0.0-rc.9` prerelease:

- source commit: `0535ad08bd54e74e76a3879d57afb4f1bd0f9835`
- tag: `v1.0.0-rc.9`
- authorized: `2026-07-26T15:06:20Z`
- published: `2026-07-26T15:09:50Z`
- standalone SHA-256:
  `c215e8c5b0847657573204e19493f54c71d2c5ad8c3a95fe1523f21f1bc66344`
- published release-record SHA-256:
  `55debf4571c23648a09c1069b74ea30a589abf0c1b81a6d4577e89802dc3190a`
- release: `https://github.com/BoQsc/OpenC-Programming-Language/releases/tag/v1.0.0-rc.9`
- remote audit: 14/14 assets uploaded with matching sizes and SHA-256 digests

The public `v1.0.0-rc.8` record also remains immutable. Finalization does not
rewrite or relabel either historical release candidate.
