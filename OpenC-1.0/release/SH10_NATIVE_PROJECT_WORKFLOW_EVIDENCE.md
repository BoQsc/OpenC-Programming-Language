# SH-10 native project workflow completeness evidence

Date: 2026-07-28
Target: Windows x86-64 Hosted
Status: **PASS**

SH-10 completes the first-party native project workflow in canonical OpenC
`.p` source. Linux, freestanding, Native-provider, and retained-D comparison
work remain outside this required gate.

## Native implementation

The 94-source self-hosted compiler adds:

1. `openc fmt --check` and `openc fmt --write` for one explicit source or all
   sources in an explicit project;
2. `openc info` context, source, module, limit, dependency, target, and type
   views with human and JSON output;
3. `openc test` for explicit manifests or direct projects with name-sorted
   discovery and execution, filtering, check-only mode, isolated executable
   names, stable source hashes, and distinct language, assertion, and
   infrastructure outcomes.

The implementation is in
`compiler/selfhost/source/cli_format.p`,
`compiler/selfhost/source/cli_project_workflow.p`, and the native CLI
dispatcher. Its installed native compiler has SHA-256
`8d20438e3e3debbe6fb700c41cb74a07553f4f6c64ce24cd9fcb21f4baa9ae71`.
Its installation provenance matches the current compiler-source fingerprint
`8fe8fe90fb63e73c0dfecb9bb6d0cf645e4249b6b9505e67a80765ef98f24896`.

## Stable records

The machine interfaces are:

- `openc.format.v1`, specified by `schemas/FORMAT_RESULT.schema.json`;
- `openc.tool_context.v1`, specified by
  `schemas/TOOL_CONTEXT.schema.json`;
- `openc.test_manifest.v1`, specified by
  `schemas/TEST_MANIFEST.schema.json`;
- `openc.test_result.v1`, specified by
  `schemas/TEST_RESULT.schema.json`.

Formatter output is UTF-8 with LF line endings, four-space indentation, and one
terminal newline. Invalid syntax is rejected before a write. Compound and
three-character assignment operators are preserved, and the verifier reparses
formatted output.

Test execution records the OpenC implementation, Windows target, requested
jobs, deterministic name-sorted order, project/source hash, expected and
actual exit state, output, and diagnostics. `--jobs=N` is recorded for
forward-compatible scheduling; SH-10 deliberately executes sequentially in
name order.

## Executed native contract

```text
python scripts/verify_sh10_project_workflow.py \
  --output build-output/selfhost-sh10/native-project-workflow
```

Result: **21/21 PASS**. The cases cover help discovery; formatter change
detection, writing, idempotence, project traversal, output reparsing, and
invalid-source nonmutation; human and JSON context plus all six filtered info
views; name-sorted test listing, filtering, no-run and direct-project checks,
three-project execution, language/assertion failure classification, and
unsupported-target rejection.

The exact machine record is
`build-output/selfhost-sh10/native-project-workflow/`
`sh10-project-workflow-verification.json`. The required D seed was not
executed.

## Development and release closure

The SH-10 daily/full workflow adds `native_project_workflow` beside the
retained 12-case SH-9 CLI gate, maintained programs, demos, complete native
conformance, and the existing performance budgets. The release workflow builds
two standalone archives independently and runs the same 21 cases against
relocated Stage 3 before accepting the archive.

Repeated validation on the live reference desktop ranged from 29.803 to
68.471 seconds, with 278/278 passing each time. Repeated 94-source rebuilds
ranged from 574.050 to 744.926 seconds, used at most 196,796,416 bytes peak
private memory and 12,967,936 bytes peak working set, and produced an
executable byte-identical to its input at SHA-256
`8d20438e3e3debbe6fb700c41cb74a07553f4f6c64ce24cd9fcb21f4baa9ae71`.
The authored SH-10 variability review discloses both observed ranges and
establishes 90/900-second live-desktop elapsed ceilings with 31.4%/20.8%
headroom. The original private-memory and working-set ceilings are retained.

The closure records are:

- `build-output/selfhost-sh10/full-workflow/full-workflow-result.json`;
- `build-output/selfhost-sh10/release/standalone-release-result.json`;
- `build-output/selfhost-sh10/release/native-release-workflow-result.json`.

The full workflow passes 11/11 tasks. Two independently assembled
1,492-entry standalone packages are byte-identical at SHA-256
`5742c5e5a8ab95c556810874b9aef0797787b26d79a80d16667d0e3a908a821a`.
The packaged compiler, relocated Stage 2, and relocated Stage 3 are
byte-identical at SHA-256
`8d20438e3e3debbe6fb700c41cb74a07553f4f6c64ce24cd9fcb21f4baa9ae71`.
Generated C is equal at
`60c6c1476c505f24d0cd1d345aa2773e4147e7e715a6d4b2b5cf97936d55ca86`;
normalized PE is equal at
`1fb5b93cee53b61eb646c909934a030fbb254ec28bcd35f93756147c2002486e`.

Relocated Stage 3 passes 21/21 SH-10 project-workflow contracts, 12/12 SH-9
CLI contracts, 278/278 conformance fixtures, 35/35 runtime fixtures, 153/153
diagnostic contracts, and 4/4 maintained programs. Infrastructure failures
are zero.

Archive A and B assembled in 69.347 and 61.380 seconds; complete relocated
verification took 1,557.274 seconds. A fresh SH-10 daily workflow passes 10/10
tasks and executes 278/278 fixtures. Repeating the exact same daily inputs
passes 10/10 with a 0.002-second conformance cache hit and executes zero
fixtures.

Both required workflows exclude the retained D seed. Current execution has
zero edition-compatibility fallback matches; the 93 historical rule-ID
compatibility matches remain explicitly disclosed.

## Next engineering milestone

SH-11 is **native language-service completeness**:

1. add native `openc lsp --stdio` initialization, shutdown, and capability
   negotiation;
2. publish document diagnostics through the SH-9 check pipeline;
3. route document formatting through the SH-10 native formatter;
4. preserve deterministic JSON-RPC transcript evidence and verify it from the
   relocated standalone package.

Independent review remains welcome and nonblocking. Linux and freestanding
remain optional future targets.
