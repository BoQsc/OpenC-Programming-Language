# SH-27 function-source facts and small parent sets

Status: **correctness/RAM, function scaling and one clean hosted C/D pass;
constrained DMD repeat still fails at 1.263x**.
This is a continuation of the integrated native pipeline, not SH-27 closure.
Retained baseline is compiler `e2caeea094cc455dada71a4a4a90e4876469fc2e7723e57972579796086435b1`
at `f6fa527`. Its two hosted 20/20 passes and failed 1.363x constrained-host
DMD repeat remain in [the pipeline evidence](SH27_INTEGRATED_NATIVE_PIPELINE_EVIDENCE.md).
Do not transfer those comparator certificates to this new compiler.

## Removed repeated work

Binary lowering previously searched the entire enclosing function for the
literal byte pattern `memory.alloc(1)` on every `+` operation. The existing
compatibility rule only uses that result with a literal right operand. The
new path selects eligible operations first and lazily computes one fact for
the current function. Subsequent nodes consume its state directly; they do
not call a helper or rescan source. Two usize context members hold owner and
unknown/absent/present state. Function entry resets state; all four explicit
context constructors initialize it. There is no source-sized allocation,
prepass, extra worker, persisted cache, or changed pointer-fault outcome.

This deliberately preserves an existing source-pattern compatibility rule.
It is **not** a general pointer-bounds implementation, and does not remove
the historical compatibility limitations or change conformance rule IDs.

Parent indexing now selects directly when a kind has zero, one or two
candidate ranges. It avoids clearing/filling two source-byte-sized maps for
that case. It preserves half-open ranges, capacity clipping, smallest and
runner-up choice, input-order ties, duplicate exclusion, self exclusion and
the final containment check. It does not substitute a larger parent after a
failed containment check. Larger sets retain the old algorithm. The temporary
second map is not allocated if both kinds are small. No benchmark name or
workload-specific flag selects either change.

## Diagnostic basis and rejected alternatives

An isolated high-resolution counter compiler and a separate thread-cycle
compiler provide diagnostic rankings only. Their legacy `_ms` fields contain
raw counter values; their timer semantics differ from the language. Neither
image is a production compiler or speed certificate. QPC wall readings still
show scheduling variation. Thread-cycle shares in three large critical chunks
are acceptance 24-26%, IR lowering 25-29%, native emission 17-19%, indexing
13-16%, with 11-20% residual. These are instrumented CPU-counter shares, not
production wall percentages or recoverable-time promises. Cycle counts are
not converted to elapsed time, following the documented
[Windows contract](https://learn.microsoft.com/windows/win32/api/realtimeapiset/nf-realtimeapiset-querythreadcycletime).

The optional owned-thread sampler pins a passing compiler/source-map proof,
launches its own compiler child under Job/time/RAM guards, and opens only that
child's threads. Successful suspension always has a finally-resume; an
unrecoverable resume failure terminates only that child. Eight lookup/safety
tests cover boundaries, other-process exclusion, failed suspension, context
failure/exception and resume failure. Metadata and sample counts are bounded.
The Windows API requires suspension for a valid
[context capture](https://learn.microsoft.com/windows/win32/api/processthreadsapi/nf-processthreadsapi-getthreadcontext).
This is optional Python diagnostics, not a normal compiler dependency.

Fifty pinned-baseline builds give 946 endpoint samples: 480 inside compiler
functions and 466 outside. All emitted programs are byte-exact. The declared
50,000-cycle activity filter reduces idle-observer feedback; it does not make
the samples unbiased CPU-time measurements or inclusive stacks. Notable
in-image counts include node indexing 26, `flow_span_contains_ascii` 24,
source-import scanning 22, parent construction 22, native emission 20 and
node typing 19. They led to inspection of the repeated function scan; counts
are not multiplied into a claimed millisecond saving.

The following normal-compiler alternatives were tested and removed:

| Trial | Large paired delta / wins / null | Control paired delta / wins / null |
| --- | ---: | ---: |
| Bulk source initialization | +7.332 ms / 5 of 11 / 36.075 ms | -11.357 ms / 9 of 11 / 14.870 ms |
| Whole-record publication | +11.553 ms / 4 of 11 / 53.736 ms | -5.518 ms / 7 of 11 / 13.683 ms |
| Two workers, identical compiler | +2.064 ms / 4 of 11 / 10.124 ms | -1.831 ms / 6 of 11 / 11.718 ms |
| Serial, identical compiler | +118.643 ms / 0 of 11 / 10.124 ms | +46.056 ms / 0 of 11 / 11.718 ms |

Negative means faster. No trial above qualifies a target gain. Bulk/record
patches and their fixed-point binaries are retained only in ignored artifacts.
The worker-mode experiment does not justify a default-policy change.

## Fact-only and combined measurements

The first helper-call fact candidate is `042c60b3...`; its inline consumer is
`52737fe8...`. An 11-pair component run shows large -18.726/-11.439 ms,
8/11 wins each, below 21.466 ms null. Its independent 31-pair large repeat
shows helper -2.910 ms, 19/31 wins, and inline -10.775 ms, 23/31 wins, below
20.789 ms null. These are not rounded into qualified production-lane gains.
The inline fact-only source passes strict 20/20 at peak private/working set
229,896,192/54,308,864 bytes and 278/278 conformance; those proofs do not
cover the later parent-set source.

The final combined candidate is
`27a1f8300e95dc89ab33c5134bb755f4f378fa7b931898ca53128ee9e3bd2985`.
All three bootstrap stages match this fixed point. Its 11-pair
production-v1 run gives large **-16.745 ms**, 6/11 wins, above 12.120 ms null;
control -5.044 ms, 6/11, below 8.384 ms null; small +0.282 ms below 3.271 ms
null; many-file -2.797 ms below 2.969 ms null. All application PEs, runtime
outputs and guards pass. This is one qualified large-lane series, not an
independent repeat or a C/D ratio certificate.

The independent corrected-source 31-pair large repeat gives **-6.740 ms**,
21/31 wins, below 12.765 ms null. Its independent medians are 278.603/271.925
ms. The required-gain report fails: no sustained production-v1 large-lane
speedup is credited, despite the strong scaling result below.

The unrestricted 11-pair protection run has paired large/control/small/many
ratios **0.986/1.027/1.037/0.994**, all within the unchanged 5% ceiling.
All four effects are below their null floors; no unrestricted throughput
gain is claimed. Eleven real compiler-project pairs give an observed
**-90.110 ms**, 9/11 wins, with independent baseline/candidate medians
**1.576372/1.470671 s**. All 22 compiler outputs match the new fixed point.
That self-build tool has no same-run null control, so this is an observed
self-build signal, not a noise-qualified speed certificate.

Fifty owned-thread profiles of this corrected compiler finish with exact
outputs and no sampler errors. Endpoint counts include node indexing 30,
source-feature scanning 26, source-import scanning 25, parent indexing 20,
operator matching 17, right-child discovery 12 and left-child discovery 5.
These are diagnostic rankings, not percentages or a recoverable wall budget.
They support inspecting both indexing and first-visit source/operand discovery;
they do not establish that parser child links alone will close the DMD gap.

## Added function-length scaling coverage

Production v1 `large_functions` has 2,048 work functions with 12 operation groups
each. It does not exercise a single very long body. The separately versioned
`benchmarks/sh27/FUNCTION_SCALE.json` adds one-function 64/256/1,024-operation
inputs without changing `CORPUS.json` or any original threshold. The largest
input is only 25,984 bytes. Compiler/time/output/RAM guards remain unchanged.
This is extra stress coverage, not a replacement representative application
or a replacement for the five production parity workloads.

On the final combined compiler, eleven four-CPU pairs give:

| Added case | Baseline / candidate independent medians | Paired delta | Wins | Null |
| --- | ---: | ---: | ---: | ---: |
| 256 operations | 23.157 / 19.572 ms | -6.073 ms | 11/11 | 1.635 ms |
| 1,024 operations | 101.373 / 30.201 ms | -70.632 ms | 11/11 | 4.074 ms |

Both clear the declared gain gate with exact PE/runtime bytes. Earlier
fact-only scaling also gains at 256/1,024 operations, but not at 64: its
overall `--require-gain` report correctly fails that below-noise small case.
The additional stress proves the scaling defect and its removal; it does
not prove that the original local DMD deficit is closed.

## Fresh constrained-host DMD and repeat

Both runs use the same normal-default compiler, pinned DMD 2.112.0 binary,
corrected launch-to-exit observer, owned affinity mask 0xF, unchanged production
v1 inputs, and 20 samples per cell. No samples are dropped.

| Run | Large OpenC / DMD | Large ratio | Control OpenC / DMD | Control ratio |
| --- | ---: | ---: | ---: | ---: |
| First | 309.430 / 289.129 ms | 1.070x PASS | 110.285 / 148.442 ms | 0.743x |
| Independent repeat | 283.143 / 224.240 ms | **1.263x FAIL** | 105.320 / 134.066 ms | 0.786x |

First-run small/many/startup ratios are 0.251/0.691/0.227; repeat ratios are
0.246/0.812/0.224. All available correctness/resource/edit/batch/self-build
checks pass. Missing MSVC/Clang/LDC still prevents a full local certificate.
The repeat also fails the large ratio. Its deficit is **2.843 ms** to 1.25x,
or **14.055 ms** to the 1.20x internal target. The changed DMD median is not
attributed to this compiler patch; do not subtract cross-run medians to claim
a source speedup. Cold throughput therefore remains the first priority.

## Differential correctness

The expanded internal probe retains statement order/tie/reinitialization,
function-body, and fallback checks, and adds function-fact owner/reset cases.
It compares small-parent results against a retained copy of the old byte-map
implementation on 96 bounded range/capacity cases. This caught a duplicate
self-range error in the first candidate. That image/report is not promoted;
the corrected image passes all 96 cases, focused edge cases, runtime and
serial/adaptive byte identity.

On corrected compiler `27a1f830...`, fresh strict stability passes 5 clean,
5 edited and **20/20 chained exact self-builds**, with peak private/working set
**228,691,968/54,681,600 bytes**, below unchanged 256/64 MiB child limits.
All **278/278** native conformance cases, **25/25** x64 substrate checks,
explicit 2/4-source-chunk PE and invalid-diagnostic identity, 15 worker-fault
variants/19 profile cases, integer boundaries, array initializers, indexed
bindings versus the retained baseline and concurrent argument-snapshot checks
pass. The 512 MiB process-tree guards remain unchanged. TCC remains only the
optional ABI test oracle; normal compilation gains no D/TCC/Python dependency.

## Exact-source hosted certificate

[Run 38932817960](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/38932817960)
at source `6ad7ba94dd99e85e35d4a35e33b19ba5f05065ef` passes all 20 comparator
checks with 20 samples per compiler/workload. Large-function OpenC ratios are
**0.282x MSVC / 0.199x Clang / 0.405x DMD / 0.189x LDC**; control/DMD is
0.186x. Compiler `27a1f830...` and all 228 source-map hashes match the local
passing worker proof. All six additional bootstrap/regression reports pass.
The hosted old-seed transition differs; stages 2/3 match the final fixed point.
This is one synthetic hosted pass, not a causal A/B gain or a replacement for
the failed local repeat, broad projects or the second final-source certificate.

Artifact `12059952228` was downloaded and its bounded reports inspected.
The 120,665,670-byte ZIP SHA-256 matches the API digest:
`e8e824450b42d3472100a22d1ee5d6c324f67d8d1327bdb44fcc17a5928dc728`.
Raw ZIP and seven reports are retained beside the local evidence as
`hosted-38932817960*`.

The custom-corpus matrix independently caps metadata at 1 MiB, workloads at
16, source files at 128, total functions at 10,000, operations per function at
1,024 and total operation groups at 65,536 per workload. Workload path IDs
cannot escape the artifact directory. Inflating file-declared limits cannot
remove these parent-generator safety bounds. The owned sampler caps proof
metadata at 32 MiB and aggregate samples at 100,000. The exact sampler used
for `large50.json` is retained as `large50-sampler.py`, SHA-256
`504220585e6ec2353184f304976e8b2f0aadd752a6ef38bd9c611a769adcdba0`.

## Parser-owned expression facts: tested, not promoted

The proposed cut below was implemented as four variants. None qualifies a
large-function gain; all trial source was removed. See the
[measured no-go](SH27_PARSER_OPERAND_BATCH_NO_GO.md). Next target the dense
source-byte successor index, not another parser-link/cache variation.

The pinned DMD 2.112.0 distribution was inspected directly:
`dmd/parse.d:9163` constructs addition nodes with both operands;
`dmd/expression.d:2621` stores them on `BinExp`; and
`dmd/glue/e2ir.d:1817` consumes operand types during native lowering.
Source-file SHA-256 values are, respectively,
`57d6d0c7c8b1433432f9af10a9bf7f2fcf798fbf2055c61a0d3d66724fef6fff`,
`efef66ea5ceb16a4a41789f1a857cafa8bc6700c320e18fb4677d1ebf1b9a9fd`,
and `abd56aed9f5e95465bc6df456701961f3d8f4c8e6c89501098bd47a32885d76b`.
This establishes a concrete representation difference, not a claim that it
alone explains DMD's speed. No DMD code or runtime dependency is imported.

The next source cut must remove discovery work, not add another eager typed
pass or a larger memo table:

1. Inventory operator-record consumers and public syntax/IR JSON output.
   Define a tagged compact child-link representation whose logical source
   spans remain unchanged. Prefer existing packed-record space; prove target
   width, node/offset bounds and compatibility before using spare bits.
2. Have the parser publish the left/right nodes it already knows. Carry these
   immutable facts through retained parsing, acceptance and lowering without
   a second source traversal or duplicate source-sized arena. Legacy/manual
   unindexed records must retain the current fallback.
3. Make first-visit child resolution consume those links. In the same batch,
   evaluate carrying a numeric operator identity into native IR so consumers
   do not repeatedly decode the same source spelling. Audit evaluation order,
   lvalues, short circuiting, literals, callbacks, aggregates and pointer rules;
   do not restrict the final result to an easier scalar-only language subset.
4. Test independent and combined candidates with the original four protected
   build lanes, complete self-build, added function/expression scaling, all
   correctness/RAM gates and fresh C/D comparisons. Require material unprofiled
   wall gains; counters or parser-link hit counts alone cannot promote it.

The current repeat's 14.055 ms internal deficit is the starting wall budget,
not a promise of recoverable time. Re-profile the corrected compiler before
assigning that budget to a particular consumer. Original incremental/project/
release work remains in the full completion plan; none is replaced here.

## Raw evidence

Ignored artifacts under `build-output/` retain the commands and all samples:

- `sh27-bulk-initialize/four-cpu11.json`: `a0a7110929f0f33ed23e104c4253d120a08616213d20badb455adc6a5fd54ef3`.
- `sh27-record-publication/four-cpu11.json`: `9c4cabb1ff2da383e5c09226ce3184f4f5280debcd4a36a7f77ab334e2126199`.
- `sh27-qpc-profile/four-cpu-profile.json`: `39b479ee70bbbe5d9daab60e88c09c698a104591ab5857654b2710773c2c2890`.
- `sh27-cycle-profile/four-cpu-profile.json`: `7c28eae37928b6615ec6202e280790987183320ca356fb8917efca088f944dc6`.
- `sh27-owned-profile/large50.json`: `3437ca788370b45ed791a38ccbd6579cdc823ac4c42e0b4e7f2aa49593a0c3bc`.
- `sh27-owned-profile/worker-policies-four-cpu11.json`: `18f288e833c9d6aefbe7d31a376e200a1f9f120350d7549243a8749facd2d138`.
- `sh27-function-allocation-fact/large31.json`: `6de77feaf8691a9bfa240c7c0aebbfbd6b6d8e025325a44d081cd2b48c7aad5f`.
- `sh27-function-allocation-fact/final-four-cpu11.json`: `76af3a5a23dd1003e674477cad413eed094d97af68b36f65c7ed5fce62eafcfb`.
- `sh27-function-allocation-fact/final-large31.json`: `3b1692eb70c77a3c81c75c582945c08b402bcc6fa60a9b56be089aa6203c77c6`.
- `sh27-function-allocation-fact/final-unrestricted11.json`: `50f97fa5dd58b831b6f3298d9aa904088af14a9e6d5b5666f114784aafcbe069`.
- `sh27-function-allocation-fact/final-selfhost11.json`: `a472e619c33cb074831491a77a651231ce8894a25fd2f330e140924c970b2ea1`.
- `sh27-function-allocation-fact/final-owned-large50.json`: `056a24ae70a9bdb10c621efa355cf8a9d912fabbf717edf2de116409264d4c03`.
- `sh27-function-allocation-fact/final-scale-four-cpu11.json`: `ffbd23a61d7a99aeb158c27771ab122e39d8ca548c947619331c9bf18fc793ed`.
- `sh27-function-allocation-fact/final-stability.json`: `5b6c32b2765a4886f44c8435487a64068a7bd572f2d3579a6bc926593e03dea5`.
- `sh27-function-allocation-fact/final-parent-probe.json`: `ad49c2ea687ebbc3f8887fd31c837a0d83cb9a564b34b4c96cf66b1f3e373a06`.
- `sh27-function-allocation-fact/final-pool-faults.json`: `62084359d947329f00aa226943043bdc1b55abee4442e70595401541fa86fc89`.
- `sh27-function-allocation-fact/final-dmd20.json`: `377cd3af12b9e5202c686830aa7856483d8a52510935d732b50dbaf656757012`.
- `sh27-function-allocation-fact/final-dmd20-repeat.json`: `dbfb5293a4c991fb62a963b8afc2b01e742248dbb8c157ecf5bb8bdc5d808a61`.

Next: obtain clean exact-source C/D comparisons and remove the remaining
first-visit IR/semantic work; the original large-function ceiling still fails
on the independent constrained repeat. Incremental
reuse, representative project breadth, editor/release audits and all other
original SH-27 completion requirements remain mandatory.
