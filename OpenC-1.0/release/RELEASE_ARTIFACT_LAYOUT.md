# Core 1.0 Release Artifact Layout

```text
OpenC-Core-1.0-standard.zip
OpenC-Core-1.0-standard.md
OpenC-Core-1.0-grammar.ebnf
OpenC-Core-1.0-rule-index.json
OpenC-Core-1.0-diagnostics.json
OpenC-Core-1.0-rationale.md
OpenC-Core-1.0-security.md
OpenC-Core-1.0-conformance.zip
OpenC-Core-1.0-reference-source.zip
OpenC-Core-1.0-implementation-evidence.json
OpenC-Core-1.0-conformance-report.json
OpenC-Hosted-1.0.0-rc.8-windows-x86_64-standalone.zip
OpenC-Core-1.0-SHA256SUMS.txt
OpenC-Core-1.0-release-record.json
signatures/ (optional)
```

Hosted, Freestanding, Native, Tooling, and Concurrent artifacts use separate names and claims.

The initial supported reference-implementation claim is Windows x86-64 Hosted.
Artifacts for experimental components must not reuse that support claim.

`SHA256SUMS.txt` covers every payload artifact other than itself. The release
record carries the digest of every payload plus `SHA256SUMS.txt`; the release
record is not recursively required to hash itself. Its identity is fixed by the
authorized Git commit/tag and the hash reported by the release verifier.
