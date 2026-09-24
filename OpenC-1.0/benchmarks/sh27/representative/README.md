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

The medium file-audit workload also has checked-in C17/MSVC and D/DMD
counterparts. To run those lanes, explicitly pin the three native tool
executables and add `--with-comparators`:

```text
python compiler/selfhost/benchmark_sh27_representative.py \
  --compiler <fixed-point-openc.exe> --workload medium_audit \
  --with-comparators \
  --c-compiler <cl.exe> --c-sha256 <64-hex-digest> \
  --c-linker-sha256 <64-hex-link.exe-digest> \
  --d-compiler <dmd.exe> --d-sha256 <64-hex-digest> \
  --runs 3 --output build-output/sh27-representative/medium-c-d.json
```

The runner refuses missing or mismatched pins, records compiler versions, and
discovers the active x64 Visual Studio environment when necessary. It runs
each C and D cold/warm/edit compile under a separate 512 MiB private/working
set guard, executes the resulting program under the 128/64 MiB program guard,
and requires stdout, stderr, and exit code to match both the literal manifest
and OpenC **exactly**, including LF line endings. These descriptive compiler
timings are not added to the generated synthetic corpus's 20-sample ratio
contract. The MSVC and DMD standard libraries and DMD's selected linker are
not independently hashed by this first version; the report records the
compiler and MSVC linker identities, but complete toolchain reproducibility
requires a pinned runner image.

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
input). The suite has no independent third-party OpenC project yet, and the
new C/D comparator lanes have since passed a separately pinned hosted run
documented in [the hosted proof](../../../compiler/selfhost/SH27_REPRESENTATIVE_HOSTED_PROOF.md).
The OpenC-only suite proof had one repetition; the hosted medium comparator
proof had three. Neither should be presented as broad real-world
throughput parity or as
SH-27 completion. Next expansion should add a retained user project and a
larger multi-module application, then run repeated independent-host or
independent-window paired measurements under these same correctness gates.

On the current local host, MSVC `cl.exe`/`link.exe` is not installed. A
local D-only guarded check with pinned
DMD64 v2.112.0 executable SHA-256
`5EC3152D183B5A7F4C3ABB67D01A7055A247D7D3C79E6041EC33B9F95C913BF5`
did compile and execute the original and edited fixture. Captured stdout was
byte-exact LF text for both manifest variants, with exit code zero. The
initial `writeln` implementation produced CRLF and was correctly rejected;
the checked-in D fixture now uses binary `rawWrite`. A first 64 MiB DMD
working-set guard also correctly rejected the D compile, so comparator
compiles now have a distinct 512 MiB ceiling rather than weakening OpenC's
256/64 MiB guard. These partial D records are ignored local files named
`build-output/sh27-representative/d-only-compile-03.json`,
`d-only-runtime-03.json`, `d-only-edit-compile-01.json`, and
`d-only-edit-runtime-01.json`. They do not establish C/D/OpenC timing parity;
the separate hosted proof above establishes exact three-language equivalence
for this one checked-in fixture.

The dedicated GitHub Actions workflow
`.github/workflows/openc-representative-medium.yml` runs on relevant `master`
commits and supports manual dispatch. It also watches this isolated
`codex/sh27-representative-work` branch for discovery testing. It reuses the
repository's SHA-pinned checkout, MSVC setup (toolset 14.44), DMD 2.112.0
setup, and artifact actions, then bootstraps the checked-out OpenC source to
a guarded Stage 3 fixed point. Its discovery job records actual hosted
`cl.exe`, `link.exe`, and `dmd.exe` hashes and versions as an artifact. It does
**not** pass newly discovered hashes straight into a proof run. The separate
proof job is skipped until reviewed literal digests are committed to
`.github/representative-toolchain-pins.json` with status `PINNED`; a manual
`mode=proof` request while pins are pending fails explicitly. The proof job
rechecks the literals on its own runner before compiling anything.

The workflow was exercised on `codex/sh27-critical-worker-budget`: the first
runner's reviewed MSVC hashes drifted, so the proof failed closed; after the
new discovered hashes were independently committed, [run 35946485926](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35946485926)
passed the full guarded pinned proof. GitHub manual
`workflow_dispatch` normally requires the workflow file on the default
branch; after that file is merged, a branch-ref dispatch can be tested with
`gh workflow run openc-representative-medium.yml --ref
codex/sh27-critical-worker-budget -f mode=discovery`, and `mode=proof` only after
the reviewed pins are committed. The workflow is separate from the synthetic
20-ratio workflow and cannot claim that contract passed. See
[GitHub's manual-run documentation](https://docs.github.com/actions/managing-workflow-runs/manually-running-a-workflow)
for the default-branch and `--ref` behavior.
