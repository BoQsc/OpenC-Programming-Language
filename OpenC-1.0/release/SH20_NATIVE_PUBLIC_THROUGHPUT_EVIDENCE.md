# SH-20 native public throughput convergence evidence

Status: **PASS** on the declared Windows x86-64 Hosted scope.

SH-20 closes the performance gap left by SH-19 without changing the normal
toolchain-independence boundary. The public `openc build` path still performs
project loading, declarations, resolution, flow/safety and acceptance
validation, canonical IR lowering, x64 lowering, and PE32+ emission. It does
not invoke generated C, TinyCC, D, Python, an assembler, an external linker,
or a Microsoft C runtime.

## Exact fixed point and public throughput

The final compiler contains 116 OpenC `.p` source units and 1,605,300 source
bytes. Three successive native builds are byte-identical:

- executable bytes: 4,941,312;
- SHA-256: `b82b228989c915db04370ed9463ac722375c610bbc15c497830b1c39ed707de3`.

The guarded 20-generation public-build chain passes 20/20 with the same hash
at every generation. Across all 20 runs, elapsed time is 16.688 seconds
minimum, 16.931 seconds median, and 18.202 seconds maximum. The five samples
used by the authored release gate are 16.970, 17.112, 17.064, 17.456, and
16.951 seconds: 17.064 seconds median and 17.456 seconds maximum, against the
25-second median and 35-second per-run ceilings.

Full semantic validation in those five builds measures 11.277 to 11.749
seconds with an 11.352-second median, below the strict 15-second gate. Small
clean builds and exact-fingerprint one-source rebuilds both have 0.164-second
medians, below their 0.5-second and 1.0-second gates.

## Same-host C and D comparison

The final comparison pins tool binaries, input trees, raw samples, and hashes.
Clang 16.0.5 builds the TinyCC 0.9.27 ISO C codebase in optimized single-source
Windows x64 mode; DMD 2.112.0/DUB 1.41.0 performs a forced release build of the
retained D compiler. These are external timing oracles only and are neither
invoked by OpenC nor included in its standalone package.

| Five-run median | Seconds | OpenC ratio |
| --- | ---: | ---: |
| OpenC public self-build | 17.064 | 1.000x |
| optimized ISO C compiler reference | 22.732 | 0.751x |
| D compiler reference | 17.504 | 0.975x |

OpenC is faster than both measured reference medians on this host. It is also
well inside the authored limits of 1.25x the slower reference and 2.0x either
reference.

## Bounded memory and packaging repair

Every SH-20 compiler sample enforces 256 MiB private bytes, 64 MiB working
set, and 4 MiB per captured output stream. The maximum observed values are
216,932,352 private bytes and 49,405,952 working-set bytes. No memory or
capture guard fired.

The release builder itself was also corrected after a guarded run exposed an
unbounded path inventory and whole-file ZIP reads. Source discovery now prunes
ignored build trees before traversal; hashing and ZIP compression stream in
1 MiB chunks. Two guarded package builds pass a stricter 128 MiB private / 64
MiB working-set policy. Their observed peaks are 17,981,440 / 24,649,728 bytes
and 18,599,936 / 24,993,792 bytes respectively.

## Correctness and standalone release

- Native conformance: 278/278, zero failures and infrastructure failures.
- Maintained programs: 4/4.
- Complete native workflow: 16/16 tasks.
- SH-18 friendly Windows modules: 27/27 regression checks.
- Standalone release: 20/20 checks.
- Two independently built archives are byte-identical at 3,686,759 bytes and
  SHA-256
  `185bd839ad2265ac22ebee3b260273365dbe21399f3e41bcda9e8602f6f65eef`.
- Both internal manifests have SHA-256
  `576046472aa74427761856e322a27af91e7049fb23b3286c3b6487b6145bb199`
  and cover 1,295 package entries.
- From a foreign working directory with only Windows `System32` available,
  the packaged compiler builds Stage 2, Stage 2 builds Stage 3, and all three
  executables have the final fixed-point hash.
- The package excludes C, C headers, D, Python, Python bytecode, and TinyCC;
  the compiler and Stage 3 import only the 28 documented `KERNEL32.dll`
  functions and no Microsoft CRT.

The friendly-module executable check remains a separately identified
historical C/TinyCC differential audit during SH-20. It is not required by
`openc build` or present in the standalone distribution. Removing Python and
all legacy-tool orchestration from required build/test/release workflows is
the active SH-21 milestone.

## Primary records

- `build-output/selfhost-sh20/native-stability-final-b82b.json`;
- `build-output/selfhost-sh20/compiler-references-final-b82b.json`;
- `build-output/selfhost-sh20/full-workflow-final-b82b/full-workflow-result.json`;
- `build-output/selfhost-sh20/package-a-memory-guard.json`;
- `build-output/selfhost-sh20/package-b-memory-guard.json`;
- `build-output/s20b82b/standalone-release-result.json`.

Linux, freestanding, ARM64, COM, and WinRT remain optional future scope. The
93 historical rule-ID compatibility matches remain explicitly disclosed and
are not used by current conformance execution.
