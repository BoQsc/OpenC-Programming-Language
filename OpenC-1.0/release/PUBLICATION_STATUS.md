# OpenC 1.0.0 publication status

Status: **OWNER AUTHORIZED; TAGGED; PUBLISHED; 15/15 ASSETS VERIFIED**

The project owner authorized final publication at `2026-09-13T16:29:48Z`.
The hash-locked GitHub Actions workflow rebuilt the compiler to its exact
OpenC fixed point, passed the 19/19 native workflow and 278/278 conformance
corpus, reproduced the release set twice, and published the final release.

## Final published release

- source commit: `d0f77f6268154ac06f4206c01cd349b226b53c1b`
- annotated tag: `v1.0.0`
- published: `2026-09-13T17:08:01Z`
- release-record SHA-256:
  `0b7cdd6620bb9155651da8ab0e07f2eeae510295f7e7a40eed8f4a4f835a6467`
- standalone SHA-256:
  `f1f07b1e5c34d8a5fbbf70f89b8f117e6d2d1a20fae5d3c200a018d3e4e11f01`
- source archive SHA-256:
  `cd5a3dea4642e9587fa3a403ad07214915853e2916386698d2b4e344db4a69db`
- VSIX SHA-256:
  `081ff8dd6de0960b1981620b3151fbaf74bb12ce73f17afc78e32d38777c3828`
- release:
  `https://github.com/BoQsc/OpenC-Programming-Language/releases/tag/v1.0.0`
- workflow:
  `https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/34770148453`
- remote audit: 15/15 assets downloaded with matching byte counts and SHA-256
  digests

The workflow uses a pinned previous OpenC compiler only to rebuild the current
compiler. D, TinyCC, generated C, an assembler, and an external linker are not
invoked. Detached signatures remain optional because no public signing key has
been established.

The immutable RC8 and RC9 release-candidate records remain historical releases
and are not rewritten or relabelled. Independent review remains invited and
none is claimed. Linux and freestanding remain optional future targets.
