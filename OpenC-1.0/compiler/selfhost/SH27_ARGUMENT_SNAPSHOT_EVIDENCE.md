# SH-27 native argument snapshot

Status: **local runtime candidate verified; hosted final-source proof pending;
SH-27 active** (2026-10-14).

Latest source correction: the compiler is now
`91573ac579fc66df94b8ce7123bd7dcf9798b01eb05f02a8dfb0b6c2abdeb959`.
The measurements below initially used `2109e1ef...`; the public CLI check
then exposed insufficient constant capacity when compiling the short
`D_HOSTED_CLI` program. Each argument intrinsic now contributes an additional
512-byte constant bound as well as its relocation/code bound. The expanded
regression fails on the earlier compiler and passes on the corrected compiler.
The corrected source passes Stage 2/3 fixed point, 278/278 conformance,
12/12 CLI checks, and a fresh strict 20/20 chain (216.85 MiB private,
51.77 MiB working set). Corrected-source 20-sample comparator and hosted
proof are in progress; the earlier compiler's timing is not represented as
final-source certification.

The workspace moved to an Intel i5-12450H with 12 logical CPUs. The latest
retained source `2e70d0f` was recovered from Git into
`codex/sh27-local-throughput` and rebuilt through three guarded stages.
Stage 2/3 reproduced compiler SHA-256
`e68db627ca1ea4699691de23d93eb8760272c78e2c8ae02a06ac3337a09d6333`.
The installed DMD was 2.113.0, so an isolated official DMD 2.112.0 archive
was extracted for this comparison. Its executable exactly matches the prior
pin `5ec3152d183b5a7f4c3abb67d01a7055a247d7d3c79e6041ec33b9f95c913bf5`.

A fresh 20-sample C: baseline run reproduced a large-function deficit at
OpenC/DMD **1.301x**; the other four DMD lanes passed. The previous four-CPU
Windows 10 host's 1.470x C: result remains valid historical evidence.

## Runtime change

Every `process.argument_count()` and `process.argument()` invocation used to
load Shell32, resolve `CommandLineToArgvW`, parse the entire command line,
then free the temporary argv/module. The candidate retains one immutable
`{argc, argv}` snapshot in the image's existing runtime data area at +16.
It publishes the header with atomic compare/exchange. Concurrent losers free
their own header and LocalAlloc argv; the winner is retained for the image's
process lifetime. Shell32 is released after parsing. UTF-8 conversion of a
requested argument remains per query; this change does not introduce a full
UTF-8 argument cache. Empty arguments now return an empty text value without
calling `WideCharToMultiByte` with a zero input length.

The new initializer has a larger relocation/code expansion. Its bounds are
counted for argument intrinsics during native function emission. The initial
allocations still grow on demand, under the existing maximum function budgets.
The first experiment failed when the older generic relocation estimate was
exhausted; after the explicit bound was added, all three bootstrap stages
passed with exact Stage 2/3 closure. Final compiler SHA-256:
`2109e1efa6c367a0559f4253027042f245c5987bc4b01ded5b0590f95ccac216`.

## Measured effect and limits

An eleven-pair alternating baseline/candidate matrix, including independent
baseline/baseline null controls and guarded executable checks, measured:

| Workload | Candidate minus baseline paired median | Candidate wins | Null floor |
| --- | ---: | ---: | ---: |
| Small single file | -11 ms | 11/11 | 1 ms |
| Many files | -18 ms | 8/11 | 11 ms |
| Large functions | -9 ms | 7/11 | 12 ms |
| Control flow | +10 ms | 4/11 | 23 ms |

Only the small/many-file gains exceed their measured null floors. The
large/control observations do not establish a source speed effect. This
matrix used the snapshot implementation immediately before the empty-value
branch was added. Its corpus passes no empty arguments; the final compiler
was separately tested below. Executables remain deterministic per compiler,
and exact program behavior passes. Runtime code changes permit different
executable bytes across compiler revisions.

The final compiler's separate pinned 20-sample comparison was:

| Workload | OpenC median | DMD median | OpenC/DMD |
| --- | ---: | ---: | ---: |
| Small single file | 0.0270 s | 0.0875 s | 0.309x |
| Many files | 0.0720 s | 0.1060 s | 0.679x |
| Large functions | 0.2540 s | 0.2120 s | **1.198x** |
| Control flow | 0.1360 s | 0.1365 s | 0.996x |
| Startup/file/allocation | 0.0280 s | 0.0910 s | 0.308x |

All five available DMD ratios and compile/execution/memory checks passed.
The overall report is `FAIL_PARITY` because MSVC, Clang, and LDC are absent
locally. This is one local DMD pass on the new host, not a complete C/D or
cross-host certificate. Do not subtract the A/B deltas from a different
run's DMD median or claim the earlier machine's deficit is solved.

An eleven-pair full self-build comparison on identical current compiler
source measured +6 ms paired median, 5/11 candidate wins, with independent
medians 1.890/1.884 s. This is flat, not a self-build speedup. The old
generator's transition output is separately pinned to the bootstrap's Stage 1
SHA-256 `5a2fb270009015614496749ef96148f8badee2e237a880d38c236792a270f6d5`;
every candidate output must equal its own Stage 3 fixed point. The pair
harness now accepts this explicit baseline output identity for runtime
code-generation changes and reports separately whether *all* outputs match
the candidate fixed point. Its ordinary default still requires one identical
candidate output from both compilers.

## Correctness and memory

- Three-stage byte-exact self-host fixed point: PASS.
- Strict 20-generation self-build and changed/small builds: PASS; peak child
  private 216.85 MiB and working set 51.49 MiB, below 256/64 MiB.
- Native conformance 278/278, x64 substrate 25/25, integer boundaries,
  serial/adaptive generated and self-build PE equality, and exact invalid
  worker diagnostics: PASS.
- Native EXE/DLL argument regression: 4/4 payload sets, with empty values,
  quotes, trailing backslashes, Ukrainian/Chinese/emoji, and a long argument.
  Each DLL is first called concurrently by 16 threads, then repeatedly
  checked against Windows' command-line oracle. Whole-Job private peaks were
  below 18 MiB in the Python test workers. The test has explicit RAM, output,
  and time guards.

The four-partition serial cache test exposed an existing assertion that
required selective semantic skips even though source-chunks=1 does full
validation. The unchanged baseline reproduced that failure. Its expectation
now requires zero skips in serial mode and positive skips with `--flow4`;
cache-hit, object, diagnostic, and fresh-output equality checks remain.
Both corrected serial and four-worker four-partition suites passed. The
four-worker body edit reused three objects and skipped flow/acceptance on
171 sources; its output exactly matched a fresh build. Both modes also passed
corrupt-object recovery, malformed-body diagnostics, and interface-edit
invalidation. These focused results do not select a normal cache policy.

The rejected ownership-scan experiment narrowed guard/call/local checks to
function ranges. It passed 278 conformance and deterministic execution, but
large-function paired median was +2 ms (4/11 wins) against 18 ms null noise.
Its compiler edits were removed; it is not part of this candidate.

Raw local reports are under ignored `build-output/sh27-current-host/`:

| Report | SHA-256 |
| --- | --- |
| `pinned-baseline20.json` | `f8e6b605a699685b36f7e49e9d5536e3bf001bc98938b128afc60646997a091b` |
| `ownership-matrix11.json` | `14273cfd611706e08cc0a971b748a68235fe291dd4c42278067a5199e519da2b` |
| `argv-matrix11.json` | `b1ee63e6c521430eb894225b27c27100cc837269e72857a9ae6d1ae83992c0dc` |
| `argv-pinned20.json` | `fe54249968f0dc7eb93f11e0f034a4f2aa44dc3f9f2aa2efe60fc5fc4b604f79` |
| `argv-stability.json` | `26d564c4aa7d7631d4a55b6d20baf0edf0db38214d60389501d7891946d1a9dc` |
| `argv-regression.json` | `21d0a6660f02ea7ac2d484e69fab4d735e95032102ddb5ecf4388736d518b23d` |
| `argv-selfhost11.json` | `824444d12e80cd71f1bdf61ebadf16de87894ef0b2a6db7e334849150f861ef6` |
| `argv-cache-flow4.json` | `d73cbb81e31a2d488d4eae40d94d8102e31a8c66fb30a2747facd5a357bb4836` |
| `argv-cache-serial-fixed.json` | `468020d91b4b39775243c2072fb8f76b7829c797aa872e9093d2ebdb86ebeccd` |
| `argv-bounded-regression.json` | `05f00149dafdc05ff7d34af1d4e65b1547a4bf2b56e72b8a438c34c7a3168cc5` |
| `argv-bounded-stability.json` | `0992f253687f8d0d3fe94d700d0934888a081628d49db63288f6f0decb820809` |

Next: obtain hosted five-compiler proof for this source, then continue the first-visit semantic/lowering work
for robust DMD headroom. Normal incremental policy, larger retained projects,
two final-source clean certifications, and editor/release gates remain open.
