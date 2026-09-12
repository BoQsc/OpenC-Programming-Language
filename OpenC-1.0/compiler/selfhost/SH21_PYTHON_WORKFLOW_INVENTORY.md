# SH-21 Python workflow inventory and disposition

Status: **COMPLETE — NORMAL WORKFLOWS REPLACED**.

SH-21 audited every Python-owned operation that could affect a normal Windows
Hosted build, test, benchmark, package, or release decision. Required behavior
is now owned by OpenC. Python copies remain optional compatibility evidence,
not normal workflow dependencies.

## Final disposition

| Former Python owner | OpenC-native owner | Final status |
| --- | --- | --- |
| `windows_native_workflow.py` | `openc workflow` | Replaced; daily 8/8, full 13/13 |
| conformance-plan and coverage scripts | `openc audit` | Replaced; 278 fixtures, 466 rules, 174 productions |
| structure/source-completeness scripts | `openc audit` | Replaced for required release decisions; 380 required files and 39 pinned hashes |
| SH-9 CLI verifier | `openc contract-audit` | Replaced with exact lexical/flow/semantic diagnostics |
| SH-10 project verifier | `openc contract-audit` and `openc test` | Replaced |
| SH-11/SH-12 LSP verifiers | `openc lsp-audit` | Replaced; 42/42 framed checks |
| SH-16 PE verifier | `openc pe-audit` | Replaced; 16/16 |
| SH-17 WinMD verifier | native reader plus checked-in projection/manifest audit | Required release identity checks replaced; explicit metadata regeneration remains optional |
| SH-18 Windows-module verifier | native semantic and source-contract checks | Required static/friendly contract replaced; legacy generated-C/TinyCC runtime differential is optional, while native DLL interoperability belongs to SH-22 |
| maintained-program and demo runners | `openc test` and `openc contract-audit` | Replaced; 5/5 programs and all six demos |
| rebuild/stability scripts | `openc benchmark` | Replaced; 20/20 exact closure with time/RAM gates |
| standalone/source archive builders and verifiers | `openc release` | Replaced with deterministic bounded ZIP build, verification, extraction, and relocation checks |
| aggregate native release script | `openc release` | Replaced |

The native process supervisor creates suspended children, assigns them to a
kill-on-close Windows Job, caps process/job private memory at 256 MiB, polls a
64 MiB working-set ceiling, caps captured output at 4 MiB, and keeps the
five-minute per-child timeout. The 20-build aggregate allowance is 15 minutes;
this does not change any individual build or performance gate.

The release ZIP writer emits each entry directly, never constructs a second
whole archive while packaging, caps an input entry at 16 MiB, verifies an
archive only below 64 MiB, rejects unsafe paths, and validates local/central
records and CRC-32. Two independently written archives must be byte-identical.

## Optional historical/bootstrap boundary

The following remain available only by explicit invocation:

- `compiler/bootstrap/python/**` and `compiler/selfhost/bootstrap*.py`;
- lexer/parser/project/semantic parity scripts;
- retained D sources and DMD/DUB launch paths;
- generated-C, C-runtime, and TinyCC differential paths;
- same-host C/D comparison benchmarks;
- the legacy SH-18 executable differential oracle.

Their authoritative boundary is
`historical/HISTORICAL_BOOTSTRAP_AUDIT_KIT.json`. They are absent from the
standalone release and are not invoked by `openc workflow` or
`openc release`.

## Next owner

SH-22 takes over the active path for PE/COFF objects, DLLs, libraries,
resources/manifests, subsystem selection, secure dynamic linking, and optional
C-ABI interoperability. Linux and freestanding remain optional future work.
