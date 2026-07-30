# SH-13 native throughput and implementation independence

Date: 2026-07-30
Target: Windows 10.0.19045, x86-64 Hosted
Status: **PASS**

## Outcome

SH-13 makes the 96-source OpenC `.p` compiler tree the sole canonical compiler
implementation, adds native build-phase records, removes repeated full-table
lookups from the dominant lowering path, and proves byte-identical self-host
closure. The standalone compiler archives contain no D source, Python source,
Python bytecode, or DUB manifests.

This milestone does not claim D/ISO-C-class compilation speed or a first-party
native-code backend. TinyCC remains the required packaged C11 compile/link
backend. Python is used only by the external evidence harness and is absent
from, and unnecessary to run, the standalone compiler.

## Closed compiler rebuild

The optimized OpenC compiler rebuilt the complete 96-source compiler twice.
Input, Stage 2, and Stage 3 are byte-identical:

```text
compiler SHA-256:
006ffed8768aeb9050cdb690e3b8db2d835f3a939c82c75f8e40ff46b9628d9e

generated C SHA-256:
cbba2415d0d3e231a458a49f7aa4b3672a19ff41917a5f122e48cdf12659b58c
```

The public `openc build --timings=...` record has schema
`openc.native_build_timings.v1` and reports:

| Phase | Milliseconds | Share |
| --- | ---: | ---: |
| Project load | 32 | <0.1% |
| Declaration collection | 1,546 | 0.3% |
| Resolution | 7,297 | 1.3% |
| Validation | 0 | 0.0% |
| OpenC lowering and C emission | 548,172 | 98.2% |
| TinyCC compile/link | 938 | 0.2% |
| Total | 557,985 | 100.0% |

The SH-12 closed baseline was 780.621 seconds. The SH-13 closed result is
557.985 seconds, a 28.5% elapsed-time reduction, and is below the tightened
900-second self-rebuild ceiling. The recorded TinyCC process consumes less
than 0.2% of the build; the remaining throughput gap is overwhelmingly in
OpenC-owned lowering and generated-compiler execution.

A separate 50 ms PSAPI-monitored rebuild completed in 500.311 seconds with
214,630,400 bytes peak private memory and 14,274,560 bytes peak working set.
It passed every 900-second/256 MiB/32 MiB budget check and produced the same
compiler and generated-C hashes.

Fresh monitored validation completed in 32.612 seconds with 6,434,816 bytes
peak private memory and 8,413,184 bytes peak working set. All 278 fixtures and
every 90-second/16 MiB/16 MiB validation-budget check passed.

SH-13 adds lazy type and expression-child caches and indexes for statements,
blocks, control nodes, expressions, names, declaration owners, and module-top
symbols. Exact compiler and generated-C equality demonstrates that these
lookup changes preserve deterministic output.

## Standalone and dependency boundary

Two independent standalone archive builds are byte-identical:

```text
archive:
OpenC-1.0.0-rc.9-windows-x86_64-hosted.zip

archive SHA-256:
9d344204f97f626cd63c60215c6df43f0c87c849b2e2f5b6962f5d6c42179d98

archive bytes:           3,334,884
ZIP entries:             1,347
manifest file entries:   1,346
forbidden source entries: 0
```

The relocated package gate uses a PATH containing only Windows System32 and
the packaged TinyCC directory. No DMD, DUB, or Python executable is available
to compiler child processes. It passes:

| Gate | Result |
| --- | ---: |
| Stage 2 / Stage 3 compiler equality | byte-identical |
| Generated C equality | byte-identical |
| Maintained programs | 4/4 |
| Public native CLI | 12/12 |
| Native project workflow | 21/21 |
| Native language service | 19/19 |
| Native semantic language service | 23/23 |
| Native conformance | 278/278 |
| Exact diagnostic contracts | 153/153 |
| Runtime fixtures executed | 35/35 |

The dependency boundary after SH-13 is:

```text
canonical compiler source:          OpenC .p
D required to build/run compiler:   no
Python required to build/run:       no
D/Python source in package:         no
TinyCC required backend:            yes
first-party object/link backend:    not yet complete
```

The 93 historical rule-ID compatibility observations remain explicitly
reported separately from the 153 exact current diagnostic contracts.
Linux, freestanding, and Native-provider verification remain optional future
scope and are not Windows Hosted release blockers.

## Reproduction

Build two independent archives, verify the relocated distribution, and compose
the SH-13 result:

```text
python release/build_standalone_windows.py --output build-output/selfhost-sh13/release-a
python release/build_standalone_windows.py --output build-output/selfhost-sh13/release-b
python release/verify_standalone_windows.py --archive build-output/selfhost-sh13/release-a/OpenC-1.0.0-rc.9-windows-x86_64-hosted.zip --comparison-archive build-output/selfhost-sh13/release-b/OpenC-1.0.0-rc.9-windows-x86_64-hosted.zip --output build-output/selfhost-sh13/standalone-verification
python scripts/verify_sh13_throughput_independence.py --compiler PATH/TO/openc.exe --timings PATH/TO/timings.json --rebuild-measurement PATH/TO/rebuild-measurement.json --validation-measurement PATH/TO/validation-measurement.json --conformance PATH/TO/conformance.json --archive PATH/TO/release-a.zip --comparison-archive PATH/TO/release-b.zip --standalone-report PATH/TO/standalone-release-result.json --output PATH/TO/sh13-throughput-independence.json
```

The composed machine result is
`openc.sh13_throughput_independence.v1`; all 22 checks pass.

## Next milestone

SH-14 is native editor integration and language-service resilience:
first-party editor launch, incremental monotonic-version synchronization,
cancellation and workspace lifecycle, and bounded protocol/resource stress.
