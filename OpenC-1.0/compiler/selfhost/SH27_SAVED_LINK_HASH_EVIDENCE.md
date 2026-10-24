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

The module/COFF workflow now also runs on `codex/sh27-local-throughput` and
includes these regressions plus an 11-pair hosted saved-link comparison.
Clean-host status is pending at the time of this local record.

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
