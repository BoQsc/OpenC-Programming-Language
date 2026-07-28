# OpenC compiler in OpenC

This directory contains the self-hosting implementation in canonical `.p`
source. The stage-0 D compiler builds `source/main.p` into a native Windows
executable. That executable implements the stage-0 byte-exact lexer and source
encoding rejection in OpenC. It performs one lexical pass, stores tokens and
diagnostics in OpenC-owned buffers, and attaches byte-accurate source
positions. The OpenC parser consumes those owned records and stores final
syntax records in a third owned buffer. Its lexical and parser observation
streams match stage 0 on every canonical `.p` source and focused probe. The
project frontend also loads JSON project records, resolves ordered source
units, composes logical modules/imports, and emits exact graph observations.
The semantic stages build OpenC-owned declaration, symbol, canonical type,
lexical-scope, constant-value, overload-selection, flow/safety, acceptance,
and canonical IR state and emit exact observations.

This is now a standalone, DMD-independent executable self-hosted compiler on
Windows x86-64 Hosted. It emits deterministic C11, invokes the shipped TinyCC
0.9.27 Win64 backend, links the next compiler stage, and reaches byte-exact
Stage-2/Stage-3 source and executable closure. SH-6 packages it with its source,
runtime, library inputs, backend, bootstrap audit seed, licenses, and integrity
records in a relocatable distribution. SH-7 adds OpenC-authored native
conformance and removes the retained D seed from the required package gate.
SH-8 makes the native compiler the default Windows compiler-under-test and
adds exact-cache and performance-budget gates. SH-9 adds the OpenC-authored
public developer CLI and human/machine diagnostic surface. SH-10 adds
OpenC-authored native formatting, project-context inspection, and deterministic
project testing. The
gate contract is in
`SELF_HOSTING.md`; the machine-readable gate state is
`SELF_HOSTING_STATE.json`. Post-SH-6 native self-rebuild measurements and
reproduction instructions are in `PERFORMANCE.md`.

Run from the repository root after building stage 0:

```text
python compiler/selfhost/bootstrap.py
```

That command builds stage 1 and executes the 304-case lexer gate, 303-case
parser gate, 22-case project/module gate, 17-case declaration/symbol/type gate,
10 exact name/constant/overload comparisons, 240 current flow/safety
comparisons, and full semantic-outcome/canonical-IR comparison with 123
accepted IR cases and 153 exact rejections. SH-2A through SH-2D, full SH-2,
SH-3A through SH-3D, and full SH-3 pass. SH-4A bootstrap D-source backend
parity, SH-4B Stage-1 self-compilation, SH-4C Stage-2/Stage-3 closure, and full
SH-4 also pass.

Run the SH-5 DMD-independent Windows closure proof with:

```text
python compiler/selfhost/bootstrap_windows_closure.py
```

Run the native daily or full SH-8 workflow with:

```text
python scripts/windows_native_workflow.py daily
python scripts/windows_native_workflow.py full
```

The resulting native compiler exposes the public build command:

```text
openc build --project=path/to/openc.project.json --output=path/to/program.exe
```

It also exposes the public native conformance command:

```text
openc validate --manifest=conformance/fixtures/MANIFEST.json --output=conformance-report.json
```

SH-9 adds the public developer commands:

```text
openc check --project=path/to/openc.project.json [--output=check-record.json]
openc run --project=path/to/openc.project.json [-- arguments...]
openc version
openc target
openc explain OPENC-LEX-COMMENT-001
```

`check` renders human diagnostics and can preserve the stable native stage
streams in an `openc.check.v1` record. Verify the complete 12-case surface
with `python scripts/verify_sh9_cli.py`.

SH-10 adds the native project-workflow commands:

```text
openc fmt --check (--project=path/to/openc.project.json|source.p)
openc fmt --write (--project=path/to/openc.project.json|source.p)
openc info --project=path/to/openc.project.json [--json]
openc test --manifest=path/to/openc.tests.json [--list] [--no-run]
openc test --project=path/to/openc.project.json
```

They produce stable `openc.format.v1`, `openc.tool_context.v1`, and
`openc.test_result.v1` records. Verify all 21 cases with
`python scripts/verify_sh10_project_workflow.py`.

Run the SH-4 proofs with a built Stage-1 executable and configured DMD:

```text
python compiler/selfhost/bootstrap_d_parity.py --stage1 build-output/selfhost-sh4/closure-final/openc-stage1.exe --output build-output/selfhost-sh4/parity-final
python compiler/selfhost/bootstrap_closure.py --output build-output/selfhost-sh4/closure-final
```

Run the complete SH-6 distribution proof with the commands recorded in
`release/SH6_STANDALONE_EVIDENCE.md`. SH-6 is **PASS**.

The published RC9 successor proof is recorded in
`release/RC9_STANDALONE_EVIDENCE.md`. It passes 278/278 conformance, all 4
maintained programs, 123 canonical-IR comparisons, and 153 exact semantic
rejections from the relocated package. Its native compiler is byte-identical
through Stage 2 and Stage 3 at SHA-256
`5924db13e20464d392dd563a086d35c95c61dafc6862ad7ba0fc767c0cdae4a6`.

SH-7 native conformance and tooling independence is **PASS**. SH-8 native
developer and release workflow hardening is also **PASS**; complete evidence
is in `release/SH8_NATIVE_WORKFLOW_EVIDENCE.md`. SH-9 native CLI and diagnostic
usability is **PASS**; its evidence is in
`release/SH9_NATIVE_CLI_EVIDENCE.md`. SH-10 native project workflow
completeness is **PASS**; its evidence is in
`release/SH10_NATIVE_PROJECT_WORKFLOW_EVIDENCE.md`. SH-11 native
language-service completeness is next.
