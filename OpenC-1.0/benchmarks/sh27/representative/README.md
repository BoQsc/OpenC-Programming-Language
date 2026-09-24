# SH-27 representative-project suite (v1)

This suite complements, rather than replaces, the generated SH-27 corpus.
It builds checked-in, maintainable OpenC programs with the standalone native
OpenC compiler. Python runs the **test harness only**; normal OpenC builds do
not invoke Python, TinyCC, D, an assembler, or an external linker.

| Workload | Current scope | Exact behavior checked |
| --- | --- | --- |
| `small_cli` | Existing one-file `programs/D_HOSTED_CLI` application | Lists two supplied arguments; edit changes its heading. |
| `medium_audit` | Four benchmark-authored OpenC modules plus a checked-in log file | Reads a file and reports lines, digits, warning markers, and a rolling fingerprint; edit changes the fingerprint multiplier. |
| `compiler_self_build` | Actual 222-source self-host compiler project | Compiled compiler prints its version; edit changes its version fallback; optional generations 2 and 3 must be byte-identical. |

The manifest is [`SUITE.json`](SUITE.json), schema
`openc.sh27.representative_projects.v1`. Expected stdout, stderr, exit code,
input files, and one exact source edit per workload are checked in. The runner
validates that each edit marker occurs exactly once before any build starts.

Run static validation without a compiler:

```text
python compiler/selfhost/benchmark_sh27_representative.py --validate-only
python -m unittest compiler.selfhost.test_benchmark_sh27_representative -v
```

Run serial guarded proof with a fixed-point compiler executable:

```text
python compiler/selfhost/benchmark_sh27_representative.py \
  --compiler <fixed-point-openc.exe> \
  --runs 3 --self-build-generations 3 \
  --output build-output/sh27-representative/proof.json
```

`cold` uses a fresh staged project and output path. `warm` rebuilds the
unchanged staged project after its files have been touched by the cold build.
`edit` applies a specified semantic source change to that same staged tree
and rebuilds. A new staging tree is created for every `--runs` repetition.
The Windows OS file cache is **not** flushed; "cold" is not a machine-cold
benchmark. OpenC does not currently expose an incremental compilation cache,
so "warm" and "edit" are not incremental-build speed claims.

The runner executes one compiler or program at a time through the existing
Windows Job/process memory guard. Defaults in the manifest are 256 MiB
compiler private/Job and 64 MiB working set, 128/64 MiB for generated
programs, 2 MiB captured output, and bounded timeouts. It refuses to overwrite
an existing report and checks disk headroom before each build. Reports contain
source-tree and compiler SHA-256 identities, commands, exact program output,
timings, peak child/Job memory, and fixed-point hashes.

Focused local proof on the production-source fixed-point compiler
`0C79BE775B0CA0962003F485BA6A3F3A2F8CB1DA6A7141B54C9BB28087D1A150`:

- Small CLI and medium app: cold/warm/edit all passed exact output and memory
  checks. The medium app printed `lines=4`, `digits=6`, `warnings=2`, and
  fingerprint `65519`; the source edit changed only the expected fingerprint
  to `16524`.
- Compiler project: cold/warm/edit and generations 2/3 passed. The edit
  changed `OpenC 1.0.0` to `OpenC 1.0.1-sh27`; generations 2 and 3 had the
  identical SHA-256
  `D0C18A385D1589DB21DA0C9EC5684E442BF828124D46C489AED29C4DDDB6D9E7`.
- Maximum observed compiler child private, Job private, and working set across
  the proof were 256,397,312 / 256,585,728 / 60,223,488 bytes, below the
  configured 256 MiB / 64 MiB ceilings. These are sampled process values;
  the Job hard-limit guards aggregate private memory.

Raw reports are ignored local artifacts at
`build-output/sh27-representative/apps-proof-03.json` and
`build-output/sh27-representative/selfbuild-proof-01.json`; they are not
published release evidence. The medium application is a real file-processing
program but is still benchmark-authored and small (four modules, a 51-byte
input). The suite has no independent third-party OpenC project yet, no C/D
comparator for the same application behavior, and only one proof repetition
so far. It must not be presented as broad real-world throughput parity or as
SH-27 completion. Next expansion should add a retained user project and a
larger multi-module application, then run repeated independent-host or
independent-window paired measurements under these same correctness gates.
