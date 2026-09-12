# SH-21 OpenC-native benchmark tranche 6 evidence

Status: **PASS FOR THIS TRANCHE; SH-21 REMAINS ACTIVE**.

## Boundary closed

The public OpenC-authored command

```text
openc benchmark --project=PROJECT --output=REPORT.json [--runs=1..20]
```

now owns the required compiler stability, throughput, validation, memory, build
record, and exact-closure gate that previously depended on the external Python
benchmark drivers. It emits `openc.native_benchmark.v1` JSON with every raw
sample. The command and each compiler it launches invoke no Python, D, C
compiler, TinyCC, Microsoft CRT, assembler, or external linker.

The acceptance form always requests 20 chained builds. `--runs` remains
available for diagnostics, but a shorter run cannot pass the 20-generation
closure gate.

## Acceptance results

The final integrated run passes every gate:

```text
chained builds:                 20/20 PASS
exact SHA-256 closures:         20/20 PASS
public build records:           20/20 PASS
public five-run build median:   13,250 ms (limit: at most 25,000 ms)
validation five-run median:      8,760 ms (limit: below 15,000 ms)
peak compiler private bytes:   224,702,464 (limit: 268,435,456)
peak compiler working set:      52,051,968 (limit: 67,108,864)
```

The first five build samples are 13,157, 13,313, 13,250, 13,047, and 13,469
milliseconds. Their validation samples are 8,715, 8,926, 8,760, 8,579, and
9,059 milliseconds. Across all 20 samples, build time ranges from 13,047 to
13,640 milliseconds and validation ranges from 8,579 to 9,076 milliseconds.
Private-byte observations range from 218,554,368 to 224,702,464; working-set
observations range from 46,137,344 to 52,051,968.

Every input and output has SHA-256
`04b765e1bfe242ba92d6373bd84eeb0939bd35a4d3478deec44b5b6fe207c5fe`.
The final compiler contains 121 canonical OpenC source units and 1,732,323
source bytes; the executable is 5,629,440 bytes.

## RAM containment correction

Initial integration correctly exposed a controller-memory defect. The first
hash implementation used `file.read_text`; each compiler hash retained a 5.6
MiB text allocation, so the controller eventually crossed the existing 64 MiB
working-set guard. The correction uses `file.read_bytes_raw`, hashes the raw
buffer, and explicitly frees it after every input and output hash.

No memory ceiling was raised. The benchmark controller remained near 5--11 MiB
working set throughout the final 20-build integrated run, while every compiler
child remained independently subject to the 256 MiB private and 64 MiB
working-set ceilings. The intentionally long 20-build workflow task has a
separate supervised 600-second wall-clock allowance; every individual compiler
child retains the normal five-minute timeout and the benchmark's 25-second
performance gate.

## Integrated workflow and audits

The final OpenC-authored full workflow passes 12/12 tasks:

- identity, target, project, and 5/5 maintained/runtime program checks;
- 367/367 required files, 39/39 pinned hashes, 278/278 fixture identities,
  466/466 active rules, and 174/174 grammar productions;
- 16/16 PE32+, imports, relocation, TLS, unwind, and CRT-absence checks;
- 42/42 framed language-service checks;
- 4/4 adversarial process-supervision checks;
- this 20/20 benchmark gate and 278/278 native conformance; and
- two self-builds plus exact compiler/stage2/stage3 comparison.

The workflow completes in 484.885 seconds and peaks at 19,435,520 private bytes
and 10,702,848 working-set bytes in its controller. Its final PE observation is
seven sections, 28 documented `kernel32.dll` imports, 1,359 runtime functions,
four `DIR64` relocations, and no forbidden CRT import.

## Remaining SH-21 work

The next engineering slice is deterministic OpenC-native release/source archive
construction and verification with bounded streaming I/O. Separately naming
and isolating the optional historical bootstrap/audit kit then remains before
SH-21 can close. Linux and freestanding continue to be optional future targets.
