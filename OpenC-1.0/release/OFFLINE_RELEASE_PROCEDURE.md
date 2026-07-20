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
produce release record and checksums
authorize and sign through the locally declared authority
copy immutable artifacts to publication media
```

A remote forge may mirror artifacts but is not the authority. The signed release record and immutable artifact hashes are authoritative.
