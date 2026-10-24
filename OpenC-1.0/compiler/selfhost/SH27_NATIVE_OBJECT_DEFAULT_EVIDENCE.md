# SH 27 ordinary build native object and frontend cache candidate

Status: **unpromoted; parallel cold preparation passes local economics**.
The isolated `codex/sh27-native-object-default` branch now overlaps cold
compiler fingerprinting and object-key preparation with native compilation.
The compiler matrix and two independent medium matrices pass their unchanged
cold/warm/edit gates. Final-source hosted proof, constrained-host parity,
representative breadth and release certification remain mandatory. The older
frontend-only candidate's failed medium cold gate is retained below.

## Parallel cold preparation checkpoint

Current compiler SHA-256:
`5b29f1a15059e861ff8918c3b2353af10f1684353d1d4d9c45a2245974adb5ff`
(8,111,104 bytes; exact Stage 2/3 fixed point).

When neither bounded snapshot can be loaded, source groups compile with null
cache offsets. One additional bounded pool job prepares compiler identity and
native keys concurrently. It reads frozen semantic tables, writes only the
cache task's state, and cannot publish an artifact. All work objects are created
before submission; every submitted callback is joined before owners return.
An unavailable API or any work-creation failure completes the same preparation
on the parent after serial chunk recovery. Timings distinguish actual pool
preparation with `object_cache.prepare_parallel`. The cold task never selects
saved objects after workers have committed to compiling all groups.

Native lowering closes additional derived types before worker launch. Cache
identity keeps the original resolved type prefix, matching the warm path's
identity; hashing the closed tail instead caused all warm compiler groups to
miss and was corrected. A missing or oversized frontend snapshot still permits
independently authenticated native object hits. Invalid builds publish neither
frontend state nor object records.

The optional file hash uses a read-only data mapping on the same size-checked
handle, denies writers, and releases its view and handles. It retains the full
compiler-byte SHA and 32 MiB pre-mapping bound. API absence falls back to the
bounded read and exact SHA implementation. Microsoft documents the mapping and
cleanup contracts in [CreateFileMappingW](https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-createfilemappingw),
[MapViewOfFile](https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-mapviewoffile)
and [UnmapViewOfFile](https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-unmapviewoffile).
The isolated mapping experiment saved only about 0.8 ms (6.774 to 5.941 ms)
and failed medium cold economics by itself; it is not a standalone speed claim.

Final-source balanced v2, 11-pair ordinary-build results:

| Project/run and lane | Direct median | Candidate median | Median paired difference | Candidate wins |
| --- | ---: | ---: | ---: | ---: |
| Compiler cold | 1.659231 s | 1.747724 s | +40.797 ms | 3/11 |
| Compiler unchanged | 1.668307 s | 0.091830 s | -1575.924 ms | 11/11 |
| Compiler body edit | 1.736599 s | 0.326627 s | -1415.056 ms | 11/11 |
| Medium first cold | 0.155990 s | 0.169715 s | -5.385 ms | 6/11 |
| Medium repeat cold | 0.115868 s | 0.124490 s | +7.082 ms | 3/11 |
| Medium repeat unchanged | 0.112348 s | 0.041432 s | -70.731 ms | 11/11 |
| Medium repeat body edit | 0.116487 s | 0.056676 s | -62.167 ms | 11/11 |

Null floors are 54.712 ms for the compiler and 11.512/11.153 ms for the medium
runs. Cold passes the unchanged five-percent-or-null gate, rather than proving
zero overhead. The absolute medians and paired differences need not subtract
to the same value. Every candidate image matches its fresh counterpart.

Current local correctness/resource proof:

- Strict 20/20 exact generations and all 13 stability checks pass; maximum
  private/working-set bytes are 237,527,040/59,240,448 under 256/64 MiB.
- Thirty cache builds pass, including missing/oversized frontend recovery,
  selective native corruption, body/API edits, invalid diagnostics, storage
  failure and concurrent publication. Maximum private/working-set bytes are
  253,792,256/65,802,240; the outer guarded tree peaks at 514,097,152 bytes
  under 512 MiB.
- All 25 worker faults pass: absent pool APIs, every ordinary native creation
  site and every cold two/four-worker creation site, including the new cache
  work item. Valid images, program output and semantic diagnostics match the
  serial controls; fallback timing explicitly reports no parallel preparation.
- File-hash probes cover exact 32 MiB, over-limit rejection before mapping,
  empty/missing/Unicode files, an open writer, and 269 calls without handle
  growth. Each of three absent mapping APIs passes three compiler generations,
  exact closure, native/frontend warm hits and independent digest checks.
- Native conformance 278/278, x64 ABI 25/25, named-layout/body/invalid-input
  replay, full validating late-read retry, forced-unavailable SHA and 2/8/32
  source-group COFF with seeded native closure pass.

The general candidate matrix also had rotation cancel its side-order parity
for even candidate counts. Its v2 runner now alternates each fixed candidate
ordinal independently of rotation; a unit test covers one through six
candidates plus null. Legacy v1 timings require balanced remeasurement for
promotion. Thirty-one matrix/batch/representative tests and eight worker-patch
locator tests pass.

The predecessor `67a7ddf` passes hosted C/D run `40117268854` and all module
safety checks; module run `40117269094` fails only the enforced medium cold
economics (+12.557 ms against 1.577 ms null). Those hosted results certify the
predecessor, not the parallel candidate. Final-source hosted and constrained
comparisons remain separate gates.

## Current architecture

Eligible ordinary builds retain two bounded latest-generation files beside
the output: `OUTPUT.exe.openc-cache/objects.bundle` for native function records
and `objects.frontend` for frontend contributions. `build --no-cache` runs the
complete path. The explicit artifact boundary remains `cached-exe`. Stable
COFF exports and project-free native COFF linking remain supported.

The frontend snapshot stores source digests, incoming type/symbol identities,
per-source contribution ranges, declaration projections and complete packed
resolved tables. Unchanged source contributions replay in the original two
ordered passes. An edit runs the ordinary parser/resolver; later contributions
replay only if their incoming type table and symbol numbering still match.
Named-type spelling is part of the incoming identity, so a same-length type
rename cannot preserve stale bindings. The append-only type prefix digest is
reused while the prefix length remains unchanged.

Native object keys bind full compiler bytes, target/schema/worker mode,
project/root, declarations, resolved type identities, function IDs and each
group's source bytes. Named declaration byte offsets are normalized in the
native key because complete declaration spelling is bound separately. A body
length change before a named struct can retain other object groups; a layout
or public API change rebuilds them. Frontend records retain exact source spans.

The frontend reader bounds files to 8 MiB before allocation and verifies the
complete SHA-256 trailer, section extents, contribution ranges, symbol spans,
owners and acyclic derived-type references. Native bundles retain their
independent per-group keys, hashes and record grammar under a 16 MiB bound.
Both files publish atomically after successful compilation. Invalid builds
publish neither snapshot. Storage failure preserves a valid direct build.

Small native bundles remain immutable compilation-owned snapshots. Larger
bundles are released before workers and authenticated again afterwards. A late
read failure releases the first compilation's arenas, then retries full
validation/lowering without caches. The frontend snapshot is not reused by
that retry. Serial/oversized or unsupported projections retain direct builds;
the current reuse boundary requires the closed 2/4-worker path, at most 4 MiB
of source, 128 KiB per source, and 16,384 resolved symbols.

## SHA context and native layout correction

The optional SHA resolver initializes once per process through an atomic
compare/exchange. The winner retains one secure Crypt32 reference until exit;
losing initializers release theirs. An unavailable API is remembered and the
exact OpenC SHA implementation remains the fallback. The native-image resolver
uses the previously unused `.data+0` slot; TLS/argument state and the public
96-byte runtime-data layout remain intact. The separate SH-16 probe image
retains its own data layout. Frontend and native keys share one compiler digest.

A new typed replay test detected an existing native query defect: `size_of`
and `align_of` used a scalar estimator and returned zero for a named struct.
Native query lowering now uses the actual native ABI layout. Concrete tests
require size/alignment 8/4 for two i32 fields and 16/8 after changing one field
to i64, including cross-module return ABI changes and cached/fresh byte parity.

## Prior frontend-only balanced local performance

Prior compiler SHA-256:
`a10814f3c6f71dd2410a533f0647cc62930e636cdbb4340941d926ec1a289863`.

The runner's v1 schedule accidentally canceled process-order reversal when
reversing the lane sequence. Those raw series are diagnostic history and do
not qualify promotion. Version 2 derives comparison order from a fixed lane
ordinal, alternates each lane's sides, and keeps null pairs. Two tests enforce
this independently of lane scheduling. The following are new v2, 11-pair
ordinary-build runs on frozen inputs with strict child memory guards.

| Project and lane | Direct median | Candidate median | Median paired difference | Candidate wins |
| --- | ---: | ---: | ---: | ---: |
| Compiler cold | 1.569062 s | 1.599628 s | +24.342 ms | 4/11 |
| Compiler unchanged | 1.603047 s | 0.090829 s | -1513.201 ms | 11/11 |
| Compiler body edit | 1.590204 s | 0.317874 s | -1263.949 ms | 11/11 |
| 24-file cold | 0.111204 s | 0.125245 s | +12.422 ms | 1/11 |
| 24-file unchanged | 0.109984 s | 0.040529 s | -67.237 ms | 11/11 |
| 24-file body edit | 0.110950 s | 0.057357 s | -60.340 ms | 11/11 |

Compiler null is 49.735 ms and all three compiler checks pass. Medium null
is 9.810 ms: warm/edit pass, while cold exceeds both five percent and null.
Every image matches a fresh build. Cold frontend/object hits are zero; warm
frontend replay covers all 230 compiler files (all 24 medium files), and a
body edit replays 229 (23) frontend contributions plus 31/32 (23/24) objects.

An isolated DLL diagnostic independently checked SHA digests against Python.
For the 8,077,312-byte compiler, 31 warmed samples measure 3.9325 ms for hashing
resident bytes and 6.8156 ms for bounded file read/hash/free. This identifies a
material fixed cold cost. Next test a same-handle mapped-file fingerprint and
cache publication batching while preserving complete-byte authentication;
metadata-only shortcuts do not qualify. Final-source balanced repeats remain
mandatory after any implementation change.

## Current local verification

- Exact Stage 2/3 fixed point and strict 20/20 native rebuilds pass, including
  all 13 stability checks. Strict peaks are 236,347,392 private bytes and
  58,232,832 working-set bytes under the unchanged 256/64 MiB caps.
- The ordinary cache proof passes 29 builds: body/length/API/local-ID edits,
  invalid diagnostics, missing storage, shared publication, native corruptions
  and frontend checksum/version/extent/symbol/span/owner/type-cycle/oversize
  faults. Cache-test peaks are 251,187,200 private and 65,814,528 working-set
  bytes; the outer process tree peaks at 513,359,872 private bytes under 512 MiB.
- The rebuilt late-read fault compiler proves one complete validating retry,
  unchanged saved storage and exact direct-build/fixed-point output.
- Sixteen simultaneous first-call SHA clients pass 3,840 independently checked
  digests per test, including empty, SHA block/padding and large inputs. The
  forced-unavailable API compiler also closes exactly and relinks identically.
- Named-layout/body-span/provider/type/import-use cases match fresh output,
  runtime and rejection diagnostics. Rejected edits leave both cache files
  unchanged. The named-span edit retains three of four native groups.
- Native conformance passes 278/278; all 25 x64 ABI/machine-code checks pass.
  The representative CLI, file application and compiler suite passes three
  runs per workload with three compiler generations and exact runtime outputs.
  These filesystem-warm representative lanes do not claim object-cache speed.
- Source-group COFF variants 2/8/32 and COFF-seeded native closure pass. Tests
  now derive source counts from the manifest rather than hardcoding 228.
  Thirty batch/matrix/representative/order harness tests pass.

The earlier candidate's hosted production comparison passed in
[run 40109648117](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/40109648117).
Its module proof stopped on the hardcoded source-count assertion, and also
failed the medium economics gate. The assertion is corrected and proved
locally. That hosted source predates frontend replay and does not certify this
compiler. Final-source C/D, constrained-host, editor and release gates stay open.

## Raw reports

Reports are under `OpenC-1.0/build-output/sh27-native-cache/`.

| Report | SHA-256 |
| --- | --- |
| `identity-proof.json` | `9e09257193ec7195c76b1075aa57ef59114091d2c46d8c8c377319ba3eae85bf` |
| `identity-proof-guard.json` | `db83b58693a8dff7747ab765fe59324ad90fb8355d4b9d0578893a376369b4e0` |
| `identity-strict20.json` | `2453722b1a4c28c75e67391eedb6ab9683fcc8159a37fced9688b2da73b63e22` |
| `identity-abi.json` | `be4846bca2d805c10556435afd580721ae89497d3ab34d850b3bc706e6368f77` |
| `identity-hash.json` | `b322a3fc7fd8440fd77be9101d900fdf66dfb6284e03abb9f806272321ac0867` |
| `identity-retry.json` | `30960d1b557ffd7f659e7b7cddc569c7a84c52c537f3ecb0005017ac883906be` |
| `identity-compiler-balanced11.json` | `50e9b36f8545b415d967adcac058fb7f661c31f5e0b1dcacd5edc3589332cbbe` |
| `identity-medium-balanced11.json` | `32a75140581641149dbf865f9de53a7759b26df867f313ff5a5c012d8bc6f285` |
| `identity-representative.json` | `f48ff2355d0cf718b1a8937b5e146a5cb6176b23401afdca706c69c7d92ca2fd` |

Earlier v1 timings remain archived beside these reports, excluded from the
promotion decision. The prototype, a compiler-only win, or one hosted pass
cannot close SH-27.
