
# Release source and operations

A release is generated from one recorded state of the canonical tree. Release archives are never edited as development sources.

The release process must distinguish:

```text
source release       complete canonical source snapshot
binary/tool release  compiled artifacts and runtime packages
design-history archive  optional non-normative historical collection
```

OpenC 1.0 uses the Windows x86-64 Hosted scope in `RELEASE_SCOPE_1.0.md`.
Licensing/governance is ratified and all required candidate gates pass.
`RELEASE_READY` authorizes artifact preparation; only a subsequent owner
publication act marks an immutable artifact `RELEASED`.

The SH-6 Windows standalone package and its RC9 successor refresh are built by
`build_standalone_windows.py`, used as a relocated self-hosting environment,
and verified by `verify_standalone_windows.py`. The immutable RC8 commands,
roles, results, and hashes are in `SH6_STANDALONE_EVIDENCE.md`; RC9 raises the
packaged conformance gate to 278/278. Its published evidence and successor
milestone are in `RC9_STANDALONE_EVIDENCE.md`. Package-user instructions are
in `STANDALONE_WINDOWS_README.md`.

SH-8 native developer/release hardening is implemented by
`scripts/windows_native_workflow.py` and `windows_native_release.py`. The
native compiler is resolved by default, full/release validation is fresh, and
the retained D seed is not executed. Commands, budgets, and measurements are
recorded in `SH8_NATIVE_WORKFLOW_EVIDENCE.md`.

SH-9 native CLI and diagnostics are implemented in the OpenC-authored
compiler and verified by `scripts/verify_sh9_cli.py`. The standalone verifier
requires all 12 public CLI cases, including `check` machine records, human
diagnostics, `run` argument forwarding, and active/historical rule
explanation. Evidence is in `SH9_NATIVE_CLI_EVIDENCE.md`.

SH-10 native project workflows are implemented in the OpenC-authored compiler
and verified by `scripts/verify_sh10_project_workflow.py`. The standalone
verifier requires all 21 formatter, context-inspection, deterministic
discovery/execution, stable-record, and failure-classification cases. Evidence
is in `SH10_NATIVE_PROJECT_WORKFLOW_EVIDENCE.md`.

SH-11 native language-service lifecycle, diagnostics, and formatting are
implemented in the OpenC-authored compiler and verified by
`scripts/verify_sh11_lsp.py`. The standalone verifier requires all 19
JSON-RPC lifecycle, synchronization, rule-ID diagnostic, SH-10 formatting,
error-state, framing, and deterministic-transcript cases. Evidence is in
`SH11_NATIVE_LANGUAGE_SERVICE_EVIDENCE.md`.

SH-12 native semantic language intelligence is implemented in the
OpenC-authored compiler and verified by
`scripts/verify_sh12_semantic_lsp.py`. The standalone verifier requires all 23
project symbol, typed hover, definition/reference, completion, safe-rename,
root-isolation, synchronization, schema, and open-order determinism cases.
Evidence is in `SH12_NATIVE_SEMANTIC_LANGUAGE_EVIDENCE.md`.

SH-13 native throughput and implementation independence adds first-party build
phase records, indexed OpenC lowering, a tightened byte-identical rebuild
budget, canonical OpenC-only compiler authority, and standalone packages that
exclude D/Python source and DUB manifests. TinyCC remains an explicit packaged
backend dependency. Evidence is in
`SH13_NATIVE_THROUGHPUT_INDEPENDENCE_EVIDENCE.md`.

SH-14 compiler throughput convergence and stability is complete. Its
absolute/relative clean-build, small/incremental, scaling, closure, memory,
correctness, workflow, and 20-run stability gates pass; evidence is in
`SH14_COMPILER_THROUGHPUT_CONVERGENCE_EVIDENCE.md`. SH-15 Windows x64 ABI and
machine-code substrate is now the active milestone in
`../compiler/design/WINDOWS_NATIVE_INDEPENDENCE.md`.

The complete publication set is assembled by
`build_release_artifacts.py` and verified by
`verify_release_artifacts.py`. The builder emits the artifact layout, mandatory
checksum list, and schema-valid owner authorization record without claiming
that a tag, push, or publication occurred. Those state changes are performed
and recorded separately.

The current owner authorization and public-tag state is recorded in
`PUBLICATION_STATUS.md`.
