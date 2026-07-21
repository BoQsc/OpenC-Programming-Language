# OpenC 1.0.0-rc.8 verification status

Date: 2026-07-21
Host: Windows 10.0.19045, x86-64

## Verified scope

This evidence supports the owner-certified Windows x86-64 Hosted reference
implementation. Linux, freestanding, Native, standalone C providers,
script/live, and Concurrent work are outside the supported 1.0 scope.

## Toolchain

- DMD 2.112.0
- DUB 1.41.0
- DMD-bundled `lld-link`
- Python 3.13.7

## Executed evidence

- 9 of 9 canonical D targets build and link in debug mode.
- 9 of 9 canonical D targets build and link in release mode.
- 8 of 8 authored D test commands pass.
- 4 of 4 Python bootstrap tests pass; bytecode and CLI smoke checks pass.
- 268 of 268 conformance fixtures pass with zero infrastructure failures.
- All 35 runtime fixtures build and execute to their expected output/outcome.
- All 4 maintained programs check, build, and run to their authored contracts.
- All 281 pre-existing OpenC source files were migrated to `.p`; together with
  the compiler-in-OpenC lexer/parser/project frontend and its two checked-in
  semantic passes, the tree contains 288 canonical `.p` sources. The
  migrated fixture corpus retains 268/268 passes and zero infrastructure
  failures.
- The compiler-in-OpenC frontend builds through stage 0 and passes SH-2A exact
  lexer parity plus SH-2B owned single-pass lexer state: 288 canonical `.p`
  sources plus 16 focused probes, 304/304. Outcomes, token kinds, byte spans,
  line/byte-column positions, diagnostic rules, source-encoding rejection,
  and totals match exactly; all 12 source/lexical diagnostic rules are
  observed.
- SH-2C exact parser parity passes on all 288 canonical sources plus 15 focused
  parser probes, 303/303. Syntax-node creation order, all 52 parser-produced
  kinds and final byte spans, 15 reachable parser/recovery rules, diagnostic
  positions, node totals, and error totals match exactly.
- SH-2D exact project/module parity passes on all 7 checked-in projects plus
  15 focused probes, 22/22. Sorted modules, ordered source units, resolved
  paths, imports, per-source parsing, missing imports, ambiguous short
  qualifiers, direct cycles, and totals match exactly. Together SH-2A through
  SH-2D promote full lexical/syntactic/project frontend SH-2.
- SH-3A exact declaration, symbol, and canonical type-table parity passes on
  the canonical compiler project plus 16 focused semantic projects, 17/17.
  The compared observations cover declaration/member order, visibility,
  parameter modes, ownership/resource state, canonical type IDs and
  constructors, source spans, and duplicate-declaration diagnostics.
- SH-3B exact name, constant, and overload resolution parity passes on the
  maintained computation project plus 9 focused projects, 10/10. The compared
  observations include 32 exact bindings, 10 constant results, 4 selected
  calls, and exact unknown-name, no-match, ambiguity, and divide-by-zero rules.
- Structure, source-completeness, manifest, and archive verification pass.

Fixture execution now distinguishes normative rules from implementation
diagnostic codes. All rejection diagnostic expectations match exactly and the
historical edition-compatibility fallback is removed (zero compatibility
matches). Imported fixtures retain their origin records while targeting OpenC
Core 1.0 Current.

Dedicated executable fixtures name 331 of 466 active Core rules. The remaining
135-rule fixture-authoring backlog is explicit in the manifest and coverage
matrix. It limits evidence granularity but does not mean those normative rules
are removed or that untested targets are supported.

The 174-production grammar is structurally validated and the parser is built
and suite-tested. Dedicated positive/rejection evidence pairs are not complete
for every individual production and remain nonblocking follow-up work.

## Reproduction commands

```text
python build/build_all.py --build debug --tools --compiler dmd
python build/build_all.py --build release --tools --compiler dmd
python tests/run_all.py
PYTHONPATH=compiler/bootstrap/python python -m unittest discover -s tests/python
compiler/openc validate --manifest=conformance/fixtures/MANIFEST.json
python tests/run_maintained.py
python compiler/selfhost/bootstrap.py
python scripts/validate_structure.py
python scripts/source_completeness.py
```

## Release conclusion

HD-012 is ratified, the declared platform gate passes, and independent external
review is a recommended post-release assurance activity rather than an initial
owner-certified release prerequisite. The candidate is `RELEASE_READY` for its
declared Windows x86-64 Hosted scope. It remains unpublished and therefore is
not `RELEASED`. SH-2A through SH-2D and full lexical/syntactic/project SH-2 are
executed self-hosting milestones. SH-3A declaration/symbol/type-table and
SH-3B name/constant/overload parity also pass. SH-3C flow/safety parity is
next; the remaining SH-3 subgates through SH-6 do not yet claim
self-compilation or a standalone backend.
