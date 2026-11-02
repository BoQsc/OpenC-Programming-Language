# SH-27 automatic native module-object cache

Status: **isolated opt-in cache implemented and locally falsified; not a
normal-default throughput promotion or SH-27 closure**.

```
openc artifact --project=PROJECT --kind=module-coff-set --output=PREFIX
  --linked-exe=PROGRAM.exe --cache-prefix=EXISTING_DIRECTORY/CACHE
  --timings=TIMINGS.json
```

One native OpenC invocation now chooses object hits and misses, validates the
entire source project, lowers/emits missed modules only, and links fresh plus
authenticated saved COFF objects. Python, D, TinyCC, C headers/compiler, CRT,
an external assembler and an external linker are not in this build path.
The command is still restricted to the existing console Windows x64 serial
module-COFF boundary: 64 modules, 4 MiB source input, 128 KiB per source, 4096
symbols and an 8 MiB saved-object bundle. Unsupported projections fall back to
the existing full module build; shared runtime `.data` remains fail-closed.

## Keys, authenticated snapshots and publication

- Keys include schema/target/emission policy, exact project manifest,
  SHA-256 of the actual compiler executable, all source text outside ordinary
  function bodies, and the owning module's full source contents with explicit
  length delimiters. Source bytes are the same stable project views used by
  parsing/resolution/acceptance, not a later unvalidated reread.
- A body-only edit misses its owning module. ANY declaration/interface,
  import, constant, layout, attribute, manifest or compiler change
  conservatively misses every module. This is dependency-safe but is **not**
  selective transitive-dependent invalidation yet. Conditional declarations
  and unfamiliar parser body ordering cannot silently obtain cache keys.
- A 130-byte key/object-hash record is read with a pre-allocation limit. The
  key must match its expected input; object hashes are lower-case hex, and
  object bytes must authenticate and parse before becoming a hit. Accepted
  object bytes are retained in a bounded in-memory snapshot for this build.
- Object files are content-addressed. Publication first claims a temporary
  file with `CREATE_NEW` (collisions never truncate another writer), closes
  it, then calls documented `MoveFileExW` with replacement/write-through and
  no cross-volume copy. Only after object publication is its record published
  the same way. This is recoverable local cache publication, not a promised
  transactional or power-loss-durable database.
- Missing, corrupt, oversized or wrong-key records and damaged object bytes
  are misses. Unavailable publication storage does not fail a valid build;
  a report counts publication failures. Incomplete/orphaned temporaries are
  ignored. Garbage collection and cleanup after failed renames remain open.
- This is a local cache under the user's control, not an authenticated remote
  execution/cache service. It does not protect against deliberate replacement
  of a valid input-key record with an attacker's matching object hash.

For large cache hashes only, a compiler-private native hook optionally uses
documented [`CryptHashCertificate2`](https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-crypthashcertificate2)
with SHA256 from the system DLL. The existing OpenC SHA-256 implementation is
the fallback. There is no new ordinary-program import or third-party library;
the system function is resolved dynamically only on the opt-in cache path.
Small digests retain the OpenC implementation. An independent Python oracle
in the tests verifies the complete compiler/input key, and verifies emitted
object digests. Python is solely a verification harness here.

## Actual large-case defects found and repaired

The first 24-file attempt exposed the restricted linker's fixed 1 KiB code,
section and definition scratch buffers. They now grow under the existing
limits before append; tiny-link proofs did not cover this defect. A retained
1153-function/four-module case now exercises growth of sections, symbols,
unwind records and cross-module relocations.

The first cache implementation used the scalar OpenC SHA on the whole compiler
and duplicated object hashes. Later measurements also exposed repeated whole-
syntax scans for each function and unnecessary whole-project stable-symbol
reconstruction for a cached link's entry. Large hash acceleration, a checked
single-pass interface-body projection, and entry-only identity preparation
remove those costs. Stable COFF body selection likewise takes the checked
parser-order fast path with the old projection as fallback.

## Executed current local proof, 2026-09-26

The final guarded bootstrap reaches byte-exact Stage 2/3 SHA-256
`f4669040b8b8b28bd30a1a92fd8f24db285394918145cc23a891ca52dd4e05b4`.
A separately strict Stage 3→4 build reproduces it. Stage 4 peaks are
62,455,808 working-set, 266,362,880 private and 267,231,232 Job-private bytes,
within the 64/256 MiB child caps. **Stage 2 still exceeds those strict caps**:
69,914,624 working-set and 271,339,520 private bytes; bootstrap uses separately
declared 512 MiB guards, not a strict Stage-2 pass.

`test_module_object_cache.py` passes guarded tests for real 3/3 no-op hits
with zero lowered functions, 2 hits/1 miss after a body edit, all misses after
same-width declaration rename, exact objects/PE/execution versus clean builds,
damaged objects, 128 MiB records, wrong input keys, changed compiler identity,
four concurrent cold writers, unavailable storage, and exact rejection
diagnostics despite existing cached objects. The test tree peaks at
109,174,784 Job-private and 26,247,168 working-set bytes. Existing stable-symbol
10-check/default artifact, module saved-link/failure and bounded-reader 3-case
suites pass again.

`benchmark_module_object_cache.py` passes five paired full/no-op repetitions
and five distinct body edits on 24 files/1153 functions, with exact clean
COFF/PE and runtime behavior. No-op hits all four modules and lowers zero
functions. An edit hits three and recompiles 288 functions in one module.
Peak child working-set/private bytes are 16,691,200/29,261,824.

| Local lane | Median wall seconds |
| --- | ---: |
| Full restricted COFF build/relink | 1.223 |
| Cache no-op | 0.335 |
| Cache body edit | 0.456 |
| Ordinary native executable build | 0.325 |

Median paired gains against a full COFF rebuild are 897 ms no-op and 785 ms
edit. **Against ordinary native compilation, no-op remains 11 ms slower in
paired observations.** This is a generated cache-scale test, not a retained
user project, null-controlled gain qualification, C/D comparison, or normal-
default speed certificate. Do not promote it merely because its correctness
workflow is green.

Raw local reports remain under
`OpenC-1.0/build-output/sh27-auto-cache-20260926/`; `cache24-current.json`
SHA-256 is `ff21a118b18f63a76b3af1a8ab538c3ead40b02d6119414fc485a742a81e58a7`.
The commit-triggered/manual workflow now runs cache falsification and 24-file
measurement before its complete strict20 chain; hosted proof of this cache
source is pending at this checkpoint.

## Hosted current-source proof

The clean [push-triggered run
36263328048](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/36263328048)
passed bootstrap fixed point, bounded input, module/selected-module/cache
falsification, the 24-file benchmark, and all 13 strict stability checks with
20/20 byte-exact chained native rebuilds. Compiler SHA-256 matches the local
fixed point above. Chain maxima are 64,532,480 working-set and 267,694,080
private/Job-private bytes; private headroom is only 741,376 bytes, not evidence
of a generous RAM margin. Hosted Stage 2 still exceeds strict caps at
70,955,008 working-set and 271,388,672 private bytes.

Raw artifact `10912623492` (`OpenC-SH27-module-COFF-36263328048`) includes
`strict20.json` SHA-256
`7f07c29698ce20118439e619fa63619e165d9b6fb0ba74792f0fe82b2cc7a36d`
and `cache24.json` SHA-256
`8cabd80136642a5e8485b73f0cbf4b4deaa0068d68d0e24848f80cef1950cd72`.
The cache recovery/concurrent-writer suite passed at 112,975,872 Job-private
peak. The 24-file child peak was 17,944,576 working-set and 29,298,688 private.

Hosted full-COFF/no-op/body-edit/normal medians were
0.778/0.178/0.260/0.188 s. Paired no-op/edit gains versus full COFF were
600/527 ms; no-op versus ordinary native was only 10 ms. Together with the
local 11 ms regression, that does not establish a robust normal-build win.
The separate [cold throughput batch
36263327847](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/36263327847)
failed its gain/noise gate (4/11 wins on each lane). No normal-default speed
promotion or new-source C/D parity is claimed. Manual dispatch is configured;
only the push trigger was exercised here.

## Next required work

Implement an authenticated input-matching whole-project validation snapshot
for real no-op front-end skipping, with changed/invalid inputs always taking
full validation. Replace conservative global-interface invalidation with
complete selective transitive-dependency keys. Extend shared runtime/data
ownership and ABI/project breadth; prove normal-default cold/no-op/edit wins
on real projects, failure recovery and memory before integrating into normal
`build`. Recertify the same integrated final source, performance twice, and
release/editor integrity. This opt-in cache alone closes none of those gates.
