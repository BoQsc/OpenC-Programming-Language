# SH-27 scalar-source flow cut

Status: **locally proved; clean Windows comparator parity failed**. This is
the second cut on `codex/sh27-flow-front-end-cut`, source commit `738bea3`,
measured against the immediately preceding ownership-gated compiler
`ab1d2d4`. It is a whole-flow-pass proof gate, not a relaxation of OpenC
safety rules or a claim that SH-27 is complete.

## Soundness boundary

The old validator entered the full flow pipeline for any function-local
variable, even when every local was a non-resource scalar with an initializer.
Its initialization analyzer itself only examines variables whose declaration
has no `=`. The new gate uses the retained **error-free** parsed source and
that same declaration predicate before choosing the fast return. It keeps
full validation if a local declaration is absent/uncertain/uninitialized,
the local has resource/pointer/ref type, a parameter has out/ref/resource
state, or the existing source feature scan sees a possible own, ref, out,
scope, unsafe, address, or pointer operation. If the project has an unsafe
function, an error-free source with **no call node** needs no unsafe-call
analysis; any call or unavailable parsed source keeps the old path.

This does not change the checks for sources with stateful variables, calls,
ownership, borrows, pointer arithmetic, or unsafe behavior. The fallback is
conservative: an uncertain symbol, syntax record, or cache state runs the
full flow validator. It preserves existing diagnostic order on the tested
invalid sources. The full 278-case conformance run includes invalid
initialization, ownership, borrow, pointer, and unsafe fixtures.

## Guarded local evidence

- Seed-to-Stage-2/Stage-3 self-host fixed point: byte-exact.
- Native conformance: 278/278. Serial/adaptive executables and the two
  invalid-control-flow diagnostic cases: exact. Generated runtime output
  and Job RAM limits: PASS.
- Strict 20-generation self-build: 20/20 exact closures; peak child private
  **249,614,336 bytes** (<256 MiB), working set **54,059,008 bytes**
  (<64 MiB).
- Eleven order-alternated same-host, normal-default revision pairs on the
  checked-in SH-27 generated source, with byte-identical executables:

| Workload | Median paired candidate minus baseline | Candidate wins | Independent medians (baseline/candidate) |
| --- | ---: | ---: | ---: |
| Large functions | **-93 ms** | 10/11 | 1.303/1.215 s |
| Control flow | **-42 ms** | 11/11 | 0.426/0.389 s |
| Complete compiler self-build | -2 ms | 6/11 | Reported as flat, not a speed gain |

The generated-lane pair harness rebuilt both compiler revisions from the
same retained seed to their own byte-exact fixed points. The self-build
comparison used those fixed-point compilers on identical current compiler
source, proved exact candidate closure, and passed guarded execution. The
local host's absolute times vary materially; only within-pair deltas are
used as speed evidence. Do not subtract these values from a separate CI
run's DMD medians.

The first clean [Windows workflow run 35928451776](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35928451776)
passed byte-exact fixed point, native conformance, the strict 20-generation
memory chain, x64 and integer checks, exact worker outputs/diagnostics and
Job RAM, historical speed guards, and the opt-in comparator lanes. Its
**enforced normal-default** five-compiler step failed two of the 20 ratios:

| Workload | OpenC/DMD same-run medians | Ratio | OpenC reduction needed for 1.25x / 1.20x |
| --- | ---: | ---: | ---: |
| Large functions | 0.451/0.315 s | 1.4317x | 57.25/73.0 ms |
| Control flow | 0.272/0.211 s | 1.2891x | 8.25/18.8 ms |

The other 18 ratios passed. These are same-run deficits from the workflow's
check annotations, not a comparison to another source or runner. The local
93/42 ms paired gains were genuine but insufficient for sustained pinned
parity. This run does not establish any clean pass of this exact source;
the next cut must close the large-function wall gap with margin before
SH-27 can advance to its two final-source runs.

One diagnostic snapshot changed top-level validation from 63 to 16 ms on
large functions and 47 to 0 ms on control flow relative to the previous
local snapshot. Those snapshots are **not** paired wall measurements; they
only confirm that the intended flow stage was bypassed. The 93/42 ms
paired whole-compiler reductions are the relevant local A/B result. The
clean comparator failure above, the remaining large-function architecture,
genuine incremental object reuse, and representative projects all keep
SH-27 open.

Raw local reports are retained under ignored
`build-output/selfhost-sh27/sh27-scalar-flow-proof-20260924/`.
