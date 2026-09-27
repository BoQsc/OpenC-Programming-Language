# SH-27 compiler CLI dispatch speed evidence

Status: **local candidate accepted for further clean-host testing; SH-27 open**
(2026-09-27).

The compiler's `main()` used to call `process.argument(0)` at each command
comparison. Each call reparses the Windows command line and reloads/resolves
the shell argument helper. The selected source change reads argument zero once
after `process.argument_count()` and reuses the resulting OpenC `text` for all
dispatch comparisons. It changes neither the process API nor other programs.

The byte-exact Stage 2/Stage 3 candidate compiler has SHA-256
`e68db627ca1ea4699691de23d93eb8760272c78e2c8ae02a06ac3337a09d6333`.
The frozen pre-change compiler is
`0c83deac588cfb81968f652cd7a77f28fc0f9ffa2c9342992a511711e634e0ca`.
Thirty alternating guarded `version` invocations gave a -33 ms median paired
wall-time difference, with 30/30 candidate wins. This is a compiler startup
and dispatch effect, not a semantic pipeline speedup.

An 11-pair, order-alternated, 512 MiB process-tree-guarded direct-PE matrix
compared the two compilers on the unchanged checked-in corpus. Each lane
passed exact generated-executable SHA-256 equality, deterministic compiler
output, executed-program behavior, and memory gates. A baseline/baseline null
control measured the local noise floor:

| Workload | Candidate minus baseline paired median | Wins | Null noise floor |
| --- | ---: | ---: | ---: |
| Small single file | -98 ms | 11/11 | 12 ms |
| Many files | -99 ms | 11/11 | 11 ms |
| Large functions | -82 ms | 11/11 | 31 ms |
| Control flow | -78 ms | 10/11 | 40 ms |

The matrix status is `PASS`; its ignored raw JSON report is
`build-output/sp27-cli-dispatch/cli-matrix11.json`, SHA-256
`8d51c13aaf729aa5eb04c7e37faca851888cdab3f88bfd3afccecbf12d1047f6`.

A separate pinned 20-sample **local DMD-only** run of the candidate kept the
production corpus, rotated tool order, executable checks, and 512 MiB guards.
This is a within-run OpenC/DMD comparison; it is not an A/B measurement or a
five-compiler clean-host certificate:

| Workload | OpenC median | DMD median | OpenC/DMD | 1.25x gate |
| --- | ---: | ---: | ---: | --- |
| Small single file | 0.0655 s | 0.1460 s | 0.449x | PASS |
| Many files | 0.1510 s | 0.1515 s | 0.997x | PASS |
| Large functions | 0.5320 s | 0.3640 s | **1.462x** | **FAIL** |
| Control flow | 0.2800 s | 0.2440 s | 1.148x | PASS |
| Startup/file/allocation | 0.0645 s | 0.1420 s | 0.454x | PASS |

The large-function lane still needs about 77 ms less OpenC wall time to meet
1.25x on this host, or 168 ms to equal this DMD median. All available
compiler/executable/output/memory checks passed, but the report correctly
remains `FAIL_PARITY`. Its ignored JSON is
`build-output/sp27-cli-dispatch/cli-local-dmd20.json`, SHA-256
`df9e18875d7f66c617f7366aa764452f22cc9292f571cc77be96467f5df9f685`.
MSVC, Clang, and LDC are unavailable on this local machine.

The strict stability rerun passed five small, five changed-source, and 20/20
chained self-builds with exact compiler closure under the 64 MiB working-set
and 256 MiB private-commit limits (`stability-retry.json`, SHA-256
`23cb9fb5e43d00648ab207536a298944ad6f6b52bee7697902ae81ff5561359f`).
The first attempt ran out of disk space while producing generation 15; its
zero-byte executable and empty final report are not treated as a compiler
result. Completed generated run trees were removed to recover space; the
compact JSON reports and compiler binary were preserved.

The same candidate passed native conformance 278/278, x64 substrate 25/25,
SH-9 CLI 12/12 with the canonical rule index and conformance plan installed
beside the test executable, SH-10 project workflow 21/21, and SH-11 LSP 19/19.
The older SH-11 script expected full sync (`change: 1`) even though the
baseline and candidate both advertise and implement incremental sync
(`change: 2`); that test expectation was corrected. Its pre-correction
18/19 result was reproduced on the unchanged baseline compiler.

Next: run the pinned five-compiler, 20-sample production gate on clean
Windows for this exact source. Independently remove the remaining local
large-function critical-path deficit, then repeat the complete corpus and
strict gates on the final source. SH-27 also still requires sound normal
incremental policy, retained real-project breadth, two independent final
clean-host certifications, editor/release audits, and normal release
integrity. This local speedup alone is not SH-27 completion.
