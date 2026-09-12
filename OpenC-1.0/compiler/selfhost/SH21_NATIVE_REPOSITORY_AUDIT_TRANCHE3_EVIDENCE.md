# SH-21 OpenC-native repository audit tranche 3 evidence

Status: **PASS FOR THIS TRANCHE; SH-21 REMAINS ACTIVE**.

This tranche moves the required canonical-tree, authored-source, conformance
identity, rule-coverage, and grammar-coverage checks into the OpenC compiler.
It does not close SH-21: native PE, LSP, benchmark, and deterministic
release/archive ownership remain active work.

## Native audit boundary

The public command is:

```text
openc audit --root=ROOT --output=REPORT.json
```

The command is implemented in canonical OpenC `.p` source. It consumes the
committed, deterministic
`tests/SH21_NATIVE_REPOSITORY_AUDIT_PLAN.tsv` rather than invoking Python or
parsing C headers. The plan pins record counts and the current authority and
coverage inputs. The resulting `openc.native_repository_audit.v1` report
passed all checks:

- 364/364 required authored source and non-source files are present and
  nonempty;
- 39/39 authority, control, manifest, and coverage hashes match their pinned
  byte counts and SHA-256 values;
- 278/278 conformance fixture identities occur in both the JSON manifest and
  native execution plan;
- 466/466 active rule identities occur in both the rule index and dedicated
  coverage map;
- 174/174 grammar production identities occur in both the grammar and
  accepting/rejecting coverage map.

The standalone audit completed in 1.626 seconds and peaked at 19,668,992
private bytes and 19,517,440 working-set bytes under the external guard. The
daily native workflow now includes the audit and passed 5/5 tasks in 5.155
seconds.

## Compiler memory scalability correction

Adding one small source unit exposed an unrelated legacy observer allocation
cliff. `observe_semantic_resolution` formerly reserved four 40-byte record
arrays using one `3 * total_source_bytes` record capacity, consuming roughly
480 reserved bytes per source byte and immediately crossing the compiler's
512 MiB live-allocation fail-fast guard.

The observer now uses the same independently sized type, symbol/detail, and
error bounds as the production build and flow paths. A guarded regression
probe reduced peak private bytes to 116,813,824 and peak working set to
25,284,608. The deliberately exhaustive observer still emitted more than the
4 MiB child-output ceiling; it is a parity/debug stream and is not used by
public `openc check` or the normal build workflow. The production self-build
completed in 19.468 seconds with full semantic validation.

The same investigation found that public `openc check` still spawned two
verbose historical parity observers and discarded their multi-megabyte
success streams. The command now keeps the bounded project-front-end stage but
uses the production flow and acceptance validator in a check-only mode that
does no IR lowering or PE emission. The complete 118-source compiler checks in
18.148 seconds; flow and semantic failures retain their respective stable
`openc.check.v1` machine-diagnostic streams.

## Fixed point and workflow result

The updated compiler contains 118 canonical OpenC source units and 1,653,683
source bytes. The bootstrap compiler and two independently emitted compilers
are byte-identical:

- executable bytes: 5,267,968;
- compiler/Stage-2/Stage-3 SHA-256:
  `69eea75081cfcd8e2fb884da9733bd5cbf198f0760dcc903b8296c19e0a5f912`.

The final-source expanded full workflow passed in 199.764 seconds (including a
140.828-second full conformance pass on the loaded host):

- 9/9 native workflow tasks;
- 1,321/1,321 native repository-audit records;
- 4/4 adversarial process guards;
- 278/278 native conformance fixtures;
- 5/5 maintained and native-runtime programs;
- exact compiler/Stage-2/Stage-3 fixed point;
- no Python, D, C compiler, TinyCC, external assembler, or external linker
  invoked by the workflow.

The guarded compiler build peaked at 212,525,056 private bytes and 46,833,664
working-set bytes. The outer full-workflow process peaked at 34,865,152
private bytes and 29,102,080 working-set bytes. Both remain within the fixed
256 MiB private and 64 MiB working-set limits.

## Primary local records

- `build-output/selfhost-sh21/audit/audit-report.json`;
- `build-output/selfhost-sh21/audit/audit-memory.json`;
- `build-output/selfhost-sh21/audit/daily-report.json`;
- `build-output/selfhost-sh21/audit/daily-memory.json`;
- `build-output/selfhost-sh21/audit/final-full-report.json`;
- `build-output/selfhost-sh21/audit/final-full-memory.json`;
- `build-output/selfhost-sh21/audit/final2-bootstrap-timings.json`;
- `build-output/selfhost-sh21/audit/final2-bootstrap-memory.json`;
- `build-output/selfhost-sh21/audit/self-check-final2-memory.json`;
- `build-output/selfhost-sh21/audit/resolution-memory.json`.

These ignored build-output records are reproducible working evidence, not
canonical source-controlled artifacts. This evidence summary and the state
records are the canonical tranche record.
