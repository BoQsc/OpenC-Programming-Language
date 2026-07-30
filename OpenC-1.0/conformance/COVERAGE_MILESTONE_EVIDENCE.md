# OpenC Core coverage milestone evidence

Date: 2026-07-26
Host: Windows 10.0.19045, x86-64
Scope: Windows x86-64 Hosted

## Result

The post-SH-6 conformance-evidence granularity milestone passes:

- 278 of 278 authored fixtures pass with zero failures and zero
  infrastructure failures;
- 466 of 466 active Core rules name executed dedicated fixtures;
- 174 of 174 grammar productions name an executed accepting fixture and an
  executed rejecting fixture;
- the fixture-authoring queue contains zero required rules;
- all 8 authored D test commands, all 4 Python bootstrap tests, and all 4
  maintained programs pass;
- all 9 canonical targets build in both debug and release modes.

The fixture corpus adds direct evidence for initial UTF-8 BOM removal,
repeated-BOM rejection, unterminated block-comment rejection, `when`
contexts, text value semantics, function recursion, and struct equality.
Initial BOM normalization was implemented in the legacy D compiler, the
informative Python bootstrap, and the OpenC-owned self-hosted compiler.
The corpus also adds a resource-initializer lifecycle case with an explicit
stable-owner transfer, a plain-field default, whole-resource consumption, and
slot-free domain discharge, plus rejection boundaries for live-owner
reinitialization and invalid resource-field state transitions.

## Native closure preservation

The OpenC-native Windows compiler still reaches DMD-independent closure with
DMD, DUB, and Python absent from the compiler child environment:

```text
Stage 2 executable SHA-256: 6b627a6c2981a521a7334afe70f8ed00c8db65bfd57226b35b04f91f257aafa7
Stage 3 executable SHA-256: 6b627a6c2981a521a7334afe70f8ed00c8db65bfd57226b35b04f91f257aafa7
generated C SHA-256:        2ac262720880dee64bd54a00bfc2aa8811b8f0c9ff0f6a74c5f7ff724965f08b
normalized PE SHA-256:      ca25e47e827590e7533f019aff71c35fbd756191d17e4635a6bd431e109482d5
lexer observation SHA-256:  b6c86740a1993bc83319cad27a9925b78102c70f654f35a19de308dcb7a8f476
canonical IR SHA-256:       2a4bb16b68fd60a7005c53c1ae12ede32b9b6ef8a4557f9899e3805501b7b830
```

Generated C, raw executables, normalized PE artifacts, lexer behavior, and
canonical IR are equal across Stage 2 and Stage 3.

## Reproduction

```text
python scripts/complete_conformance_coverage.py --check
python scripts/validate_structure.py
python build/build_all.py --build debug --tools --compiler dmd
python build/build_all.py --build release --tools --compiler dmd
python tests/run_all.py
PYTHONPATH=compiler/bootstrap/python python -m unittest discover -s tests/python
compiler/openc validate --manifest=conformance/fixtures/MANIFEST.json
python tests/run_maintained.py
python compiler/selfhost/bootstrap_windows_closure.py --stage1 PREVIOUS_NATIVE_OPENC --use-existing-stage1 --tcc third_party/tinycc-win64/tcc.exe --output OUTPUT
python scripts/source_completeness.py
```

## Release disposition and successor

The public `v1.0.0-rc.8` tag and its 268-fixture standalone evidence remain
immutable historical records. This milestone is post-tag mainline work; it
does not claim that the old archive contains the expanded corpus.

That successor milestone is complete and published as `v1.0.0-rc.9`: two
byte-identical archives reach packaged native closure, execute all 278 fixtures
and all 4 maintained programs, and ship with the verified artifact set and
release record. The next engineering milestone is SH-7 native conformance and
tooling independence.
