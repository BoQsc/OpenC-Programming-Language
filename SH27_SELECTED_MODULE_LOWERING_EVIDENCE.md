# SH-27 selected-module IR/native emission boundary

Status: **isolated lowering prerequisite; not automatic incremental builds**.
`openc artifact --project=PROJECT --kind=module-coff-set --module=MODULE
--output=PREFIX --timings=FILE` now lowers and emits only the named module.
It still parses, resolves, checks flow, and runs acceptance across the whole
project. This protects diagnostics while giving a cache manager a real
compile-miss operation rather than partitioning an already-emitted whole
project. Other sources release their acceptance context before the IR
function loop; they consume no SSA value IDs and emit no native records.
Their acceptance-created type closure is preserved in the project context.

Selection is restricted to serial module-COFF output, rejects missing/empty
module names, and cannot be combined with `--linked-exe`. Link selected and
previously saved objects through the separately proved `module-coff-link`
command. Normal nonselected build policy and artifact behavior are unchanged.
Selected timing reports expose `module_selection.sources_lowered` and
`sources_validation_only`; the latter is not a cache-hit or parse-skip count.

## Executed local proof, 2026-09-26

The production compiler's guarded source check passed. A guarded Stage 1→3
native bootstrap passed with exact Stage 2/3 SHA-256
`07db199b26bf69d32fbd91c902ce434c1d603f735e8f7ffdd22b8d26cdd0a077`.
Bootstrap uses 512 MiB guards; Stage 2 working set 69,492,736 and private
268,570,624 bytes exceed the separate strict 64/256 MiB limits. A separate
strict Stage 3→4 self-build reproduced the same SHA-256 and passed those
limits: peaks 61,476,864 working-set, 263,200,768 private, and 263,294,976
Job-private bytes.

`test_module_selected_lowering.py` passed under a 512 MiB process-tree
private / 128 MiB working-set guard, peaking at 31,289,344 Job-private and
18,038,784 working-set bytes. Its three-module project proves:

- Selecting each module gives one object, byte-identical to its full-build
  object; counters show one source lowered and two validation-only sources,
  with exactly one emitted function while `source_files` honestly stays 3.
- Linking the three separately emitted objects gives a byte-identical PE
  to the full build and executes with exit 7.
- After changing only the provider body, only that selected module is
  recompiled. Linking its new object with both unchanged saved objects gives
  a byte-identical PE to a fresh full build and executes with exit 8. The
  caller deliberately chooses the reuse set; no cache manager is claimed.
- A two-source selected module lowers both sources, validates the other
  two, emits exactly two functions, and retains exact full-build COFF bytes.
- Unknown selection fails before an output manifest. A return-type error
  in an unselected module still rejects the build with byte-exact stdout
  and stderr relative to full compilation; no manifest is published.

The existing saved/module link and bounded-reader suites passed again, as
did ten stable-symbol/default-artifact checks against the previous isolated
compiler. Raw ignored reports are in
`OpenC-1.0/build-output/sh27-module-selection-20260926/` and
`OpenC-1.0/build-output/sh27-module-selection-bootstrap-20260926/`.
The commit-triggered COFF proof workflow now includes the selected-module
suite and still enforces the complete strict 20-generation chain.

## Remaining SH-27 requirements

### Hosted proof of this selected-module source

Commit `2d693f4` passed the clean hosted [COFF proof run
36260957581](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/36260957581).
Raw artifact `10912427125` contains the selected-module guarded report and
`strict20.json`: all 13 strict stability checks and 20/20 exact chained native
rebuilds passed on compiler SHA-256
`07db199b26bf69d32fbd91c902ce434c1d603f735e8f7ffdd22b8d26cdd0a077`.
Chain maxima were 63,594,496 working-set, 264,396,800 private, and 264,413,184
Job-private bytes. Selected-module tests peaked at 19,701,760 working-set and
32,243,712 Job-private bytes. The independent paired [speed batch
36260957484](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/36260957484)
failed the gain gate: large/control median gains were 0 ms, both 5/11 wins,
against 6 ms null noise. No cold-throughput improvement is claimed.

The subsequent automatic cache implementation is separately documented in
`SH27_AUTO_MODULE_CACHE_EVIDENCE.md`; the following limitations describe the
selected-module command itself, not a claim that the newer cache is absent.

No automatic object hit, dependency-complete cache key, atomic publish,
concurrent-writer protection, cache corruption fallback, or measured warm/
edit speed exists yet. Whole-project parsing/resolution/validation remains;
even validation-only sources allocate their existing context scratch. Shared
`.data` and runtime-helper ownership and broader ABI/project coverage remain
required before general module reuse. Full acceptance skipping requires
validated semantic/interface records; this flag alone cannot provide it.
This slice is not a C/D throughput or full SH-27 certificate and is not
promoted into the production compiler.
