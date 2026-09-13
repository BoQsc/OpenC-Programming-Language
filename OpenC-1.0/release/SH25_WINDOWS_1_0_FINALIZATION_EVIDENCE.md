# OpenC 1.0 Windows finalization evidence

Status: **RELEASE-READY; NOT YET TAGGED OR PUBLISHED**

SH-25 freezes the Windows x86-64 Hosted 1.0 candidate and its packaged editor.
The authoritative measurements and review state are recorded in
`compiler/selfhost/SH25_COMPLETION_EVIDENCE.md`,
`review/SH25_WINDOWS_EDITOR_EVIDENCE.json`, and
`review/SH25_REVIEW_INTAKE.json`.

The candidate passes the 44/44 OpenC-native finalization audit. Its VSIX is
byte-reproducible, embeds the exact final fixed-point compiler, and passes an
actual clean-profile VS Code activation/server/diagnostics run with explicit
memory guards. Compiler children retain the 64 MiB working-set gate; archive
package/finalization children are separately bounded at 96 MiB so deterministic
verification cannot be terminated midway while still remaining supervised.

Licensing remains 0BSD for code and CC0-1.0 for dedicated visual/creative
assets. Linux and freestanding remain optional future targets. The 93
historical rule-ID compatibility matches remain disclosed.

Publication authority is unchanged: only the project owner may authorize the
`v1.0.0` tag and public release. The most recent published release remains
`v1.0.0-rc.9` until that separate SH-26 action occurs.
