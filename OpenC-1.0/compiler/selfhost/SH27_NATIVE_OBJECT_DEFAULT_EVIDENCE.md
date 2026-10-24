# SH 27 ordinary build native object and frontend cache candidate

Status: **unpromoted; medium cold cost remains open**. The isolated
`codex/sh27-native-object-default` branch now replays unchanged declaration and
resolution contributions as well as native object groups. Balanced local
matrices qualify the compiler project and the medium project's warm/edit
lanes. The medium cold penalty still fails its unchanged gate. SH-27 remains
active pending that fix, final-source hosted proof, constrained-host parity
and release certification.

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

## Balanced local performance

Current compiler SHA-256:
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
