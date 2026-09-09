# SH-19 implementation ledger

Status: **PASS**. SH-19 passed every exit gate on 2026-09-09.

The final 116-source compiler reaches byte-identical Stage 82/83 closure at
4,712,960 bytes with SHA-256
`277e5ee71bc7f366cfb921c8525a42fe9228221b9955a5fa099326c55fb994c4`.
The relocated package passes 278/278 conformance, 4/4 maintained programs,
all CLI/project/LSP gates, and contains no C, D, Python, or TinyCC source or
toolchain. The compiler and Stage 3 import only `KERNEL32.dll`. Full evidence
is in `release/SH19_COMPILER_CAPABLE_NATIVE_BACKEND_EVIDENCE.md`.

The remaining text preserves the implementation checkpoints that led to the
fixed point. Statements that a checkpoint was incomplete describe that dated
checkpoint, not the final SH-19 state.

## Historical native compiler and memory checkpoint (2026-09-09)

The direct backend now compiles the complete 116-source self-hosted compiler
to a CRT-free PE32+ image and reaches a byte-identical trusted fixed point:

- Stage 39/40 SHA-256:
  `d0224ebf0237d2a60009e09a34a5ca23ebd5e4d471ecff1092f9a6ef0eb61595`;
- image size: 4,197,376 bytes;
- latest guarded trusted rebuild: 9.640 compiler-reported seconds,
  198,123,520 peak private bytes and 39,940,096 peak working-set bytes;
- native lowering/runtime probes: PASS 63/63;
- retained SH-16 PE/runtime regression: PASS 34/34;
- direct-native corpus audit: 72 `NATIVE_COMPILED`, 13 declaration-only
  `NOT_EXERCISED`, and no silently lowered or timed-out cases.

This was the first real compiler fixed point. Later SH-19 work reduced public
self-conformance to zero errors, switched the default to direct x64/PE32+,
and passed the complete 278-fixture plus 4-program native release gates.

### RAM regression containment

The former public build exceeded 512 MiB because direct-mapped path and file
caches repeatedly missed and retained replacement allocations. At the last
failing sample, the compiler had accumulated 45,980 file misses and 787,827
path misses by source record 93. Project source records now retain exactly one
stable source-text view. The same public path completes validation with 116
file misses and 116 path misses, 78,853,345 live compiler-allocation bytes and
107,032,576 peak process-private bytes.

Three independent guard layers remain active:

1. native allocations reject any single allocation above 256 MiB and all live
   native payload above 512 MiB with `OPENC-NATIVE-ALLOC-BUDGET`;
2. public compiler validation stops above 384 MiB live payload with
   `OPENC-VALIDATION-MEMORY-BUDGET` and records phase/counter telemetry;
3. `run_with_memory_guard.py` enforces default 256 MiB private and 64 MiB
   working-set process limits, records `openc.windows_process_memory_guard.v1`,
   and exits 86 with `OPENC-PROCESS-MEMORY-BUDGET` when tripped.

The process monitor streams stdout/stderr to temporary files rather than
undrained pipes and caps captured output, preventing large diagnostics from
deadlocking or becoming a second memory spike. Run its regression gate with:

```text
python scripts/verify_sh19_memory_guards.py --output REPORT.json
```

Current result: PASS 6/6, including a forced private-memory failure and a
large-output non-deadlock/capture-bound probe.

The maintained compiler now uses the x64/PE32+ backend by default. The
`--native-build PROJECT OUTPUT.exe` path emits machine code and PE bytes
directly, rejects unsupported lowering, and never falls back to TinyCC.

Implemented foundations:

- `--native-audit PROJECT REPORT.json` inventories every project function's
  exact lowered IR opcodes, value kinds and legacy call bindings. This is a
  conservative all-functions census, not a reachability or completeness proof.
- Native scalar emission uses stack slots, checked integer operations,
  branches, recursion, direct-call relocations, register/stack arguments and
  short-circuit boolean evaluation. Signed literals and the full unsigned
  64-bit literal range are decoded without the legacy signed-only parser.
- Large fixed stack frames probe each 4 KiB page before changing RSP, preserve
  register arguments and use one unwind-described allocation. This follows
  the stack-probing requirement in Microsoft's [x64 prolog documentation](https://learn.microsoft.com/en-us/cpp/build/prolog-and-epilog).
- The PE linker assigns dynamic section/function addresses and emits unwind
  tables, TLS, relocations and documented system-DLL imports. It reuses the
  previously tested SH-15/SH-16 encoder and format primitives.
- All backend source lowering now refuses parser diagnostics. A previously
  malformed condition in `backend_c_buffer.p` was corrected.

Verification entry point:

```text
python scripts/verify_sh19_native_scalars.py --compiler PATH_TO_COMPILER --output REPORT.json
```

Checkpoint 2026-09-08 (not milestone completion):

- `build-output/selfhost-sh19/scalar-verification9.json`: PASS 16/16. Includes
  checked arithmetic/casts, signed division/remainder, short-circuit fault
  avoidance, recursive calls, six-argument calls, a 600-local stack probe,
  deterministic PE bytes, system-DLL-only imports and fail-closed rejection.
- `build-output/selfhost-sh19/scalar-closure9`: legacy C/TinyCC bootstrap
  Stage-2/Stage-3 closure PASS. This is NOT direct-native compiler closure.
- SH-18 friendly module regression: PASS 27/27; Python tests: PASS 42/42.
- The first full legacy regression run passed 15/16 tasks, including
  conformance, but exceeded the 256 MiB private-memory gate at 263 MiB.
  The parallel C emitter now retains only its header during worker execution
  and reserves the measured combined output afterward. The budget was not
  changed. `memory-regression-final.json` passes byte-exact rebuild in 10.049 s
  with 236,654,592 peak private bytes (225.7 MiB).
- The subsequent `full-regression-final/full-workflow-result.json` passes
  every functional/performance task: 278/278 conformance, 4/4 programs,
  CLI/project/LSP/Windows gates and budgeted self-rebuild. Its aggregate
  remains FAIL 15/16 because structure validation had run before its status
  check was updated to accept `IN_PROGRESS_NOT_COMPLETE`. A separate rerun
  of `python scripts/validate_structure.py` passed after that correction.
  This report has not been rewritten or relabeled as a full PASS.
- An attempted direct-native full-compiler build was interrupted after
  several minutes without output during validation. No native compiler was
  produced; validation throughput needs investigation as well as the known
  unimplemented lowering/runtime work below.
- The installed default compiler is unchanged. The experimental compiler
  and legacy regression distribution are under `build-output/selfhost-sh19`.

The first conservative compiler census, before adding scalar/image emission,
contains 1,167 functions and 100,755 IR instructions. Most apparent
`ocb_compiler_*` dependencies are legacy optimizations of existing `.p`
functions. Native emission must bind to the OpenC implementations and retain
their performance; generic Hosted primitives still need an OpenC runtime.
The updated scalar-closure8 census contains 1,186 functions and 104,103 IR
instructions (`build-output/selfhost-sh19/compiler-ir-audit8.json`).

Historical required work, completed in dependency order:

1. General value layout: named aggregates, fields, enums, text, status, arrays,
   slices, optionals, pointer/ref/out/own semantics and cleanup.
2. ABI-complete call/return lowering, floating operations, indirect calls and
   callbacks; extend the scalar arithmetic edge-case corpus.
3. OpenC runtime implementations for memory/text/path/file/process/console and
   the compiler's caching/parallel primitives; external Windows imports and
   friendly Windows providers must have no C implementation requirement.
4. Compile the full compiler and runtime via the native path. Reach Stage-2 /
   Stage-3 byte closure. Audit imports and check unwind/stack walks/callbacks/TLS.
5. Run 278/278 conformance, 4/4 maintained programs, public CLI/workflow checks,
   repeated throughput and memory gates. Correct regressions before switching
   the default backend.
6. Produce and verify the standalone package without TinyCC, C headers, C
   sources/runtime, assembler or external linker. Retain the legacy path only
   for explicit differential auditing. Update state/evidence and commit SH-19
   complete only after these gates pass.

Python remains the external SH-19 evidence harness. Public compiler throughput
convergence is SH-20; required Python workflow replacement is SH-21.
Linux/freestanding remain optional future work.

## Aggregate/reference increment (2026-09-08)

The aggregate increment (`aggregate-closure4`) passes the initial
27/27 native lowering checks and legacy Stage-2/Stage-3 closure. It adds:

- exact-width scalar pointer loads/stores and scalar address formation;
- recursive plain-structure layout, local value copies and nested fields;
- aggregate `ref` mutation and whole-aggregate pointer loads/stores;
- whole-aggregate field replacement through an address temporary, with
  explicit regression coverage for adjacent-field preservation;
- fail-closed rejection of aggregate by-value arguments/returns, pointer
  arithmetic and ownership calls until their lowering is implemented.

`aggregate-rebuild.json` passes byte-identical legacy self-rebuild in 7.125 s
with 235,274,240 peak private bytes. This is one observation, not a new
formal C/D throughput comparison. The compiler default remains unchanged.

The first full regression (`aggregate-full-regression`) passed 16/16 before
the field-replacement fix. The new field-replacement regression failed on
that compiler and passed after the fix (`aggregate-verification4.json`).
The final post-fix run (`aggregate-full-regression-final`) also passes 16/16,
including 278/278 maintained conformance and the unchanged rebuild budgets.

Next: implement ABI-classified
aggregate calls/returns, status/out lowering, arrays/slices, ownership cleanup
and the OpenC runtime. The current scalar/structure subset is not a complete
Core backend and does not establish native compiler closure.

## Aggregate ABI and status increment (2026-09-08)

`status-closure2` passes legacy Stage-2/Stage-3 closure;
`status-verification-final.json` passes 35/35 native lowering checks.
`status-full-regression/full-workflow-result.json` passes 16/16 maintained
workflow tasks, including 278/278 conformance, maintained programs and the
unchanged byte-exact self-rebuild performance/memory gates. These full
conformance results use the retained C/TinyCC lane, not direct-native emission.

- Plain structures of 1/2/4/8 bytes use the integer argument/return path;
  other supported aggregate sizes use pointers, with a hidden first result
  argument for returns. Aggregate temporaries are 16-byte aligned. This
  implements the relevant [Microsoft x64 argument/return rules](https://learn.microsoft.com/en-us/cpp/build/x64-calling-convention).
- Register arguments are saved before parameter copies. Outgoing arguments
  are prepared before loading ABI registers, including hidden-result shifts
  and fifth-and-later stack arguments. Callees copy indirect value arguments
  into independent local storage.
- Added status construction, copies, `code`/`ok` access, return values and
  successful status-returning `out` calls. Empty text values are supported;
  nonempty text constants/messages still reject, pending the constant-data
  and runtime implementation. This is not complete status/text support.
- Machine-code capacity now accounts for aggregate copies. A status-copy
  regression exposed the previous scalar-only capacity estimate.
- Native tests include 1/2/4/8-byte values, recursive 3-byte returns, multiple
  large value arguments, mutation isolation and status success/failure.
  These OpenC-to-OpenC tests are not an independent Windows SDK ABI oracle.

Next: constant text/data emission, arrays/slices and ownership cleanup, then
the CRT-free OpenC runtime and native compiler closure. Floating aggregates,
resources and unsupported value layouts remain fail-closed. The installed
default and SH-19 completion status are unchanged.
