# SH-21 OpenC-native workflows and bootstrap boundary

Status: **COMPLETE — PASS**.

SH-21 removes required Python orchestration from normal Windows Hosted build,
test, validation, benchmark, audit, packaging, and release verification. The
normal path now needs only a previous OpenC compiler, canonical `.p` source,
and documented Windows system DLLs. D, Python, C, and TinyCC remain only in the
explicitly named historical bootstrap/audit kit.

## Completed exit gates

- `openc workflow` owns daily and full orchestration. The final daily surface
  is 8/8; the guarded full workflow is 13/13.
- `openc audit` verifies 380 required files, 39 pinned hashes, 278 fixture
  identities, 466 active-rule coverage records, and 174 grammar-production
  pairs.
- `openc pe-audit` passes 16/16 PE32+, section, import, relocation, TLS,
  x64-unwind, and CRT-absence checks. The final compiler imports only 30
  documented Kernel32 symbols.
- `openc lsp-audit` passes 42/42 byte-framed language-service contracts.
- `openc contract-audit` passes 29/29 CLI, diagnostic, project, demo,
  friendly-Windows, WinMD, and historical-boundary contracts; 20 consecutive
  stress runs pass.
- `openc benchmark` passes 20/20 exact chained rebuilds. The final enforced
  five-run median is 23.094 seconds and semantic validation is 14.827 seconds,
  below the unchanged 25-second and 15-second gates.
- Compiler peaks are 181,161,984 private bytes and 53,575,680 working-set
  bytes, below 256 MiB and 64 MiB. Captured output remains capped at 4 MiB and
  each child remains capped at five minutes.
- `openc release` emits independent byte-identical standalone and source ZIP
  pairs with deterministic STORE records, CRC-32, SHA-256, safe-path checks,
  an internal package manifest, bounded per-entry buffers, and capped archive
  verification.
- A relocated standalone compiler builds two exact generations, runs the 8/8
  daily workflow, passes 29/29 contract checks and 278/278 conformance, and
  imports no Microsoft CRT.
- The standalone package excludes C, D, Python, TinyCC, C headers/runtime,
  external assemblers, and external linkers. The retained historical material
  is documented by `historical/HISTORICAL_BOOTSTRAP_AUDIT_KIT.json` and is
  never searched or invoked by default.
- The prior 93 historical rule-ID compatibility matches remain disclosed.
  Linux and freestanding remain optional future targets.

The final fixed-point compiler has 130 OpenC source units, 1,794,397 source
bytes, 6,110,720 executable bytes, and SHA-256
`7eea1c053132536398c562a09e46c98478f6f4cde6ddf9a2f706943ee4fbc130`.
Detailed results are in `SH21_COMPLETION_EVIDENCE.md`.

## What comes next

SH-22 is now the active engineering milestone: PE/COFF ecosystem
completeness. It covers COFF objects, OpenC DLL imports/exports, static and
import libraries, resources and manifests, console/GUI subsystem selection,
secure runtime linking, and optional bidirectional C-ABI interoperability.
A standalone assembler is added only if the shared x64 encoder proves
insufficient. SH-23 remains optional COM/WinRT projection work; SH-24 remains
native editor integration and LSP resilience.
