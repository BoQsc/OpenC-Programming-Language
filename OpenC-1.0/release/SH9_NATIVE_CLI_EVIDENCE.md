# SH-9 native CLI and diagnostic usability evidence

Status: **PASS**  
Required target: **Windows x86-64 Hosted**

SH-9 makes the self-hosted OpenC compiler directly useful as a public
developer command. The implementation is authored in
`compiler/selfhost/source/cli.p`; the retained D seed is not used by any
required SH-9 command, test, workflow, or release gate.

## Public native commands

```text
openc check --project=PROJECT [--output=CHECK-RECORD.json]
openc build --project=PROJECT --output=OUTPUT.exe
openc run --project=PROJECT [-- PROGRAM-ARGUMENTS...]
openc version
openc target
openc explain RULE-ID
```

`check` runs the existing native project, flow-safety, and semantic-IR
stages rather than implementing a second semantic path. It prints concise
human diagnostics. When `--output` is supplied it also writes
`openc.check.v1`, retaining the underlying stable project, flow, and
semantic observation streams.

`run` first applies the same check, builds through the packaged C11/TinyCC
backend, forwards program arguments after `--`, executes the program, and
returns its exit code. Compiler progress text is not mixed into successful
program output.

`explain` reads the packaged canonical 466-rule index. The 93 historical
rule-ID compatibility matches remain explicitly identified as
`historical_compatibility_disclosed`; they are not presented as current
normative rule entries.

## Executed CLI contract

```text
python scripts/verify_sh9_cli.py
```

All 12 required cases pass:

1. help lists the public native surface;
2. version identifies OpenC 1.0.0-rc.9 and the self-hosted compiler;
3. target reports Windows x86-64 Hosted, 64-bit pointers, and TinyCC;
4. an active rule is explained from the canonical rule index;
5. a historical diagnostic identity is explicitly disclosed;
6. an unknown rule fails visibly;
7. a valid project passes and writes a valid machine record;
8. a lexical failure has an exact human rule/location and machine stream;
9. a flow failure has an exact human rule/location and machine stream;
10. an acceptance-stage failure has a concise human summary and retained
    machine stream;
11. a demo builds and runs through public `openc run`;
12. hosted program arguments, including an argument containing a space, are
    forwarded exactly.

The automated record is
`build-output/sh9-cli-verification/sh9-cli-verification.json`.

## Direct demos and regression repair

All six demo projects execute through public `openc run` with exact output:

```text
python demos/run_all.py
```

The direct gate found and repaired an import-alias false positive: a local
parameter named `file` was incorrectly treated as the built-in
`system.file` module qualifier. Acceptance now resolves parameter and local
value shadowing before applying the built-in alias rule. The ownership demo
therefore passes the same public semantic check used by every other demo.

## Native closure and required gates

The reference SH-9 compiler contains 92 canonical compiler `.p` files:

```text
compiler SHA-256    573a9e41a95d964cb437e84302922aa78ee422a7ca925862f9d1d87f44aa0f09
generated C SHA-256 14fc123dcf938992302140298ed928d56c9031fe4d181dcefc112dc13fcc9d16
```

The complete required verification retains:

- 278/278 native conformance fixtures;
- 153/153 diagnostic contracts;
- 35/35 runtime fixtures;
- 4/4 maintained programs;
- 6/6 demos through public native `check`/`run`;
- 15/15 Python source tests;
- deterministic native Stage-2/Stage-3 compiler closure;
- deterministic standalone archive construction and relocated verification;
- zero retained-D-seed executions in required workflows.

The executed full workflow passed 10/10 tasks. Fresh native validation took
27.181 seconds with 6,549,504 bytes peak private memory. The native
self-rebuild took 437.734 seconds with 179,523,584 bytes peak private memory
and produced an executable byte-identical to its input. Both remain within
the existing 50-second and 620-second elapsed ceilings and their memory
ceilings.

Linux and freestanding remain optional future targets and are not SH-9
gates.

## Next engineering milestone

SH-10 is **native project workflow completeness**:

1. add native `openc fmt --check` and `openc fmt --write`;
2. add native `openc info` for project, target, and dependency inspection;
3. add native `openc test` with deterministic discovery and exit records;
4. route formatter, inspection, and test behavior through standalone release
   gates while preserving stable machine records.

Independent review remains welcome and nonblocking.
