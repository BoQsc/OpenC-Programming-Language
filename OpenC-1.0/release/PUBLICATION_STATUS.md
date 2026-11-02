# OpenC publication status

Current release: **1.0.1 OWNER AUTHORIZED, TAGGED, PUBLISHED; SH-27 COMPLETE**.

The owner authorized candidate artifact `13174846904` from run `41512757985`
at `2026-11-02T20:41:04Z`. Publication occurred at `2026-11-02T20:46:07Z`.
All 16 public assets (121,829,675 bytes) match their approved SHA-256 digests.
Both the local release-ID completion and hosted publication workflow independently
downloaded and verified them. The immutable 1.0.0 tag and all 15 assets were
verified before and after publication.

- Release/tag: [v1.0.1](https://github.com/BoQsc/OpenC-Programming-Language/releases/tag/v1.0.1)
- Release commit: `06cdba3e0e4ba5e2539e45bd7f7d142d532347b4`
- Compiler SHA-256: `7c6f7bbaa5b9ed737a23c5779c560e54e0954d51f8756c412aad7f5ab05d42f5`
- Release-record SHA-256: `e6e0b1fbdd07941d3999080a09595e15acf9d62b968a6748f41bdd5474c1b4df`
- Standalone SHA-256: `7f4a786b5b9b84ab34f912f5df42d9aa246e31afad82f39be0afb2d9f8ab6d3f`
- Source SHA-256: `15b0905884fd4e0da0060b814fa20b01e205d865320d1e0b244cd5bd80cc27f4`
- VSIX SHA-256: `fe156d1f1b3bb98f9901eb4198f234a990481ee3863af0dc09b5ae61652e63a5`
- Publication audit: [41521487125, attempt 2](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/41521487125/attempts/2)
- Durable evidence: repository `.github/release-evidence/v1.0.1/publication.json`
  and its authenticated verification ZIP.

The first publication job created the draft but its tag lookup returned 404
for an unpublished draft. Completion used the release-ID API with the owner's
existing authorization, verified every draft byte before publishing, and
verified every public byte afterwards. The workflow's independent audit then
passed. The draft-lookup fix is a later source commit; release payloads and
tags remain unchanged. Independent review remains invited and unclaimed.

## Immutable 1.0.0 publication history

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
