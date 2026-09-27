# SH-27 retained-syntax COFF identity cut

Status: **local fixed point, exact-output paired gain, cache and strict-memory
proof PASS; final-source hosted proof and normal-default policy pending**
(2026-09-27). This is an opt-in source-partition cache improvement, not SH-27
completion.

The preceding cold COFF source spent roughly one second after native workers
finished. A new additive `coff_partition_profile_ms` timing breakdown showed
that stable COFF symbol identity alone consumed a median **719 ms** in a
five-pair direct-versus-cached experiment. The stable-identity routine read,
lexed, and parsed every source again after the native workers had already
used and released the resolution parse cache. A substitution of the existing
large-buffer accelerated digest did not help: it won only 2/5 pairs and its
identity median stayed at 703 ms, so that substitution was reverted.

The retained-syntax cut computes exactly the same canonical symbol hashes
from resolution's already-parsed syntax before the native workers release it.
The hashes and offsets are held in a small cache-owned buffer until object
construction and then freed with the cache state. Missing retained syntax
still uses the original read/lex/parse path; uncached COFF output is unchanged.
The build report now separates stable identity, partition selection, COFF
object construction, digesting, file publication, bundle copying, cache
publication, and native linking. `total` is the cached object-writer phase;
the candidate's `identity` is prepared before worker launch and is therefore
not a child of that `total` value.

On the identical 228-source compiler project, the guarded, order-alternated
11-pair old/new cold-cache matrix passed byte-exact PE comparison:

| Measure | Previous source | Retained-syntax source |
| --- | ---: | ---: |
| Cold 32-object wall median | 8.441 s | 8.113 s |
| Stable-identity median | 782 ms | 203 ms |
| Cached object-writer median | 1,359 ms | 531 ms |
| Native worker-wall median | 3,266 ms | 3,157 ms |

The candidate won **7/11** whole-build pairs; the median paired wall delta
was **-0.432 s**. Whole-build samples had appreciable host jitter, including
four candidate losses, so the 579 ms identity-phase saving is stronger causal
evidence than the wall median alone. An earlier five-pair matrix won 5/5,
with exact output and a -1.259 s median paired delta. Baseline compiler
SHA-256: `b472190df89359701d70892c11ff7b21873b702c88ac07a21f7a3466fd812c26`;
candidate fixed-point compiler SHA-256:
`0c83deac588cfb81968f652cd7a77f28fc0f9ffa2c9342992a511711e634e0ca`.

The same candidate passed:

- three-stage byte-exact native self-hosting;
- the 32-partition cold, no-op, corrupted-object, implementation-edit,
  fresh-edit, interface-edit, and pointer-flow invalidation cache suite,
  with exact fresh/cached output and child memory caps;
- 2/8/32 source-partition COFF and seeded self-host fixed point;
- 278/278 native conformance fixtures;
- strict 20/20 chained self-build, peaking at **227,033,088 private bytes**
  and **54,116,352 working-set bytes** (under 256/64 MiB caps);
- 22 SH-27 benchmark-harness unit tests.

Ignored raw reports are under
`OpenC-1.0/build-output/sp27-coff-profile/` and
`OpenC-1.0/build-output/sp27-identity-reuse/`. A same-source five-pair
direct-versus-cold-cache comparison still measured **6.738/7.703 s** medians,
so cold cached output remains about 0.97 s behind direct PE on this host.
The normal default is unchanged. The next cost targets are the remaining
object writer/link and cache publication path, plus a production-policy
decision tested on retained real projects. Final-source hosted RAM,
representative, two-run pinned C/D parity, editor, and release gates remain.
