# SH-27 integrated native pipeline and bounded worker reuse

Status: **two clean hosted 20/20 parity passes; independent constrained
repeat fails large-function parity**. SH-27 remains active. This candidate closes
the public local four-CPU DMD ceiling once, but does not establish the final
1.20x margin, broad project performance, default incremental policy or release
readiness. Baseline is `f58c5a07...` from the indexed-binding batch.

## Integrated changes

The three changes form one tested candidate; isolated effects are not added
to claim its gain.

1. Native function preparation captures its first SSA ID at the lowering
   boundary and builds type, stack-slot, operand-use and capacity facts in
   one creation-order traversal. It removes the minimum-ID scan, the old
   reference-origin writes immediately overwritten by stack slots, and the
   later value-layout walk. Contiguous result IDs are checked before indexing
   scratch. The one-past-last slot, block ordering, frame alignment, numeric
   checks, code/relocation/constant budgets and generated application bytes
   remain unchanged. Use-count storage is now allocated for every function;
   the strict RAM test below includes that cost.
2. Statement adjacency visits creation order backwards. Monotonic direct
   siblings prepend instead of repeatedly traversing a growing sorted list;
   the unchanged sorted insertion handles non-monotonic positions and ties.
   The existing function-position index publishes each function's largest
   contained body in otherwise unused function-key control-block head slots.
   Acceptance and lowering share that fact. No new source-sized table is
   allocated; unindexed contexts retain the original scans.
3. Parsing, flow and native source chunks use documented Windows threadpool
   work instead of creating fresh OS threads at each phase. At most three
   work items are submitted while the caller runs the remaining chunk. The
   two-worker policy submits one. Chunk scratch/type ownership, policy
   thresholds and ordered diagnostic/code merging are unchanged. This is
   not function-level scheduling and does not relax its ownership gate.

The pool adapter uses normal three-argument x64 callbacks. All work objects
are created before submission. Lookup/allocation failure closes unsubmitted
objects and returns the existing serial-fallback result. After submission,
all callbacks complete before work objects, source state or the system DLL
reference are released. Only documented KERNEL32 APIs are dynamically
resolved; no new import library, CRT, C header, D, TCC or Python requirement
is added to normal compilation.

Microsoft documents the relevant contracts for
[creation](https://learn.microsoft.com/windows/win32/api/threadpoolapiset/nf-threadpoolapiset-createthreadpoolwork),
[submission](https://learn.microsoft.com/windows/win32/api/threadpoolapiset/nf-threadpoolapiset-submitthreadpoolwork),
[completion](https://learn.microsoft.com/windows/win32/api/threadpoolapiset/nf-threadpoolapiset-waitforthreadpoolworkcallbacks),
and [release](https://learn.microsoft.com/windows/win32/api/threadpoolapiset/nf-threadpoolapiset-closethreadpoolwork).
The legacy timing field `flow_threads_launched` continues to indicate a
successful worker launch; with this implementation it does not count newly
created OS threads.

## Selection and rejected alternatives

The encoder packet trial was removed: its large/control paired changes
(-3.310/-0.117 ms) did not exceed 21.163/7.257 ms null floors. Native
preparation alone was also not promoted (+1.913/-2.092 ms versus
15.866/7.233 ms null).

The first statement/body combination showed -16.886/-4.498 ms above null,
but its independent component matrix did not reproduce the large gain:
reverse-only -4.869 ms, body-only -13.219 ms, both +1.921 ms, versus a
13.410 ms null. Pool-only was below noise (-7.384/-1.921 ms versus
12.929/2.020 ms). These are not individually promoted speed claims.

The integrated matrix compares full, no-pool and pool-only binaries against
the same baseline with order rotation, adjacent pairs and a null control.
Full large improves 7.947 ms (6/11 wins; 7.279 ms null). Its control effect
is flat (-0.064 ms; 8.106 ms null). No-pool and pool-only do not clear the
large gain test. The matrix's overall `FAIL` correctly reflects requested
gains not obtained on all candidates/lanes.

A full-candidate repeat has -12.333 ms large (9/11 wins), **24 microseconds
below** its 12.357 ms null floor. It is not rounded into a gain pass. The
subsequent 31-pair large test, with no dropped samples, passes: **-16.170 ms,
23/31 wins, 12.099 ms null**. Independent medians are 250.161/236.437 ms.
The repeat's protected control/small/many-file paired ratios are
0.942/1.035/0.984; all output and memory checks pass.

Unrestricted 11-pair large/control effects are flat (+0.635/+0.028 ms,
9.543/7.386 ms null). Small/many-file ratios are 1.032/1.016, within the
5% protection gate. Real compiler self-build is also flat: -22.663 ms paired
median, 7/11 wins, independent medians 1.508564/1.514229 s. The old generator
is pinned to its declared transition output `c4a603ae...`; the candidate
produces its new fixed point. Cross-revision compiler bytes are intentionally
different because the worker runtime changed; application PE bytes remain
exact. No self-build speedup is claimed.

## Fresh four-CPU comparator proof

The normal-default 20-sample run retains the same owned-process affinity
mask `0xF`, corrected process-exit observer, corpus and DMD 2.112.0 binary
(`5ec3152d...`). It passes all five available DMD ratios:

| Workload | OpenC median | DMD median | OpenC/DMD |
| --- | ---: | ---: | ---: |
| Small single file | 0.019647 s | 0.072324 s | 0.272x |
| Many files | 0.063043 s | 0.085172 s | 0.740x |
| Large functions | 0.232483 s | 0.193489 s | **1.202x** |
| Control flow | 0.086388 s | 0.124026 s | 0.697x |
| Startup/file/allocation | 0.016863 s | 0.079576 s | 0.212x |

Large has 9.378 ms public-ceiling headroom but misses the internal 1.20x
line by 0.296 ms in this run. Missing local MSVC/Clang/LDC tools still make
the full report `FAIL_PARITY`; this is not a five-compiler certificate.
All available version, compilation, execution, RAM, edit, batch and self-build
checks pass. Do not infer a causal speedup by subtracting earlier comparator
medians; the same-host A/B above establishes the measured effect.

The fresh critical large-worker medians are 125 ms wall, 23.5 acceptance,
31 IR lowering, 16 native emission and 15.5 indexing. These separate,
coarsely timed medians are not an additive ledger. Control remains 47 ms
wall with 15 ms lowering and acceptance below timer resolution.

### Independent repeat: the large-function deficit remains open

On exact compiler `e2caeea0...`, the independent 20-sample four-CPU run gives
OpenC/DMD **1.363x large / 0.740x control**. Small/many/startup ratios are
0.279/0.670/0.259. Large OpenC median is 0.261041 s, with a 0.228191 to
0.298965 s range. All available non-parity correctness/resource checks pass;
missing local C/LDC and the large-function ratio fail the report. Do not
discard the repeat, average it with the first pass, or claim sustained parity.
Its raw report is `four-cpu-dmd20-repeat.json`, SHA-256
`ce46f1cd0bb9a9d4ab243152d89a5f5841b8b4964207e63901f30399c9fe00c7`.

Native-worker wall exceeds the slowest chunk by zero in most repeat samples,
but individual gaps reach 62 ms; declarations and critical chunk wall also
vary. These coarse timers do not isolate a pool regression or thermal cause.
Two clean exact-source runs pass at commit `f6fa527`, as recorded below.
Cold throughput remains ahead
of incremental/release work until the repeated deficit is resolved.

### Clean hosted replication on the exact fixed point

[Run 38909638831](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/38909638831)
and independent manual [run 38912021927](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/38912021927)
both pass all 20 comparator checks, with 20 samples per compiler per workload.
Both use source `f6fa527570cb5776c49960ac82c57fbbf0ddb3ba` and compiler
`e2caeea0...`, exactly matching the local fixed point. All worker-pool,
statement/body, indexed-binding, array and argument regression reports pass.
The complete worker-verifier source hash maps match the local source proof.
The bootstrap transition differs from its seed, as expected; stages 2/3
match. The transition mismatch is not relabeled as a stage-1 fixed point.

| Hosted run | Large OpenC/MSVC | Large OpenC/Clang | Large OpenC/DMD | Control OpenC/DMD |
| --- | ---: | ---: | ---: | ---: |
| 38909638831 | 0.541x | 0.330x | 0.886x | 0.493x |
| 38912021927 | 0.372x | 0.237x | 0.550x | 0.237x |

The raw ZIPs were downloaded, bounded JSONs inspected, and their hashes
matched GitHub's artifact digests. Artifact `12049792695` is 120,607,808
bytes, SHA-256 `2499880f49299b3d3a5110e455b1a79f3ea9cfcaf5e8c95d0e73285ea6cd3939`;
artifact `12051490646` is 120,611,513 bytes, SHA-256
`f33d9c650c8ab6b32eae277c33c45b06f6c68f552d40e4445482bcd054209b1e`.
The corresponding `hosted-RUN-*.json` reports and ZIPs are retained beside
the local reports. These replicate the hosted synthetic gate, not broad
cross-host parity: the 1.363x constrained-host failure remains authoritative.

## Correctness and failure proof

Compiler SHA-256:
`e2caeea094cc455dada71a4a4a90e4876469fc2e7723e57972579796086435b1`.
The older seed produces a transition compiler; stages 2/3 match exactly.
A final-source bootstrap from this fixed point produces identical bytes in
all three stages. The later correction of a stale CreateThread comment does
not change the compiler binary.

- Strict stability passes 5 clean, 5 edited and 20/20 chained byte-exact
  compiler builds. Peak private/working set is **228,503,552/54,108,160 bytes**,
  under unchanged 256/64 MiB child limits.
- All 278 native conformance cases pass. Serial versus explicit 2/4 chunks
  produces exact self-build/generated PEs and single/multi-source invalid
  diagnostics. The 512 MiB process-tree guards remain unchanged.
- All 25 x64 substrate checks, integer boundaries, array initializers,
  indexed scope/parameter bindings, and concurrent argument-snapshot checks
  pass. TCC remains only the optional ABI test oracle.
- The internal statement/body probe passes serial/adaptive exact bytes and
  runtime: shuffled creation order, equal-position ties, reinitialization,
  largest nested body, body absence, control-head preservation and unindexed
  fallbacks. Its full-compiler probe uses a separate 512/256 MiB build guard,
  not the strict stability proof above.
- The worker verifier passes **15 fault variants**, with 19 profile cases:
  missing each of four API names; failed first/second/third creation for
  parsing, four-worker flow/native; and failed sole creation for two-worker
  flow/native. It verifies actual fallback flags where available, exact valid
  PEs/runtime and invalid diagnostics with no executable. Normal controls
  prove the two/four-flow and four-native policies actually launch workers.
  Parsing is exercised below its existing 1 MiB threshold, and four-worker
  flow above it; the two profiles deliberately cover both policies.

Fault injection modifies only newly copied compiler images. Creation-call
patches skip the allocation and set its return value to null; they do not
allocate then lose a work handle. Source-order/.pdata joins and exact
instruction-pattern counts reject mismatches before patching. Eight unit
tests cover mapping and rejection cases. This is optional Python evidence,
not a production compiler dependency. It does not prove zero handle leaks
by itself; the cleanup ordering/write audit and bounded process tests are
also required. Both focused verifiers are in push/manual CI.

## Retained evidence and next gate

Ignored reports are under `build-output/sh27-integrated-native-pipeline/`:

- `large31.json`: `269c1e1023a4a700d427d87497fb4a5bbae77efc23b2a58924c2acbb53b2aea2`.
- `repeat-four-cpu11.json`: `39b5bafa6adf603c009ea2f0e146c77913d32df457f52aa4de5e1c86331dc187`.
- `unrestricted11.json`: `265b6abc9d798a910cf237429c77574ffb66df64724237b68591a0082dbda830`.
- `selfhost11.json`: `cdf2b8ee41e2e0dce5deaf39919d06e5af56d2fd3da6df9782522da43dd9615b`.
- `four-cpu-dmd20.json`: `9d59667b9e1454a86591b1a2c46124e4d6b42f45430f984f900c8be1f40b3ae1`.
- `stability.json`: `33bba2ec71764f8183e145fff85bffce980969254786ca33fc42f8f0a4f99d7e`.

Isolated rejected patches/reports remain in `sh27-encoder-packet/`,
`sh27-native-plan/`, `sh27-statement-handoff/`, and `sh27-worker-pool/`.
Their mechanisms are retained only as the complete integrated candidate,
except the packet encoder, which remains removed. No independent component
speedup is credited.

Next resolve the failed constrained-host repeat before claiming sustained
cross-host parity. The 1.20x local margin remains unproved.
Then complete the original normal-default incremental, representative-project,
repeated final-source editor and release gates. None is waived by this result.
