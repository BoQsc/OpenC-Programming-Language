# SH-21 completion evidence

Status: **PASS — COMPLETE**.

Date: 2026-09-12
Target: Windows x86-64 Hosted
Implementation and required workflow language: OpenC

## Fixed point and throughput

- Compiler source: 130 `.p` units, 1,794,397 bytes.
- Compiler image: 6,110,720 bytes.
- Compiler/stage-2/stage-3 SHA-256:
  `7eea1c053132536398c562a09e46c98478f6f4cde6ddf9a2f706943ee4fbc130`.
- Full workflow: 13/13 tasks, exact stage-2/stage-3 closure.
- Native benchmark: 20/20 builds, 20/20 exact closures, 20/20 build records.
- Enforced build median: 23.094 seconds (limit 25 seconds).
- Semantic-validation median: 14.827 seconds (exclusive limit 15 seconds).
- Peak compiler private bytes: 181,161,984 (limit 268,435,456).
- Peak compiler working set: 53,575,680 (limit 67,108,864).
- Guarded workflow controller peak: 19,922,944 private and 14,491,648
  working-set bytes.

The compiler-source partitioning performed during SH-21 reduced validation
syntax candidates from about 1.05 million in the regressed draft to 491,733
without changing emitted compiler behavior.

## Native correctness and audit ownership

- Conformance: 278/278, zero infrastructure failures.
- Maintained/runtime programs: 5/5.
- Repository: 380/380 required files, 39/39 pinned hashes, 278/278 fixture
  identities, 466/466 rules, 174/174 grammar productions.
- PE audit: 16/16; seven sections, 30 documented Kernel32 imports, 1,405
  runtime functions, four DIR64 relocations, no Microsoft CRT.
- LSP audit: 42/42.
- Residual CLI/project/demo/Windows/WinMD audit: 29/29; 20/20 repeated audit
  stress runs.
- Process guard adversarial checks: 4/4.
- Required legacy-tool invocation: none.

Primary generated records:

- `build-output/selfhost-sh21/full-final.json`
- `build-output/selfhost-sh21/sh21-native-benchmark.json`
- `build-output/selfhost-sh21/sh21-native-conformance.json`
- `build-output/selfhost-sh21/audit-final.json`
- `build-output/selfhost-sh21/pe-final.json`

## Deterministic release boundary

`openc release --root=. --output=build-output/selfhost-sh21/release-final`
uses the 1,608-entry canonical native release plan. It produces independent
standalone A/B and source A/B ZIP files, requires byte equality for both
pairs, validates STORE records/CRC-32/safe paths, verifies the internal
SHA-256 manifest, extracts the standalone archive, reaches exact two-generation
compiler closure, runs the 8/8 packaged daily workflow, passes the 29/29
contract audit, and passes 278/278 conformance.

Archive hashes live in the generated release result rather than this file,
because this evidence file is itself a source-archive input; embedding the
archive hash here would create a self-referential package.

The standalone archive excludes C, D, Python, TinyCC, C headers/runtime,
assemblers, external linkers, and Microsoft CRTs. Retained legacy material is
explicit-only under `historical/`. The previous 93 historical rule-ID
compatibility matches remain disclosed. Linux and freestanding are not SH-21
gates.

## Next milestone

SH-22 PE/COFF ecosystem completeness is active next.
