# SH-15 Windows x64 ABI and machine-code substrate evidence

Status: **PASS**

Date: 2026-08-12
Target: Windows x86-64 Hosted
Compiler implementation: OpenC `.p` source
Compiler source units: 104
Compiler SHA-256: `b9edd79017cb92c2f1d3e87fab83c065460c3f966da0745fe602c61b5edcec1e`
Generated C SHA-256: `1b6fe066792f97299d25f76bc6fd1ef69fe1a04cd1e834262e545d2202c13350`

## Result

SH-15 supplies a first-party, OpenC-authored Windows x64 substrate. The target
record now carries the `openc.windows_x64_abi.v1` contract, while the compiler
emits the deterministic `openc.windows_x64_substrate.v1` probe record.

The implementation covers:

- Microsoft x64 positional integer and floating argument registers, stack
  arguments, 32-byte shadow space, and 16-byte body alignment;
- scalar, direct aggregate, indirect aggregate, hidden-return, callback,
  function-pointer, and variadic-float classification;
- the LLP64 data model, natural and packed records, explicit layouts, unions,
  and bitfield storage;
- volatile/nonvolatile integer and vector registers;
- a typed x64 byte encoder with REX, ModRM, SIB, memory operands, integer,
  floating/vector, branch, call, stack, and return instructions;
- forward and backward relative-32 plus absolute-64 relocations;
- version-one x64 unwind information and ordered 12-byte runtime-function
  records for `.pdata`/`.xdata` consumers.

The substrate does not invoke a C-header parser, external assembler, or
external linker. Windows names and types remain target/library concerns rather
than Core language primitives.

## Executable verification

The SH-15 verifier passes 25/25 checks. It allocates executable memory and
runs emitted Win64 machine code to prove:

- six integer register/stack arguments produce `21`;
- four positional XMM arguments produce `11.5`;
- direct and indirect aggregate calls produce the expected 64-bit values;
- the hidden aggregate-return pointer is shifted and returned correctly;
- an emitted indirect callback returns `42` with entry `RSP mod 16 = 8`;
- `RBX` and `XMM6` survive nested calls;
- variadic floating arguments are duplicated into the corresponding integer
  register;
- the unwind function table can be registered, resolved, and removed through
  the documented Windows runtime APIs.

A tiny verification-only DLL confirms structure size/offset, Windows
`long` width, bitfield packing, and the variadic duplication observation. This
use of the vendored TinyCC is an ABI oracle only; it is not used to assemble or
link the first-party probe substrate.

## Closure, correctness, and performance regression

Stage 2 and Stage 3 compiler executables are byte-identical at the compiler
SHA-256 above. Their generated C is also byte-identical at the generated-source
SHA-256 above.

- native conformance: 278/278;
- maintained programs: 4/4;
- Python source tests: 35/35;
- full native workflow: 13/13;
- retained D seed executed by required workflow: false;
- historical rule-ID compatibility matches: 93, explicitly disclosed.

The enforced five-run regression suite remains comfortably inside the SH-14
performance contract:

| Measurement | SH-15 result | Gate |
| --- | ---: | ---: |
| OpenC clean median | 6.218 s | <= 30 s |
| OpenC clean maximum | 7.156 s | <= 45 s |
| Pinned D clean median | 16.862 s | reference |
| OpenC / D median ratio | 0.369x | <= 1.25x |
| Peak private memory | 244,424,704 bytes | <= 268,435,456 |
| Peak working set | 27,963,392 bytes | <= 33,554,432 |

The faster 4.137-second SH-14 best baseline remains the regression baseline;
SH-15 does not relax any budget.

## Dependency boundary

TinyCC remains the compiler's production C backend until SH-19. Python remains
external evidence orchestration until SH-20. D remains optional historical
bootstrap/audit and a pinned comparator, and is not part of the required
compiler workflow. Linux and freestanding verification remain optional future
target work and are not SH-15 gates.

## Reproduction

```text
python scripts/verify_sh15_windows_x64.py --compiler build-output/selfhost-sh15/closure/stage3/openc.exe --output build-output/selfhost-sh15/closure/sh15-verification.json
python compiler/selfhost/benchmark_throughput_suite.py --compiler build-output/selfhost-sh15/closure/stage3/openc.exe --runs 5 --enforce --output build-output/selfhost-sh15/final-throughput-suite-v2.json
python scripts/windows_native_workflow.py full --compiler build-output/selfhost-sh15/closure/stage3-distribution/openc.exe --output build-output/selfhost-sh15/full-workflow-final-v2 --force-conformance
```

The retained primary reports are:

- `build-output/selfhost-sh15/closure/sh15-verification.json`;
- `build-output/selfhost-sh15/final-throughput-suite-v2.json`;
- `build-output/selfhost-sh15/full-workflow-final-v2/full-workflow-result.json`.

## Next milestone

SH-16 is active: emit a deterministic PE32+ executable directly and supply the
minimal CRT-free OpenC entry/runtime for UTF-8 output, process-heap allocation,
and file access using documented Windows system DLLs. TinyCC removal remains
SH-19, after the native path can rebuild the compiler itself.
