# SH-19 compiler-capable native backend and TinyCC exit evidence

Status: **PASS** on the declared Windows x86-64 Hosted scope.

SH-19 changes the normal compiler artifact path from generated C plus TinyCC
to OpenC-owned x64 machine code and a deterministic PE32+ writer. The compiler,
runtime, public CLI, project tools, and language server are authored in OpenC
`.p` source. The retained C/TinyCC and D implementations are optional
differential/bootstrap audit material and are not packaged or executed by the
required SH-19 release gate.

## Fixed point and resource bounds

- canonical compiler sources: 116;
- Stage 82 / Stage 83 executable bytes: 4,712,960;
- both SHA-256:
  `277e5ee71bc7f366cfb921c8525a42fe9228221b9955a5fa099326c55fb994c4`;
- guarded trusted Stage 83 rebuild: 10.378 seconds, 202,903,552 peak private
  bytes, and 41,111,552 peak working-set bytes;
- final full-workflow rebuild: 14.502 seconds, 202,338,304 peak private bytes,
  and 41,160,704 peak working-set bytes;
- allocation/process guards: 6/6;
- direct lowering/runtime probes: 63/63;
- retained PE32+/runtime probes: 34/34.

The compiler rejects a single allocation above 256 MiB, live native payload
above 512 MiB, validation payload above 384 MiB, child output above 64 MiB,
process private bytes above 256 MiB, and process working set above 64 MiB.
Failures carry stable `OPENC-*-BUDGET` diagnostics and the process harness
records bounded stdout/stderr instead of retaining unbounded pipes.

## Correctness and user-facing tools

The clean SH-19 full workflow passes 16/16 tasks:

- native conformance: 278/278, zero failures and zero infrastructure failures;
- maintained programs: 4/4;
- public CLI and diagnostic contracts: 12/12;
- formatter/project/test workflow: 21/21;
- JSON-RPC language service: 19/19;
- semantic language service: 23/23;
- friendly Windows modules: 27/27;
- WinMD/raw projection gate: 26/26 in the integrated regression;
- Python source-contract tests: 42/42.

The native LSP owns Content-Length stdio framing through documented
`KERNEL32.dll` handles and `ReadFile`; it does not enter through a CRT. The
formatter and JSON field parser use scalar result contracts, avoiding
unsupported or ambiguous aggregate/out return shapes at native call boundaries.

## Standalone release boundary

Two independent package builds are byte-identical:

- archive SHA-256:
  `d7911bc60cf5fa887bcccf7c9e519ea7694566360fbf3e8e4b13b723dba92fea`;
- internal manifest SHA-256:
  `90844f26d9ae04439f5f41cc7aa11e9ea5a0007a5fac428f886b7c217f1fcfce`;
- archive files: 1,296; manifest entries excluding the manifest itself: 1,295.

From a foreign working directory and a `PATH` containing only Windows
`System32`, the packaged compiler builds Stage 2, Stage 2 builds Stage 3, and
both stages are byte-identical to the packaged compiler. The verifier then
runs all correctness/tooling gates listed above.

The archive contains no `.c`, `.h`, `.d`, `.py`, or `.pyc` files and no
TinyCC distribution. Compiler and Stage 3 import only these 28 documented
`KERNEL32.dll` symbols: file/console handles, heap allocation, UTF conversion,
timing/module/environment access, dynamic-library access, and process/pipe
creation/wait/exit queries. They import no `ucrtbase.dll`, `vcruntime*.dll`,
`msvcp*.dll`, or `msvcrt.dll`. Build records state that DMD, DUB, Python,
TinyCC, external assemblers, and external linkers were not invoked.

Primary records:

- `build-output/selfhost-sh19/final-release-verification5/standalone-release-result.json`;
- `build-output/selfhost-sh19/full-workflow-final4/full-workflow-result.json`;
- `build-output/selfhost-sh19/native-final-stage83-guard.json`;
- `build-output/selfhost-sh19/public-final84-guard.json`;
- `build-output/selfhost-sh19/native-scalars-final3.json`;
- `build-output/selfhost-sh19/memory-guards-final2.json`;
- `build-output/selfhost-sh19/native-corpus-final2.json`.

## Explicit remaining performance problem

SH-19 proves correctness and toolchain independence; it does not claim that
the fully validating public compiler is yet C/D-class. The final public
116-source self-build reports 109.328 seconds, with 97.828 seconds in semantic
validation, and observes 198,148,096 private bytes plus 45,846,528 working-set
bytes. The output is still byte-identical and within the SH-19 guards.

This measurement makes SH-20 native public throughput convergence the next
and highest-priority engineering milestone. Required Python workflow
replacement is deliberately pushed to SH-21 so performance is solved first.
The forced 278-fixture runner also shows host-sensitive one-process-per-fixture
times from 76.081 to 233.841 seconds while staying below 12 MiB process memory;
SH-19 uses a reviewed 300-second functional ceiling, but SH-20 still requires
a 15-second public-validation median and must remove that process overhead.
Linux, freestanding, and ARM64 remain optional future targets. The 93
historical rule-ID compatibility matches remain explicitly disclosed and are
not used by current conformance execution.
