# SH-21 Python workflow inventory and disposition

Status: **INVENTORY COMPLETE; NATIVE REPLACEMENT IN PROGRESS**.

This inventory names every Python-owned operation that can affect a normal
Windows Hosted build, test, benchmark, package, or release decision. Historical
bootstrap and differential tools are listed separately because SH-21 does not
delete archaeology; it makes that material unavailable to normal workflows.

## Required workflow surface entering SH-21

| Python owner | Current responsibility | SH-21 disposition | Native status |
| --- | --- | --- | --- |
| `scripts/windows_native_workflow.py` | Aggregate daily/full task selection and JSON evidence | Replace with `openc workflow` | First native daily/full slice implemented |
| `scripts/generate_native_conformance_plan.py` | Prove fixture plan is synchronized | Move plan verification into native workflow audit | Pending |
| `scripts/validate_structure.py` | Canonical-tree and state invariants | Implement native manifest/state audit | Pending |
| `scripts/source_completeness.py` and `source_inventory.py` | Source inventory and authored-source completeness | Implement deterministic OpenC source manifest audit | Pending |
| `scripts/complete_conformance_coverage.py` | Grammar/rule/fixture coverage | Implement native coverage audit over pinned manifests | Pending |
| `tests/python/test_*.py` | Source and harness regression assertions | Move behavioral assertions to native workflow fixtures; retain Python copies only as optional audit | In progress |
| `scripts/verify_sh9_cli.py` | Public CLI and diagnostic contract | Native workflow task set | Basic version/target/check covered; exact negative cases pending |
| `scripts/verify_sh10_project_workflow.py` | Formatter, info, test and project commands | Native workflow task set | Maintained `openc test` path covered; remaining cases pending |
| `scripts/verify_sh11_lsp.py` | JSON-RPC and basic LSP lifecycle | OpenC-native LSP client/verifier | Pending |
| `scripts/verify_sh12_semantic_lsp.py` | Project symbols/navigation/rename | OpenC-native LSP client/verifier | Pending |
| `scripts/verify_sh16_pe_runtime.py` | PE imports, sections, relocations, unwind, TLS and CRT absence | Reuse OpenC PE/COFF reader in native audit command | Pending |
| `scripts/verify_sh17_winmd_projection.py` | Pinned metadata and generated raw projection | Add native projection comparison/report command | Reader/generator native; verifier pending |
| `scripts/verify_sh18_windows_modules.py` | Friendly-module build/runtime contract | Native compile/run manifest; move C/TinyCC comparison to optional audit | Pending |
| `tests/run_maintained.py` | Four maintained program builds and exit assertions | `openc workflow` through `openc test` | Implemented for all four programs plus native `out ptr` regression |
| `demos/run_all.py` | Demo compilation and execution | Native test manifest | Pending |
| `benchmark_windows_validate.py` and `benchmark_windows_rebuild.py` | Timings and process ceilings | Native benchmark/process-supervision command | Native timing and closure implemented; hard child ceilings pending |
| `benchmark_sh20_stability.py` | Samples, 20-build closure and performance gates | Native benchmark driver | SHA-256 closure primitive reused; sampling/gates pending |
| `release/build_standalone_windows.py` | Deterministic standalone tree and ZIP | `openc release build` with bounded streaming I/O | Pending directory/ZIP substrate |
| `release/verify_standalone_windows.py` | Relocation, manifest, closure, imports and behavior | `openc release verify` | Pending; several checks already reusable from workflow |
| `release/build_source_archive.py` and `verify_source_archive.py` | Source snapshot and manifest integrity | Native release archive mode | Pending directory/ZIP substrate |
| `release/windows_native_release.py` | Aggregate two-build release transaction | `openc release` | Pending |

The first `openc workflow` slice is intentionally honest about the remaining
gap. It is OpenC-authored and performs public CLI identity checks, a semantic
project check, all four established maintained-program checks, one native
runtime output-pointer regression, native 278-fixture
conformance, two compiler rebuilds, SHA-256 hashing, exact fixed-point closure,
and deterministic JSON reporting. It does not claim child-process RAM limits,
tree structure coverage, PE inspection, LSP transcript verification, or ZIP
ownership until those capabilities move into OpenC.

## Optional historical/bootstrap boundary

The following are not candidates for normal-workflow translation. They move to
the explicitly requested audit/bootstrap boundary and must never be searched or
invoked by `openc workflow` or `openc release`:

- `compiler/bootstrap/python/**`;
- `compiler/selfhost/bootstrap*.py`;
- lexer/parser/project/semantic parity scripts;
- retained D implementation and DMD/DUB launch paths;
- generated-C, C-runtime and TinyCC differential paths;
- C/D comparison mode in the throughput reference benchmark.

They may remain useful for first-binary recovery, historical investigation, or
an explicitly requested differential audit. Their presence in the repository
does not make them a normal build, test, package, release, or runtime
dependency.

## Next implementation slice

1. Add OpenC-owned bounded child supervision: timeout, output ceiling, peak
   private bytes and peak working set, with child-tree termination on failure.
2. Move canonical-tree/source/coverage checks into `openc workflow`.
3. Add the native PE import, unwind and CRT-absence audit.
4. Replace the LSP Python clients with an OpenC-native framed client.
5. Add directory enumeration/creation and deterministic ZIP emission for
   `openc release`.
