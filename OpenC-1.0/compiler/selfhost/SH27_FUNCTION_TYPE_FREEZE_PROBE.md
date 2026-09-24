# SH-27 function type-registry probe

Decision: **retain only as an isolated, opt-in ownership probe**. This is not
an immutable type registry, a function scheduler, or a throughput win. Normal
build behavior remains unchanged. `artifact --freeze-function-types` also
enables the serial `PreparedSource`/`IrFunctionScratch` path.

## Cut and observed closure

After whole-source acceptance, `ir_prematerialize_ref_call_pointer_types`
visits the existing indexed call list. For selected `ref` parameters, it
mirrors the lowering decision about whether an argument needs a temporary
address, then interns only the required kind-13 pointer record. It allocates
no full-source arena. The first unprepared `sh27_nested_aggregate` run found
two late pointer records (elements `usize` and `Pair`) in the first source's
`main`; with this pass, the same run prematerializes 2 and reports 0 late
additions. Its executable remains byte-identical to default:
`11e0554e36498c393d388df2f57d3c35ed408902f75651cf13b196e5504230a6`.

The opt-in loop samples `types.length` around **each** function lowering and
fails the build with `OPENC-FUNCTION-TYPE-FREEZE-MISS` if records were added.
This is a post-function, fail-closed assertion, not a read-only mapping or a
pre-write interlock. The call pass is deliberately incomplete for other
possible constructors; an unseen legal source may still fail closed. The
static audit found only append writes to `type_data` in `semantic_add_type`;
it is not a transitive proof that all type-related state is immutable.

## Guarded evidence (2026-09-24)

The final current-source Stage1/2/3 bootstrap passed byte-exact fixed point.
All three PE files were 7,223,296 bytes and had SHA-256
`fb25289da5ad178faed5535fd560a22afdd06c9c2dd5c3410900302c40081e80`.
Peak child private / working set, respectively: Stage1
258,740,224 / 60,227,584; Stage2 257,466,368 / 60,030,976; Stage3
257,527,808 / 60,633,088 bytes. These pass the 256 MiB private and
64 MiB working-set bootstrap caps. Raw report:
`build-output/selfhost-sh27/sh27-type-freeze-final-20260924/bootstrap-current/bootstrap-current.json`.

The one-pair exactness check uses frozen `benchmarks/sh27/CORPUS.json`
(SHA-256 `ac35a710344f247454efdd039c13e6a84809fc97e9dc96cd49cd70b42361ef61`)
and compiler PE above. Both generated workloads reported 0 prematerialized
and 0 late types, exact output PE hashes, and exact executed
stdout/stderr/exit between default and opt-in:

| Workload | Source-tree SHA-256 | Output PE SHA-256 | Default / opt-in peak private bytes | Default / opt-in peak working-set bytes |
| --- | --- | --- | ---: | ---: |
| large_functions | `50529585eac9823b449d64cee8f45eb7b3d25c3c45d27e543b2a71a5f71fa9c0` | `81d22e50b31b4c958bce1e3da02c7c114d67ca815934b58b2902cb97cbb76c4e` | 169,918,464 / 170,475,520 | 75,440,128 / 76,050,432 |
| control_flow | `c7f2f64ec401c21d38417b21fce9098cec62d593d944df412c64dbabd758b9d2` | `31b8906a62a954d885b37fe8a03a94010eefaa619648f42626620ca455590e50` | 83,570,688 / 84,643,840 | 49,991,680 / 50,106,368 |

The generated-large default itself exceeds 64 MiB working set, so this
comparison used the canonical 512 MiB private / 512 MiB working-set corpus
guards; it is **not** evidence for a 64 MiB corpus guard. The checked-in
invalid fixture produced exact exit/stdout/stderr in both modes. Raw report:
`build-output/selfhost-sh27/sh27-prepared-source-bootstrap-20260924/proof/type-freeze-corpus-canonical-20260924/function-type-freeze.json`.
The verifier is `verify_sh27_function_type_freeze.py`. Static ownership tests
passed 8/8.

## Why function jobs remain unsafe

Type-table length stability for the observed corpus removes only one alias
path. `name_cache`, `type_cache`, call/argument links, left/right expression
caches, symbol-export and native-layout caches still have first-visit writes
in lowering; `IrFunctionScratch` still borrows their source-wide pointers.
IR buffers, SSA numbering, output, and diagnostics remain serial/shared.
Before function-level workers, these need private bounded ownership or
proven immutable snapshots, source-order result/diagnostic merge, and the
existing 256 MiB child-private / 64 MiB working-set scheduler gate. See
`SH27_FUNCTION_WORK_OWNERSHIP_GATE.md`.
