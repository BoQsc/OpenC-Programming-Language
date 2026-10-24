# SH-27 explicit zero-allocation batch

Status: **rejected; all compiler edits removed** (2026-10-24).

Native allocation already requests `HEAP_ZERO_MEMORY`. The C worker and D
bootstrap allocators also expose uninitialized allocation, so simply removing
compiler clear loops would be incorrect. An owned private allocation primitive
used the native guarded zeroed heap and an explicit clearing source fallback.
Four fixed-point variants selected layout/export caches, source caches,
function scratch, or all three; a helper-only control retained ordinary loops.

The balanced v2 11-pair four-CPU batch covered large functions, control flow
and many files. The combined large paired delta was -8.768 ms, 6/11 wins,
below 12.928 ms null. Control was -4.720 ms, 10/11, below 6.237 ms null.
Individual source/layout variants did not qualify. Function scratch's initial
control/many-file signals motivated an independent narrowed repeat.

The 31-pair four-CPU repeat compared combined, function scratch and helper
control. Combined large regressed by +6.704 ms (9/31 wins); function scratch
was +5.392 ms (15/31), against 13.690 ms null. Combined control was +1.527 ms
(14/31), and function scratch +0.079 ms (15/31), against 7.210 ms null.
No target gain qualified or reproduced. All generated programs were guarded,
deterministic and byte-exact; those correctness results do not qualify speed.

The 396 first-batch and 496 narrowed compiler/execution samples use the
original corpus guard profile; candidate bootstraps separately used 256/64 MiB.
The baseline compiler was `964a8e71...`. Raw reports remain under
`build-output/z27/`:

| Report | SHA-256 |
| --- | --- |
| `zero-matrix4cpu11.json` | `187284fc957c738a15868c5b03cafbe87b5914d475db8d899daaa10978150316` |
| `zero-narrow4cpu31.json` | `c0c3eb7016f2014372024ba670f88ed877cd24a87d68891c551fe3cb9e5fc7b7` |

The current frontend-publication/manifest-order change contains none of this
batch's private allocation primitive or removed-clear-loop edits.
