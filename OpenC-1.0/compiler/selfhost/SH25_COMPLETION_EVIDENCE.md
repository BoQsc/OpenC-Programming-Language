# SH-25 Windows 1.0 finalization evidence

Status: **PASS**

OpenC now identifies the finalized source and artifact candidate as `1.0.0`.
The 221-source OpenC compiler reaches a byte-identical 7,119,360-byte native
fixed point at
`eadbef1f065261385c2c36d524624347f7e5cd3c021a4a1db9ccfcaf7c191087`.

The native `openc editor-package` command creates a deterministic 9-entry VSIX
without Python, Node/npm, a package registry, or the network. Independent A/B
packages are byte-identical at 7,142,886 bytes with SHA-256
`081ff8dd6de0960b1981620b3151fbaf74bb12ce73f17afc78e32d38777c3828`.
The package embeds the exact fixed-point compiler.

A real VS Code 1.137.0 run used empty user-data and extension directories. It
installed `openc-language.openc@1.0.0`, activated the extension, selected the
packaged compiler, started the native language server, and completed a
diagnostic round trip with no provider failures or unexpected server exits.
The complete VS Code process tree peaked at 1,495,654,400 bytes under its 2 GiB
guard; the OpenC server peaked at 9,289,728 bytes under its 64 MiB guard. The
test process tree was terminated after evidence capture.

The native process supervisor retains the 64 MiB ceiling for compiler work and
uses a separate 96 MiB ceiling only for package/finalization children that must
hold and verify the embedded compiler archive. This resolves the observed
bounded-process termination without removing RAM supervision or weakening the
compiler performance gate.

`openc finalization-audit` passes 44/44 checks, covering deterministic package
identity, clean-profile usability, memory limits, licensing, Windows scope,
review integrity, owner publication authority, and the explicitly disclosed 93
historical rule-ID compatibility matches.

The complete OpenC-native workflow passes 19/19: 5/5 maintained/runtime
programs, 507/507 repository paths, 39/39 pinned hashes, 38/38 residual
contracts, 278/278 conformance fixtures, and 20/20 exact compiler generations.
The fully validating build/validation medians are 12.843/6.282 seconds. Peak
compiler private/working-set memory is 175,710,208/60,731,392 bytes, under the
unchanged 256/64 MiB limits.

The native release proof packages 1,734 planned source entries and 1,443
standalone entries into byte-identical ZIP pairs. A relocated package rebuilds
the same compiler through Stage 2 and Stage 3, passes its 14/14 daily workflow,
38/38 contract audit, 44/44 finalization audit, and 278/278 forced conformance.
The standalone contains no C, D, Python, TinyCC, assembler, external linker, or
Microsoft CRT dependency.

Five external review tracks—grammar, semantics, security, editor, and
release/reproducibility—are openly invited. No independent reviews have been
received, and none are claimed. The internal final review is labelled internal;
the intake currently records no known P0/P1 findings. External review remains
recommended and nonblocking under the established 1.0 policy.

The final 1.0 tag and public release are deliberately not created by SH-25.
Those are the explicit owner-authorized SH-26 action.
