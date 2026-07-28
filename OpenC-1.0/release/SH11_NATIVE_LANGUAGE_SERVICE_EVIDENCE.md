# SH-11 native language-service completeness evidence

Date: 2026-07-28
Target: Windows x86-64 Hosted
Status: **PASS**

SH-11 adds the native editor-facing protocol foundation in canonical OpenC
`.p` source. Linux, freestanding, Native-provider, and retained-D comparison
work remain outside this required gate.

## Native implementation

The 95-source self-hosted compiler exposes:

```text
openc lsp --stdio
```

`compiler/selfhost/source/cli_lsp.p` owns JSON-RPC parsing, lifecycle state,
request validation, deterministic response serialization, one synchronized
document, compiler diagnostics, and document formatting. Initialization
advertises UTF-8 positions, full-document synchronization, and formatting.

The Windows Hosted C runtime supplies only framed transport: it reads
case-insensitive `Content-Length` headers, limits headers to 8 KiB and bodies
to 16 MiB, reads the exact body, validates UTF-8, and returns the frame through
the existing native `system.file.read_text` ABI using the reserved
`@openc-internal:lsp-stdio-frame` resource. Protocol semantics remain in
OpenC.

The authoritative SH-11 compiler was built from the current source tree by the
installed OpenC-native SH-10 compiler. DMD, DUB, and Python were not invoked
by that build. The outputs are:

```text
compiler SHA-256    a0a53c463a157dc671a77de95c2f2e7aad8d82563a264e551e6af219ba8bb318
generated C SHA-256 b4edf7653d507a55b77d7c2e543c265f5c315c7de9e0b8112aaa2fd9614132be
source fingerprint  5df0a1ee460508132e8c258b6e4354197cf529515c834efad42947bc77543d34
```

The installed standalone distribution has the same compiler-source
fingerprint as the canonical tree.

## Protocol and stable transcript contract

SH-11 supports:

```text
initialize
initialized
shutdown
exit
textDocument/didOpen
textDocument/didChange
textDocument/didClose
textDocument/formatting
```

Opening and changing a document run the native lexer/parser/check path.
Published diagnostics include stable OpenC rule IDs, severity, UTF-8 ranges,
messages, and byte-span data. A valid change and document close publish an
empty diagnostic set. Formatting calls the SH-10 formatter; invalid or
unopened documents are not rewritten.

Deterministic transcript records use `openc.lsp_transcript.v1`, specified by
`schemas/LSP_TRANSCRIPT.schema.json`. The authored session fixture is
`tests/tooling/sh11/session.json`.

## Executed native contract

```text
python scripts/verify_sh11_lsp.py --force
```

Result: **19/19 PASS**. The cases cover help discovery; initialize
capabilities and server identity; invalid-open diagnostics and their stable
contract; invalid-source non-formatting; valid change and diagnostic clearing;
SH-10 full-document formatting; close clearing; unopened-document and unknown
method errors; shutdown, post-shutdown rejection, and clean exit; pre-init
rejection; exit-without-shutdown failure; duplicate initialization;
byte-identical independent sessions; and exact JSON-RPC 2.0 UTF-8 framing.

Both independent transcript records validate against the schema and are
byte-identical at SHA-256:

```text
78cd47ec56903c7ade4dc90fb3e1b8a0892ea71468ebe1fd7a185f83e32e5dff
```

Five focused Python tests cover frame encoding/decoding, the authored fixture,
and transcript schema shape.

## Development and release closure

The SH-11 daily/full workflow adds `native_language_service` beside the
12-case SH-9 CLI gate, 21-case SH-10 project-workflow gate, maintained
programs, demos, complete native conformance, and performance budgets. The
release workflow builds two standalone archives independently, extracts one
into a foreign working directory, rebuilds Stage 2 and Stage 3, and runs the
same 19 cases against relocated Stage 3 before accepting the archive.

The complete native full workflow passes **12/12** tasks. Fresh validation
passes 278/278 in 39.664 seconds with 6,422,528 bytes peak private memory and
8,384,512 bytes peak working set. The 95-source self-rebuild completes in
945.439 seconds with 201,244,672 bytes peak private memory and 13,348,864
bytes peak working set. It produces generated C at SHA-256
`b4edf7653d507a55b77d7c2e543c265f5c315c7de9e0b8112aaa2fd9614132be`
and a byte-identical compiler at SHA-256
`a0a53c463a157dc671a77de95c2f2e7aad8d82563a264e551e6af219ba8bb318`.

The reviewed ceilings are 90 seconds for validation and 1,050 seconds for the
self-rebuild. The private-memory and working-set ceilings remain unchanged.
An initial build used the output name `final-openc.exe`; TinyCC retained that
PE module basename, so copying it to `openc.exe` could not be byte-equal to a
later executable linked directly as `openc.exe`. Generated C was already
byte-identical. Rebuilding and installing the stable `openc.exe` basename
removed the packaging artifact and the rerun reached exact executable closure.
The initial 905.429-second observation remains disclosed in the authored
performance review.

A fresh daily workflow passes **11/11** tasks and executes all 278 fixtures.
Repeating the exact inputs passes 11/11 with a 0.003-second conformance cache
hit and executes zero fixtures. The full record is
`build-output/selfhost-sh11/full-workflow-stable/full-workflow-result.json`.

Two independently assembled 1,498-entry standalone package manifests are
byte-identical at archive SHA-256
`6c73a64de6c16d33e34b5e3162678e8d8cfb2f63cbc12f7d30323fd0c6ca29a0`.
Archive A and B assembled in 139.211 and 59.692 seconds. Complete relocated
verification took 1,689.055 seconds.

The packaged compiler, relocated Stage 2, and relocated Stage 3 are
byte-identical at SHA-256
`a0a53c463a157dc671a77de95c2f2e7aad8d82563a264e551e6af219ba8bb318`.
Generated C is byte-identical at
`b4edf7653d507a55b77d7c2e543c265f5c315c7de9e0b8112aaa2fd9614132be`;
normalized Stage-2/Stage-3 PE is equal at
`3bb46ab678f83ea21d6aad426a2e3099c36f69baf564412e710e35e791b79e18`.

Relocated Stage 3 passes 19/19 SH-11 language-service contracts, 21/21 SH-10
project-workflow contracts, 12/12 SH-9 CLI contracts, 278/278 conformance
fixtures, 35/35 runtime fixtures, 153/153 diagnostic contracts, and 4/4
maintained programs. Infrastructure failures are zero. The closure records
are:

- `build-output/selfhost-sh11/release/standalone-release-result.json`;
- `build-output/selfhost-sh11/release/native-release-workflow-result.json`.

Required workflows do not execute the retained D seed. Current conformance
execution has zero edition-compatibility fallback matches; the 93 historical
rule-ID compatibility matches remain explicitly disclosed.

## Next engineering milestone

SH-12 is **native semantic language intelligence**:

1. add native document symbols and typed hover information;
2. add definition and reference navigation over synchronized project context;
3. add deterministic completion and validated safe rename;
4. verify multi-document/project-aware semantic transcripts from the
   relocated standalone package.

Independent review remains welcome and nonblocking. Linux and freestanding
remain optional future targets.
