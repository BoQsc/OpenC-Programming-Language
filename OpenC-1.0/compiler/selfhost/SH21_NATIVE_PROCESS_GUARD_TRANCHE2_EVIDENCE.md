# SH-21 OpenC-native process guard tranche 2 evidence

Status: **PASS FOR THIS TRANCHE; SH-21 REMAINS ACTIVE**.

This tranche closes the native child-process supervision exit gate. It does
not close SH-21: native structure/source/coverage, PE, LSP, benchmark, and
deterministic release/archive ownership remain active work.

## Owned process boundary

The first-party Windows x64 backend now lowers every `system.process.run` call
to an OpenC-owned supervisor with these fixed default limits:

- 256 MiB per-process commit and 256 MiB whole-job commit;
- 64 MiB live working set;
- 4 MiB combined captured stdout/stderr;
- 300,000 ms wall-clock timeout.

The child starts suspended, is assigned to a Windows Job, and only then
resumes. The Job uses `KILL_ON_JOB_CLOSE`, so descendants cannot escape normal
cleanup or a guard failure. The nonblocking pipe loop polls the process every
25 ms and therefore continues enforcing working-set and time limits even for a
silent or continuously writing child.

Windows requires `SE_INC_WORKING_SET_NAME` for a Job working-set limit. Normal
unprivileged compiler processes do not hold that privilege, so the supervisor
uses documented `K32GetProcessMemoryInfo` polling for the 64 MiB rule while the
Job enforces process/tree commit. The required functions are resolved from
System32 Kernel32 through the existing secure loader boundary; the fixed
28-entry PE import table and no-CRT contract are unchanged. Direct PE
inspection of the final compiler confirms one imported DLL (`KERNEL32.dll`),
all 28 expected functions, and no UCRT, VCRuntime, MSVC++, or MSVCRT import.

## Adversarial verifier

The public command is:

```text
openc process-guard --output=REPORT.json
```

Its `openc.native_process_guard.v1` report passed 4/4 checks:

- a child writing 4,194,560 bytes was stopped by the 4 MiB output ceiling;
- a child requesting 300 MiB was contained by the 256 MiB Job limit;
- a child touching 100 MiB was terminated by the 64 MiB working-set poll;
- a non-terminating child was stopped by a 250 ms probe timeout.

Failures have distinct status codes and stable diagnostics for launch/setup,
working-set, timeout, and output-budget failures. The bounded helper remains a
compiler-internal native intrinsic; the optional historical C bootstrap body
falls back to ordinary `process.run` and is not authority for this gate.

## Fixed point and workflow result

The updated compiler contains 117 canonical OpenC source units and 1,641,196
source bytes. Two independently emitted compilers are byte-identical:

- executable bytes: 5,163,008;
- compiler/Stage-2/Stage-3 SHA-256:
  `112444e2c106dab5f0f0c03e321697352cd4bdf3d3eb3511c9c4ecdff1b6d4cb`.

The expanded full workflow passed in 129.312 seconds:

- 8/8 native workflow tasks;
- 4/4 adversarial process guards;
- 278/278 native conformance fixtures;
- 5/5 maintained and native-runtime programs;
- exact compiler/Stage-2/Stage-3 fixed point;
- no Python, D, C compiler, TinyCC, external assembler, or external linker
  invoked by the workflow.

The outer full-workflow process peaked at 34,381,824 private bytes and
28,602,368 working-set bytes. Final guarded compiler rebuilds peaked at
218,652,672 private bytes and 46,555,136 working-set bytes. Captured output
remained within 4 MiB. The same compiler passed
`process-guard` and the daily 4/4 workflow after being renamed
`openc-guard-renamed.exe`.

## Primary local records

- `build-output/selfhost-sh21/process-guard/touch-process-guard.json`;
- `build-output/selfhost-sh21/process-guard/touch-daily.json`;
- `build-output/selfhost-sh21/process-guard/touch-daily-memory.json`;
- `build-output/selfhost-sh21/process-guard/touch-full.json`;
- `build-output/selfhost-sh21/process-guard/touch-full-memory.json`;
- `build-output/selfhost-sh21/process-guard/renamed/renamed-process-guard.json`;
- `build-output/selfhost-sh21/process-guard/renamed/renamed-daily.json`;
- `build-output/selfhost-sh21/process-guard/final/gen2-memory.json`;
- `build-output/selfhost-sh21/process-guard/final/gen3-memory.json`.

These ignored build-output records are reproducible working evidence, not
canonical source-controlled artifacts. This evidence summary and the state
records are the canonical tranche record.
