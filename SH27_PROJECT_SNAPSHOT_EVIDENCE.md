# SH-27 content-validated whole-project no-op snapshot

Status: **isolated opt-in cut; local and hosted module-COFF proof passed;
default-production and SH-27 closure open**.

The restricted Windows x64 serial `module-coff-set --cache-prefix` path now
publishes a compact project validation record only after successful whole-
project acceptance, object publication, native link, and COMPLETE manifest.
The record is keyed by cache schema/target/policy, actual compiler executable
SHA-256, exact project manifest and root, canonical module names, and every
source's stable in-memory bytes with length delimiters. It contains the entry
symbol, canonical object digests, and a checksum. The reader bounds allocation
to 4,308 bytes, checks schema/input/count/entry/digests/checksum, then reads,
authenticates, and parses every saved COFF object before replacing outputs.
An absent, corrupt, oversized, or stale record takes the ordinary full
validation path. Changed source bytes cannot inherit the previous validation.
The cache remains local user-controlled storage; its checksum is not a remote
cache signature or protection against a malicious local writer.

On a valid no-op hit, the compiler now skips lexing, parsing, declaration,
resolution, flow, acceptance, IR lowering, and native object emission. It
relinks authenticated objects and emits the same per-module object paths and
manifest schema. Timing JSON reports `validation_skipped: true`, zero syntax
nodes/functions, and actual object hits. The opt-in restrictions from
`SH27_AUTO_MODULE_CACHE_EVIDENCE.md` remain: 64 modules, 4 MiB total source,
128 KiB per source, bounded COFF bundle/symbols, console target, and no shared
runtime `.data` objects. Public `check` and normal `build` behavior are not
changed by this cache mode.

## Falsification and measurement

Final local fixed-point compiler SHA-256:
`0821055a370bc00f7babfacc24327cf62ac36cdcf41bfede5635121b72dd144d`.
Stage 2 and Stage 3 are byte-identical. The raw ignored local reports are in
`OpenC-1.0/build-output/sh27-project-snapshot-bootstrap-20260926e/`.

- `test_module_object_cache.py` passes independent Python SHA-256 oracles for
  the compiler/input project key and snapshot checksum, exact warm COFF/PE
  and runtime behavior, corrupt checksum and 128 MiB snapshot fallback,
  object/key corruption fallback, changed body/API/invalid source,
  unavailable storage, and concurrent writers. Python is a test oracle only;
  OpenC owns the build/cache/link path.
- Five local paired 24-file/1,153-function runs: full COFF median **1.544 s**,
  content-validated no-op **0.273 s**, changed-body **0.603 s**, and ordinary
  native build **0.392 s**. Paired no-op gain over ordinary native build is
  **0.110 s** locally. Every no-op has four object hits and zero semantic,
  syntax, or lowering work; every edited build validates and recompiles only
  the changed module. Fresh and cached COFF/PE bytes and runtime exits match.
  The local benchmark is not yet a clean-hosted or default-policy speed proof.
- Strict Stage 3→4 self-build: 20/20 byte-identical chained generations and
  13/13 checks. Peak child private **266,633,216 bytes**, working set
  **63,672,320 bytes**, and Job private **266,633,216 bytes** are below the
  256/64/512 MiB limits respectively. Bootstrap Stage 2 uses the separate
  512 MiB transition guard and is **not** claimed to meet strict 256/64 MiB.
- Native conformance `EXECUTED_NATIVE` **278/278**, zero failures and
  infrastructure failures, under a 512 MiB Job/128 MiB working-set guard.
  Bounded saved-COFF reader (3 cases), module COFF set, and selected-module
  mixed-object/failure-diagnostic tests pass locally.

The independent [hosted Windows workflow run
36265721024](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/36265721024)
passed every module-COFF step on commit `a9785da` (artifact
`10913876523`, compiler SHA-256 identical to the local value above). Hosted
strict self-build passed 13/13 checks and 20/20 byte-exact generations with
peak child private **266,682,368 bytes** and working set **64,884,736
bytes**. The hosted five-pair 24-file medians were full COFF **0.788 s**,
validated no-op **0.106 s**, edited body **0.282 s**, and ordinary native
**0.189 s**; the observed paired no-op advantage over ordinary native was
**0.083 s**. Raw `strict20.json` and `cache24.json` were downloaded from
the hosted artifact to the ignored local `hosted-36265721024/` directory.
This is a repeatable opt-in workload observation, not a default-build or
representative-project parity claim.

The separate [branch batch run
36265721035](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/36265721035)
failed its required cold-compile gain/noise gate: large-functions paired
median **-0.002 s** with 7/11 wins below 0.009 s null noise, control-flow
**+0.002 s** with 5/11 wins below 0.005 s null noise. This cut is not a
claim of faster cold/default compilation.

An initial version hit a checked failure on warm cleanup: a scoped destructor
captured a growable bundle's original allocation after reserve replaced it.
The current allocation is now destroyed explicitly on every return. The
initial strict self-build then failed twice near the 256 MiB private cap even
though the same command passed unguarded. Reducing the up-front semantic-error
buffer cushion from 65,536 to 8,192 records (while retaining the source-size
term) restored the full guarded 20-generation chain; the 278 native fixtures
also pass. The failed reports remain in the ignored `...20260926d/` directory.

## Remaining SH-27 work

This snapshot improves exact no-op builds only. Public-interface edits still
conservatively invalidate every module. Dependency-complete transitive keys,
general shared-data/runtime object support, larger retained projects, default
build integration and repeated clean hosted C/D/default speed proof remain.
The final combined source still needs two independent parity runs, strict
correctness/RAM/release integrity and a matching clean-profile editor 14/14
audit before SH-27 can close.
