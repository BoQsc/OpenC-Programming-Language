# RC9 standalone release evidence

OpenC `1.0.0-rc.9` is the published Windows x86-64 Hosted release-candidate
refresh. It succeeds the immutable RC8 268-fixture record without modifying
that historical evidence.

## Authority and publication

- source commit:
  `0535ad08bd54e74e76a3879d57afb4f1bd0f9835`
- annotated tag: `v1.0.0-rc.9`
- owner authorization: `2026-07-26T15:06:20Z`
- publication: `2026-07-26T15:09:50Z`
- GitHub release:
  `https://github.com/BoQsc/OpenC-Programming-Language/releases/tag/v1.0.0-rc.9`
- tag-bound authorized release-record SHA-256:
  `3cdd12dcc5eee7c5f4b497ebca829b2641bd0aa916db852a88b6fdbf570c8fe7`
- published release-record SHA-256:
  `55debf4571c23648a09c1069b74ea30a589abf0c1b81a6d4577e89802dc3190a`
- remote audit: 14/14 assets are uploaded and their sizes and GitHub-reported
  SHA-256 digests match the verified local publication set

The annotated tag binds the authorized pre-publication record. The published
record adds the immutable `published_utc` value and `released: true`; the
artifact checksums and release source commit are unchanged.

## Standalone artifacts

Two independent builds produced byte-identical archives:

```text
standalone archive SHA-256: c215e8c5b0847657573204e19493f54c71d2c5ad8c3a95fe1523f21f1bc66344
packaged compiler SHA-256:  5924db13e20464d392dd563a086d35c95c61dafc6862ad7ba0fc767c0cdae4a6
Stage 2 SHA-256:            5924db13e20464d392dd563a086d35c95c61dafc6862ad7ba0fc767c0cdae4a6
Stage 3 SHA-256:            5924db13e20464d392dd563a086d35c95c61dafc6862ad7ba0fc767c0cdae4a6
generated C SHA-256:        28769077f9fa15fe152801a9a9a4e5c2c3faaea71086e79b19b24f58989ed90b
normalized PE SHA-256:      6cbdeae4f0f742c9f1d8652d0b2768b320bfffea240114a54fa275b0a7041331
bootstrap seed SHA-256:     e1641975ccb22f70a7f30b769c3351be24a075d4266b5eb1e993d084f980bf99
TinyCC SHA-256:             e9cb3e89e20a9efead83cc9e6b100314275634c2f705056da71f424ea9b0cdf0
packaged files:             1,169
manifest payload entries:   1,168
```

## Executed gates

- independent standalone archives are byte-identical;
- the internal package manifest is valid;
- the extracted package is relocatable and was verified from a foreign
  working directory;
- the packaged compiler builds Stage 2, and Stage 2 builds Stage 3;
- packaged, Stage 2, and Stage 3 executables are byte-identical;
- generated C and normalized PE artifacts are equal;
- native build records contain no DMD, DUB, or Python invocation;
- exact flow/safety parity passes 240 comparisons;
- canonical IR parity passes 123 comparisons and 153 exact rejection
  comparisons across 273 authored source fixtures;
- all 278 conformance fixtures pass with zero failures and zero infrastructure
  failures;
- all 4 maintained programs build and execute to their authored contracts.

Linux, freestanding, and the authored Native provider are not release gates.
They remain optional future targets.

## Reproduction

```text
python compiler/selfhost/bootstrap.py --output build-output/rc9-dev/bootstrap-full
python compiler/selfhost/bootstrap_windows_closure.py --stage0 compiler/openc.exe --stage1 PREVIOUS_NATIVE_OPENC --use-existing-stage1 --output build-output/rc9-native-closure-final
python release/build_standalone_windows.py --tree . --compiler NATIVE_RC9_OPENC --bootstrap-seed compiler/openc.exe --version 1.0.0-rc.9 --output-tree OUTPUT_TREE --archive OUTPUT_ARCHIVE --force
python release/verify_standalone_windows.py --archive ARCHIVE_A --comparison-archive ARCHIVE_B --output build-output/selfhost-rc9/final-v2 --jobs 8 --force
python release/build_release_artifacts.py --tree . --standalone ARCHIVE_A --sh6-result build-output/selfhost-rc9/final-v2/standalone-release-result.json --conformance-report build-output/selfhost-rc9/final-v2/conformance-report.json --output RELEASE_SET --release-commit 0535ad08bd54e74e76a3879d57afb4f1bd0f9835 --authorized-utc 2026-07-26T15:06:20Z --authorization-status AUTHORIZED --published-utc 2026-07-26T15:09:50Z --force
python release/verify_release_artifacts.py --release RELEASE_SET_A --comparison RELEASE_SET_B --expect-authorized --expect-released
```

## What comes next

The next engineering milestone is **SH-7 native conformance and tooling
independence**. RC9's packaged native compiler is already self-hosting, but the
complete packaged conformance manifest is still executed through the retained
D audit seed. SH-7 will:

1. add a native `openc validate` path, or an equivalent OpenC-authored
   conformance runner, for the full 278-fixture manifest;
2. reproduce exact acceptance, diagnostic, and runtime outcomes through the
   packaged native compiler;
3. remove the retained D seed from the required packaged conformance gate
   while preserving it as an optional audit oracle;
4. retain byte-identical native closure, reproducible archives, and the 4/4
   maintained-program gate.
