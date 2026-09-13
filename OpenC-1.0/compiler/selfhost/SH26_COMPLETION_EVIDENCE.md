# SH-26 completion evidence

Status: **PASS — OWNER-AUTHORIZED OPEN C 1.0.0 RELEASE PUBLISHED**

The project owner authorized final publication on 2026-09-13. Commit
`d0f77f6268154ac06f4206c01cd349b226b53c1b` added the hash-locked GitHub
release workflow and the release-intent record. GitHub Actions then completed
every build, verification, deterministic packaging, evidence-retention, and
publication step successfully.

The annotated `v1.0.0` tag resolves exactly to that commit. The ordinary,
non-prerelease GitHub release was published at `2026-09-13T17:08:01Z` with 15
assets. The workflow streamed every published asset back from GitHub and
verified its byte count and SHA-256 digest before reporting success.

The clean runner used the exact SH-25 OpenC compiler only as the previous
OpenC bootstrap seed. It rebuilt the compiler to the authorized
`eadbef1f…c191087` fixed point before executing the 19/19 native workflow,
278/278 conformance corpus, two deterministic archive builds, relocated
release checks, and deterministic VSIX packaging. D, TinyCC, generated C, an
assembler, and an external linker were not invoked. Python was limited to
GitHub release orchestration and remote publication verification.

The release is public at:
`https://github.com/BoQsc/OpenC-Programming-Language/releases/tag/v1.0.0`.
The successful workflow is at:
`https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/34770148453`.

Independent review remains invited and none is claimed. Linux and
freestanding remain optional future scopes. SH-27 owns public-download
verification, review/errata intake, and broader production C/D comparator
work without changing the frozen 1.0 artifacts.
