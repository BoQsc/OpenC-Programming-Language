# SH 27 ordinary build native object cache candidate

Status: **unpromoted; the 24-file performance gate fails**. The isolated
`codex/sh27-native-object-default` branch adds content-validated native object
reuse to ordinary `build`. Correctness and strict memory checks pass locally,
but the medium-project gains remain below measured noise and cold builds cost
more. SH-27 stays active and this candidate must not replace the retained
production compiler until both project sizes and the remaining gates qualify.

## Direct native artifacts and cache policy

The compiler-private object contains the direct PE linker's native function
records. Normal source builds avoid converting those records to COFF and
reading COFF back into the same linker. Stable COFF exports, saved-object
linking and their tests remain available for independent artifacts.

Eligible ordinary builds use `OUTPUT.exe.openc-cache/objects.bundle`.
`build --no-cache` runs full compilation. The explicit artifact boundary is
`artifact --kind=cached-exe --cache-prefix=PREFIX`; cache options are restricted
to console executables without external manifest/resource inputs. Serial
projects and sources larger than the proved 128 KiB per-source projection
limit retain direct compilation. Supported source groups require the closed
2/4-worker path, at most 4 MiB of source and 16,384 resolved symbols.

Keys bind compiler bytes, target ABI, schema, worker count, source grouping,
project/root, complete project declarations, resolved types, function numeric
IDs/source/module/return-type mapping and each group's full source contents.
A body edit can reuse the other groups. Local declarations that shift later
function IDs, or public/interface changes, conservatively invalidate all
groups. Parsing and resolution still run for every source.

## Bounded atomic storage

The initial per-group implementation published 32 objects plus 32 key records.
Its ordinary compiler matrix added a 259.593 ms median cold paired penalty,
above a 120.682 ms null floor. It was rejected for default promotion.

The replacement stores one latest-generation atomic bundle. A 16-byte header
and 136-byte entries describe independent content keys, SHA-256 digests and
contiguous object extents. Each native object has a versioned 16-byte source
range header followed by native function records. The bounded reader rejects
files above 16 MiB before allocation; entry sizes and the complete object
grammar are checked before a hit can skip flow/acceptance/lowering.

Objects are merged in deterministic source order. New records are indexed
once instead of scanning the whole stream twice per group. Project declaration
projections are length-delimited and hashed together. Bundles at most 2 MiB
stay as immutable compilation-owned snapshots; larger bundles are released
before workers and reread/authenticated after they join. Normal operation
retains one bundle rather than accumulating every historical content key.

Missing or malformed objects rebuild from source. Storage publication failure
does not invalidate a successful executable. If a large bundle disappears or
fails authentication after early validation, the first compilation releases
its arenas and retries complete validation/lowering without the cache. The
timing report records `object_cache_retries`; no cached source survives that
retry.

## Current local correctness proof

Current compiler SHA-256:
`2878d6f2ecac3fe9bd709854481046f2fc3f9635ba0f1417f84f5871a2ada6e6`.
Stage 2/3 close byte-exactly.

- The ordinary-build cache proof passes 21 builds, including cold/warm,
  timestamp-preserving body edit, longer body, shifted function IDs, public
  API edit, invalid diagnostic parity, unavailable storage and shared-cache
  publication with distinct executable destinations.
- Independent Python hashes authenticate forged wrong-magic, source-range,
  function-symbol, relocation-offset and truncated-object cases. Each rebuilds
  the affected group and matches fresh executable bytes. A cache-version
  change rebuilds all groups.
- The separately rebuilt fault compiler forces a late reread failure. Its
  warm build retries once, emits every fresh function, preserves the stored
  bundle and matches its direct-build/self-host fixed point.
- Strict stability passes all 13 checks, including 20/20 chained native
  rebuilds, with 231,108,608 peak private bytes and 56,979,456 working-set bytes
  under the unchanged 256/64 MiB child caps.
- Cache falsification peaks at 239,128,576 private and 65,069,056 working-set
  bytes. Its outer guarded process tree peaks at 500,277,248 private bytes
  under the unchanged 512 MiB cap.
- Native conformance passes 278/278, all 25 native x64 ABI/machine-code checks
  pass, and all 20 production-harness/runtime-observer tests pass. The checked-in
  representative CLI, file application and compiler self-build suite passes
  three runs per workload with three compiler generations and exact runtime
  outputs; those filesystem-warm lanes do not claim incremental speed.

## Compiler project economics

The current compiler's independent 11-pair ordinary-build matrix passes all
three economics checks. Unchanged and edited builds win 11/11 above the
71.644 ms null floor. The median cold paired cost is 36.034 ms, within five
percent and below null. Every cold/warm/edit executable matches its fresh
counterpart under strict child memory guards.

| Lane | Direct median | Candidate median | Median paired difference |
| --- | ---: | ---: | ---: |
| Cold | 1.543533 s | 1.582676 s | +0.036034 s |
| Unchanged | 1.554850 s | 0.353936 s | -1.194673 s |
| Body edit | 1.613047 s | 0.578196 s | -1.053183 s |

This establishes a large-project incremental gain on this host. The separate
medium matrix below still blocks default promotion.

## Medium project gate and next architecture

The frozen 24-file fixture has four modules and 3,073 functions. Eleven
alternating ordinary-build pairs compare the cache with `build --no-cache`
on identical inputs, with adjacent direct/direct null pairs. Every executable
matches its fresh-build SHA-256; cold has 0/24 hits, warm 24/24, and body edit
23 hits plus one miss. Each child keeps the strict memory guards.

| Lane | Direct median | Candidate median | Median paired difference | Candidate wins |
| --- | ---: | ---: | ---: | ---: |
| Cold | 116.907 ms | 145.498 ms | +21.703 ms | 0/11 |
| Unchanged | 114.393 ms | 97.082 ms | -10.691 ms | 8/11 |
| Body edit | 119.168 ms | 113.998 ms | -2.244 ms | 8/11 |

The null floor is 15.184 ms. All three economics checks fail: the cold penalty
exceeds both five percent and null, and neither warm/edit gain clears null.
The earlier non-batched bundle was slower on all three lanes; batching improves
the direction but does not qualify promotion.

The next cut must persist content-bound declaration/resolution state, restore
unchanged source records and rebuild the edited source. Its declarations,
types and local/global symbol mapping must be checked against the saved state;
interface/numbering/unsupported changes require the complete fresh path.
Invalid diagnostics, exact output and memory remain mandatory. Repeat both
the 24-file and full compiler paired matrices before promotion, then obtain
final-source C/D, representative and release proof. The original constrained
four-CPU DMD deficit remains a separate open gate.

## Reproduction and raw evidence

`benchmark_native_object_cache.py COMPILER --ordinary-build --fixture medium
--pairs 11 --enforce --report REPORT` enforces the medium gate; use
`--fixture compiler` for the full compiler. The push/manual module proof
workflow runs both matrices after correctness and strict stability, preserving
the failing performance decision in its job result. The production comparator
now explicitly rejects object hits in each clean OpenC sample.

Raw reports are in `OpenC-1.0/build-output/sh27-native-cache/`:

| Report | SHA-256 |
| --- | --- |
| `batched-proof.json` | `c7388cf991ede4a4a88362c02d82afa895ab9322d7e0034ce2d59dcd2f56e79b` |
| `batched-proof-guard.json` | `faa6a8048f2dca2800825966943e75b4619c7ff53938a0061b9490ffdba87da2` |
| `batched-retry-proof.json` | `7fe287e6398ebabaa09278dd0eddd74ffab1186a4390324e33e5375d53255c06` |
| `batched-strict20.json` | `c1a01320ff671171bef3a6dd80ab76fda0651d9bc3f01a3ed53c7e3ee6c8fb31` |
| `batched-medium-pairs11.json` | `dabcdfd4269564a30b063f7d48ad5f511708d892980a13b5a4e79d8683721578` |
| `batched-compiler-pairs11.json` | `a1b7b75814dd508b0b7f2f623ff9c8d743daccd014cb5739abacb63d6229732e` |
| `batched-abi.json` | `175cba3f400d10e657fd6b6f67f50165d1db4990e100a8a829849ce56dc59dc8` |
| `batched-representative.json` | `4128da552bfb5692f171cc8505f3d23b6a40ba338a492f793f8f0a7150c0f78e` |

Earlier individual-file and bundle reports remain alongside these results.
They are architectural comparisons, not final-source parity certificates.
