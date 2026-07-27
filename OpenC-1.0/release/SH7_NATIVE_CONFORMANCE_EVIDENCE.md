# SH-7 native conformance and tooling-independence evidence

Status: **PASS**  
Required target: **Windows x86-64 Hosted**  
Evidence date: **2026-07-27**

SH-7 moves the complete packaged conformance gate into the OpenC-authored
compiler. Linux, freestanding, Native-provider, and standalone Native-provider
verification remain optional future target work and are not SH-7 blockers.

## Native conformance result

The public command is:

```text
openc.exe validate --manifest=MANIFEST --output=REPORT
```

`compiler/selfhost/source/native_conformance.p` implements the runner in OpenC.
`scripts/generate_native_conformance_plan.py` deterministically materializes
the canonical manifest as `conformance/fixtures/NATIVE_PLAN.tsv` plus 273
project records. `--check` proves that every materialized input is current.

The executed native report has schema `openc.conformance_result.v2`, evidence
state `EXECUTED_NATIVE`, SHA-256
`381dd35f71a4361c494288026bedd6e0a65bfca16fe87ebf02f110e2c6474f10`,
and records:

- 278 total, 278 passed, 0 failed, 0 infrastructure failures;
- 35 of 35 runtime fixtures built and executed to their exact outcome/output;
- 153 of 153 diagnostic contracts matched;
- 81 diagnostic rules observed directly in native frontend/semantic output;
- 72 canonical fixture-contract rules paired with a native rejection.

Each result records `rule_match_kind`, so direct native observations and
canonical fixture-contract matches are never conflated. Current execution uses
zero edition-compatibility fallbacks. The 93 historical compatibility matches
remain explicitly disclosed in `CHANGELOG.md`.

The native plan SHA-256 is
`d1d24d081ffb1cac23dbbb4608a3834611f81060a4f90969cf4554141dc5356f`.

## Seed independence

`release/verify_standalone_windows.py` invokes Stage 3, not
`bootstrap/openc-stage0.exe`, for the required 278-fixture gate. The retained D
compiler is packaged only for audit continuity. Its semantic/IR comparison runs
only when a maintainer explicitly supplies `--audit-seed`; the required SH-7
command omits that switch.

Python is an external evidence orchestrator. DMD, DUB, and Python are absent
from the native compiler child PATH used for Stage-2/Stage-3 builds.

## Native closure and maintained programs

The clean native closure command is:

```text
python compiler/selfhost/bootstrap_windows_closure.py --stage1 build-output/selfhost-rc9/final-v2/stage3-distribution/openc.exe --use-existing-stage1 --output build-output/sh7-closure-runner2
```

The result is `PASS`:

- Stage 2 builds Stage 3;
- generated C is byte-identical at SHA-256
  `124f7a42356fd468fa2c0b244c0580bcdca3345b3937e4f1d8d3139a800a7fbb`;
- raw Stage-2/Stage-3 executables are byte-identical at SHA-256
  `9b59bb94d516a50285fe3d0c882ef47c1977ad570cb6b041c9f251c39f0a1ab2`;
- normalized PE is equal at SHA-256
  `c992cb254ba21f23a47436e447ed260b86c8547bfbf05fe9e69fb9053f50ee99`;
- lexer behavior and canonical IR are equal;
- both native build records exclude DMD, DUB, and Python;
- all 4 maintained programs build and execute to their exact contracts.

## Reproducible relocated-package proof

Two standalone distributions are assembled independently from the same frozen
source state. Their ZIP bytes must compare equal before verification proceeds.
The verifier then extracts one archive, validates its internal manifest,
rebuilds Stage 2 and Stage 3 from a foreign working directory, requires exact
generated-C/raw-PE/normalized-PE closure, runs all 4 maintained programs, and
executes native `openc validate` for all 278 fixtures.

```text
python release/verify_standalone_windows.py --archive build-output/release-sh7/OpenC-1.0.0-rc.9-sh7-windows-x86_64-standalone-a.zip --comparison-archive build-output/release-sh7/OpenC-1.0.0-rc.9-sh7-windows-x86_64-standalone-b.zip --output build-output/selfhost-sh7/final --force
```

The command passes without `--audit-seed`. Exact archive/package hashes are
written to `build-output/selfhost-sh7/final/standalone-release-result.json`;
that generated result is kept outside the authored source snapshot so the two
source-derived archives remain reproducible.

## Next engineering milestone

SH-8 is native developer and release workflow hardening:

1. make the OpenC-native compiler the default compiler-under-test for Windows
   Hosted development gates;
2. measure native validation and self-rebuild paths and establish regression
   budgets;
3. remove avoidable full-corpus work where measurements justify it;
4. keep the D oracle separately invocable and outside required daily/release
   execution.

Linux and freestanding remain optional future priorities.
