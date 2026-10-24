# SH 27 ordinary build native object and frontend cache candidate

Status: **unpromoted; hosted cold economics and final-source proof remain open**.
The isolated `codex/sh27-native-object-default` branch now overlaps cold
compiler fingerprinting and object-key preparation with native compilation.
The compiler matrix and two independent medium matrices pass their unchanged
cold/warm/edit gates. Final-source hosted proof, constrained-host parity,
representative breadth and release certification remain mandatory. The older
frontend-only candidate's failed medium cold gate is retained below.

## Current digest/scratch and peak-guard checkpoint

### Hosted evidence for `2832d79` and the next ownership/publication candidate

The downloaded raw artifact for production run `40124695875` proves
`PASS_PARITY`, all twenty comparator ceilings, 20 samples per cell, and the
`e0299413...` compiler below. Its ZIP SHA-256 is
`c0f72570b74c140e229deacc14d39a1e2b0ed0da83f7131c74a747a92ea585d7`;
the extracted `sh27-production-comparators.json` SHA-256 is
`cd1ab9ffa10ff39bc26ca2a941c7f35cf3fc02d370e2c81329694baf32df8bd4`.
Hosted large/control are 0.419x/0.215x DMD. This is one hosted certification,
and does not erase the constrained-host failure or certify subsequent source.

Module run `40124695871` passes bootstrap, bounded reads and all 30 cache
cases, but fails the forced late-read retry at 67,469,312 peak working-set
bytes under the unchanged 67,108,864-byte cap. Its medium cold gate also
fails: +7.417 ms against 1.516 ms null, direct median 106.839 ms. Compiler
economics passes. All later safety steps skipped after the retry failure
remain unverified on that hosted run. The downloaded module ZIP is verified
as `4dce9c85172efc4b2e6e483a8f546b4d9c9f02fb5f44790eb2637ffab43655d1`.

The next source authenticates every evicted hit before allocating merged
destination streams. A failed reread releases its saved owner immediately;
successful merging releases the saved bundle before PE linking. A serial
publication releases the encoded next bundle before linking as well. These
are changes to object lifetimes, with no memory threshold changes.

Four separately bootstrapped diagnostic variants omit publication I/O,
frontend encoding, native encoding, or both encodings. All generated medium
images match. In 11 balanced pairs, removing I/O costs -5.017 ms, 7/11 wins,
against 4.272 ms null. Removing both encodings costs -9.688 ms, 8/11 wins;
the single-component ablations are noisy. These incomplete-cache binaries
are diagnostic only and cannot be promoted.

The joined-publication candidate uses the existing bounded one-work pool
machinery: an immutable encoded bundle/path belongs to the publication
callback, while the caller owns PE linking and its mutable context. Submission
and both operations finish before returning or releasing borrowed buffers.
Missing APIs or work-creation failure use the complete serial fallback.
`object_cache.publish_parallel` records actual successful pool setup; a warm
all-hit link starts no publication job. The worker fault proof now covers
the extra creation site and all four absent APIs, including serial publication.

Candidate compiler SHA-256 is
`eaa0017defb9cd4691239f0e3ae293ae9483799e13fc50c9bec24920086abe56`
(8,133,632 bytes; exact Stage 2/3 bootstrap). The local late-read proof passes
at 60,342,272 peak working-set bytes; all 30 cache cases pass at 61,251,584
peak working-set and 248,905,728 private bytes. The initial medium economics
run passes only its noise alternative (+9.944 ms versus 23.078 ms null), so
it is not evidence that cold overhead is resolved. Same-size owned-binary
publication ablation gives -18.290 ms medium (9/11 wins versus 15.148 ms
null) and -81.039 ms compiler (8/11 wins versus 62.879 ms null). Both sides
use the same-size compiler image; the serial control replaces only the
publication work-creation call with a failed creation, exercises cleanup and
serial fallback, and produces identical images. This supports overlapping
publication; it does not establish final ordinary cold economics.

The comment-frozen source rebuilds to the same `eaa0017d...` SHA in three
guarded stages. It passes strict 20/20, all 278 conformance cases, 25 ABI
checks, legacy module-cache behavior, and 26 worker-setup faults. The complete
30-case cache proof also passes inside an outer 512 MiB job guard, with
516,554,752 peak aggregate private bytes. Fresh hosted and constrained-host
proof, representative breadth and release certification remain open.

The first final-source four-CPU, pinned-DMD 20-sample diagnostic passes all
five available public ceilings: large 224.822/186.221 ms = 1.207x; control
94.130/125.104 ms = 0.752x. Large still lacks 1.357 ms for the 1.20x internal
margin, and an independent repeat is required. Missing local C/LDC tools
leave the overall status `PARTIAL_COMPARATOR_SET`. This unpaired comparison
with earlier revisions cannot attribute a source speedup. All three retained
representative projects pass three cold/warm/edit repetitions with three
compiler fixed-point generations (`publication-representative3.json`);
cross-language representative proof and broader project coverage remain open.
The representative C/D workflow now also triggers on this isolated branch,
using its existing reviewed literal toolchain pins and manual entry point.

Raw local reports under `build-output/sh27-native-cache/`:

| Report | SHA-256 |
| --- | --- |
| `publication-strict20.json` | `5aaf0544eae72781a03d23a930494bcae88b607578047a3884eef1e1792e69d7` |
| `publication-cache-guard.json` | `0ee9fea798b271cdaaca1fde602245441ea957a074a51439465d15d57b6d77e5` |
| `publication-cache-guarded.json` | `4adf1349cead61948139c58702443e12f8eb204f2287f4056fa01eccfb4f7067` |
| `publication-worker-pool.json` | `d0f5a359804143059ee17dc115b74baef16295c1a3308bd310d18ff4ea4f381f` |
| `publication-pairs/report.json` | `6fb4c7abf33841849ea5feaee75b7c78bda20f4d17dcd97f5693e6a11fe54d20` |

Preceding compiler SHA-256 is
`e02994136860f9dbc8181af0696364d58b19dbb0b5157288d8773d4fe59763b6`
(8,126,976 bytes), with exact Stage 2/3 bootstrap under the corrected peak
working-set guard. The 5b29 checkpoint and its measurements below are history.

Cold source/type-prefix digests now materialize in the cache job from recorded
contribution boundaries and frozen type/source bytes. Declaration projections
are copied before launch: native workers consume and release retained parsed
records. An attempted deferred AST projection failed the named-type proof and
was corrected; background native key preparation no longer even looks up a
parsed record when it already owns a declaration projection. Type-prefix hash
scratch is sized from actual records and named spelling within the original
bound, and reused across prefixes, rather than allocating a project-sized
buffer for every prefix change. Warm-hit validation remains ordered and exact.

A RAM audit caught a real guard defect. The Python sampler reported OS peak
working set, but enforced only sampled current working set and omitted a final
peak check. A 70,393,856-byte cache-test peak was therefore labeled PASS under
a 64 MiB cap. That run is excluded from acceptance. Three regression tests now
enforce an earlier peak, a peak first observed after exit, and the exact cap;
both CI workflows run them. The corrected guard reproduced the failure at
70,791,168 bytes in `cache-version-change`.

The rejected native bundle still owned its large allocation after its length
was set to zero. The small-buffer eviction test consequently retained roughly
9 MB through every worker. Invalid bundle grammar now releases the allocation
immediately and replaces it with an empty owner. With the corrected guard,
`peak-fixed-proof.json` passes all 30 cache cases at maximum 245,170,176 private
and 63,676,416 working-set bytes, below the unchanged 256/64 MiB limits. This is
a source fix, rather than an exception to the resource gate.

The preceding scratch-only compiler `f6b3f092...` passed the four-CPU medium
matrix's unchanged gate, but still cost +12.064 ms cold against 21.998 ms null;
warm/edit won 11/11. The earlier deferred-digest prototype failed that gate
at +26.595 ms against 21.825 ms null. These separate source runs do not prove
a paired speedup or eliminate cold overhead. Final-source compiler/medium
economics and constrained C/D proof must still be repeated.

Hosted source `693c275` passed the full C/D workflow `40119581212`. Its module
workflow `40119581236` failed medium cold at +10.170 ms versus 2.689 ms null,
and an exact legacy-cache dictionary assertion omitted the new
`prepare_parallel: false` field. That assertion is corrected and the complete
legacy cache test passes locally. The hosted failure remains disclosed;
it does not certify this newer compiler.

The native subprocess supervisor now reads OS peak working set during live
supervision and captures retained peak working-set/commit counters after exit,
before closing the child handle. Its live and post-exit 64 MiB probes pass.
An owned compiler variant waits for exit before its first poll, so the final
query is the only possible source of counters. Removing only that query makes
both the small-child accounting and over-budget rejection controls fail as
expected. These six observations are in `native-peaks-proof-final.json`.

Final `e0299413...` source passes all 13 stability checks and 20/20 exact native
generations with 238,350,336 private and 61,071,360 peak working-set bytes.
Its 30-case corrected-guard cache proof peaks at 245,960,704 private and
63,864,832 working-set bytes; the outer tree is 516,886,528 bytes under 512 MiB.
Conformance passes 278/278 and x64 ABI 25/25. Final-source hosted, constrained,
representative speed/breadth and release requirements remain open.

## Parallel cold preparation checkpoint

Parallel-preparation compiler SHA-256:
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

Two final-source 20-sample DMD-only diagnostics use the retained pinned
2.112.0 executable (`5ec3152d...`), affinity mask `0xf`, the original production
corpus and 512/512 MiB corpus guards. The host exposes 12 logical CPUs; this is
a four-CPU constrained run, not a claim that the host has only four CPUs.
The separate strict self-build caps remain 256/64 MiB.

| Four-CPU run | Large OpenC / DMD | Ratio | Control OpenC / DMD | Ratio |
| --- | ---: | ---: | ---: | ---: |
| First | 238.535 / 189.625 ms | **1.258x FAIL** | 85.939 / 116.787 ms | 0.736x |
| Independent repeat | 404.282 / 755.387 ms | 0.535x | 155.439 / 566.330 ms | 0.274x |

All four other available ratios and all execution/resource checks pass in
both runs. Both reports are `PARTIAL_COMPARATOR_SET` because MSVC, Clang and
LDC are absent. The first run still needs 1.504 ms for the public 1.25x gate
and 10.985 ms for the 1.20x internal margin. The same compiler produced both
series, and both compilers' medians moved substantially; the repeat does not
erase the first failure or establish a source speedup. The first run's median
large-function declarations/resolution are 62/15 ms; critical-worker wall is
132.5 ms, with 31 ms acceptance and 32 ms native emission. These are nested
phase diagnostics, not additive or high-resolution savings budgets.

Representative CLI/file-application/compiler correctness passes three runs
per workload and three compiler generations. The current SHA first-call race
also passes all 3,840 independently checked digests. These checks do not certify
representative cross-language speed or close constrained-host consistency.

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
material fixed cold cost. It motivated the mapped-file diagnostic and parallel
preparation checkpoint above. Metadata-only shortcuts do not qualify;
final-source balanced repeats remain mandatory after implementation changes.

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

## Current peak-guard raw reports

| Report | SHA-256 |
| --- | --- |
| `final-peak-cache.json` | `967384663b76871a346abb700b6016084e8c05946bc26ee8194766fa5bb624a7` |
| `final-peak-cache-guard.json` | `7a70de32defce9566d6394f91fa7a45d3ab48a4c9872f052f6491dde0b664c17` |
| `final-peak-strict20.json` | `2cb8e12af26e834915239bf362ccae65389ad741d183c15588bec2971c1b732a` |
| `final-peak-conformance.json` | `3dd7d80aeab7a152e4ba75ad2414e6e4cddef948b7b75b7f1cfc4d4577354c3b` |
| `final-peak-abi.json` | `18aa690ae2c6b4a8d61f7744564500dd626aa4b4a84488d0331b9fdeb87ecc14` |
| `native-peaks-proof-final.json` | `e6b01888321c42022a321ed33fdcb8f0ce7d163e88a2ef2478fd2513d24f441d` |
