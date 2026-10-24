# SH 27 saved object hash acceleration

The public `module-coff-link` command now authenticates saved objects through
the same optional Windows SHA-256 path as object-cache hits. On a fixed set of
32 compiler objects, 11 alternating baseline/candidate pairs reduced relink
time from **1.232 s to 0.073 s**, with 11/11 candidate wins and identical PE
bytes. The median paired reduction was 1.160 s; the baseline/null median
absolute difference was 18.663 ms. This improves project-free saved-object
relinking. The cached compiler path already used this digest helper; normal
source compilation and cold-cache economics are separate outstanding gates.

## Implementation and authentication

`coff_link_append_published_object` previously selected the pure OpenC SHA
implementation even for large inputs. It now enables the shared
`module_cache_digest` helper: inputs below 4096 bytes retain the OpenC path;
larger inputs try the documented `CryptHashCertificate2` SHA-256 service and
fall back to OpenC if the optional API is unavailable. There is no new static
import or external compiler/linker dependency.

The same-handle pre-allocation size check, complete SHA-256 comparison,
aggregate bundle cap, and restricted COFF parser remain enforced. None of
these checks is replaced by file metadata or a trusted caller-supplied flag.

The retained baseline is `439c4d12995a9e6333094824d077561f8ed35498`, compiler
SHA-256 `27a1f8300e95dc89ab33c5134bb755f4f378fa7b931898ca53128ee9e3bd2985`.
The candidate fixed point is
`7f2f503a8cacd0f0723b09d690b73a9b062ef48107a249b26a4283887986711c`.
The timed objects were emitted once from an immutable source snapshot. Every
baseline/candidate/null relink uses those same objects and expected PE hash;
successful temporary outputs are removed after their measurements are saved.

## Verification

- Stage 2/3 native bootstrap closes byte-exactly. The strict stability suite
  passes all 13 checks, including 20/20 chained rebuilds, with peaks of
  **228,687,872 private bytes and 54,374,400 working-set bytes** under the
  unchanged 256/64 MiB child caps.
- Native conformance passes 278/278. Module boundary/native/saved linking,
  corruption, recovery, interface/body invalidation, concurrent cache writers,
  the 32-group compiler cache, and large relocation-overflow objects pass.
- `test_coff_relocation_targets.py` authenticates forged objects with freshly
  computed hashes, then rejects a later relocation with an invalid kind,
  code offset, symbol index or addend, plus an unresolved external. Repeated
  valid external references still link to the exact reference executable.
- The 128 MiB oversize, exact object limit and limit-plus-one reader cases
  pass under a 64 MiB process budget. The accepted-limit input has an
  independently computed Python SHA-256 and still fails COFF parsing.
- `test_coff_hash_fallback.py` replaces the SHA API name in an isolated
  compiler project, rebuilds to an exact Stage 2/3 fixed point, verifies the
  unavailable API name in that compiler, and uses it to relink a greater-than-
  4096-byte object. Accelerated and fallback compilers both match the reference
  executable and runtime result. The diagnostic compiler never replaces the
  production executable.
- The reusable saved-link runner and pinned-baseline CI wrapper pass separate
  three-pair smoke runs with an enforced above-null gain (3/3 wins each).

The [clean hosted module/COFF proof](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/40104280273)
passes at `2a0eaf0`: bootstrap, missing-API fallback, repeated-relocation
falsification, the pinned-baseline comparison, large objects, source-group
edit/recovery, representative builds and strict 20/20. Its independent
11-pair saved-link result is **2.481394 s to 0.103594 s (23.95x)**, 11/11 wins,
with a -2.378958 s paired median and 7.227 ms null floor. The logs and
source-group report identify the same `7f2f503a...` compiler. Artifact ID
`12563698202` has archive SHA-256
`d0112178b9fe1a3c44898950b92afc533fde70c783901aa8ae6141919a70fc89`.

The [first hosted attempt](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/40103916163)
failed before the fallback bootstrap because the fixture tried to make
relative paths from a C: temporary directory to a D: checkout. The corrected
fixture stays on the source volume. A local cross-drive report test and the
hosted retry pass; compiler source and binary are unchanged by that repair.

The [20-sample hosted C/D run](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/40103916224)
also passes all 20 ratios on this exact compiler. Large/control OpenC-to-DMD
ratios are 0.519/0.231; large MSVC/Clang/LDC ratios are 0.364/0.241/0.203.
This is one current-source pass and does not erase the earlier constrained
host's deficit. The downloaded archive was streamed and verified against
SHA-256 `297913259711c4d309f92bc29bdb9aa13acf7b12d4bdc466902e8c1af3486643`;
the raw production report SHA-256 is
`36322b82c39e18d9022febe466de00e0add268e2f709219a7c6c9065a5a8153e`.
The report's compiler and stage-2/stage-3 hashes all equal the local fixed
point. Adding the new safety tests to the production workflow will obtain
an independent C/D repeat without changing compiler source.

The final-source local 24-file cache check has no-op/body-edit/normal medians
of 31.403/140.923/63.368 ms. No-op is faster, but edited-module reuse is still
slower than ordinary direct compilation on that small project. Default cache
promotion therefore remains open.

## Rejected companion candidates

The per-object symbol-RVA table, typed wide PE/COFF stores, and their combined
version preserve outputs but fail the independent 11-pair relink speed test:
paired medians are +13.733, +20.558 and -13.259 ms respectively. The null
median absolute difference is 35.402 ms. A single-allocation COFF section
writer also fails the cold-build test: +2.284 ms with 5/11 wins, below a
55.129 ms null floor. All four source changes were removed.

The earlier constant rematerialization, slot reclamation, parameter ownership
metadata and compact expression-index trials are likewise unpromoted. Their
patches, internal oracles and reports are archived in ignored build output.
The index results are separately recorded in
[the expression-index decision](SH27_EXPRESSION_INDEX_BATCH_NO_GO.md).

An initial three-pair cold comparison was invalidated by editing its compiler
input during the run. It is excluded; the subsequent cold and relink batches
freeze the source/object inputs before timing.

## Raw evidence

Local reports are under `build-output/sh27-link-resolve/`, relative to
`OpenC-1.0`. SHA-256 identities:

| Report | SHA-256 |
| --- | --- |
| `hash-links11.json` | `8133a95c40203c8a669226ffc28ea9503179b0ea408a0cb542f65878da4761d7` |
| `saved-link-smoke.json` | `cfbb0c8551b7ef3013b2bfca793bc000b0dfb191afa6421a59830306da6bee9a` |
| `wrapper-smoke.json` | `c0eb9a683cd99d83d85a38a93f790982d8e21a052324407a6360a813dcaebb95` |
| `hash-fallback-v2.json` | `ef9f0449d531db69792e4e554791d94fdd17445421318e5a32cd127a8adbf585` |
| `hash-bounds.json` | `b8e1359d3390f2fc74c388cbfa689179f626850c4c9fd3a4cf79d0517ecc3d7c` |
| `strict20.json` | `bc97c6c4424ad60049b8017a2599a1d8145fa4049d99402ec9e64595d645a7f7` |
| `conformance.json` | `3dd7d80aeab7a152e4ba75ad2414e6e4cddef948b7b75b7f1cfc4d4577354c3b` |

SH-27 remains active. Normal-default incremental behavior, cold and edited
representative performance, constrained-host throughput, two final-source
C/D runs and editor/release certification remain required.
