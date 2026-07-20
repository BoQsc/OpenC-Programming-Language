# Offline Release Procedure

The release operator works from one verified source archive in a clean directory with network access disabled where possible.

```text
verify input checksums and signatures
extract to a clean root
run specification and schema validators
build recorded implementation toolchains
execute all required conformance and real-program gates
regenerate books, indexes, reports, and manifests
build deterministic source/binary archives twice
compare hashes
extract each archive and verify its internal manifest
produce release record and mandatory SHA-256 checksums
authorize through the locally declared owner authority
optionally add detached signatures when a public key is recorded
copy immutable artifacts to publication media
```

A remote forge may mirror artifacts but is not the authority. The
owner-authorized release record and immutable artifact hashes are authoritative.
