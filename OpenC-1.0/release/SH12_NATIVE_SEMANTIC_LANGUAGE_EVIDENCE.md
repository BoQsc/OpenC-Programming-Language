# SH-12 native semantic language intelligence evidence

Date: 2026-07-28
Target: Windows x86-64 Hosted
Status: **PASS**

SH-12 completes project-semantic editor intelligence in canonical OpenC `.p`
source. Linux, freestanding, Native-provider, and retained-D comparison work
remain outside this required gate.

## Native implementation

`compiler/selfhost/source/cli_lsp.p` now owns a bounded eight-document
synchronized workspace while preserving the SH-11 lifecycle, diagnostics, and
formatting contract. `compiler/selfhost/source/cli_lsp_semantic.p` builds a
deterministic declaration-semantic index from native lexer tokens in
URI/source order and implements:

```text
textDocument/documentSymbol
textDocument/hover
textDocument/definition
textDocument/references
textDocument/completion
textDocument/prepareRename
textDocument/rename
```

Semantic context is limited to open documents under `initialize.rootUri`.
Document symbols retain source order; project references and rename edits sort
by URI and source position; completion labels are unique and
lexicographically sorted. Rename rejects non-identifiers, keywords, unresolved
targets, and collisions with existing declarations. Closing a document
immediately removes its declarations from project context.

The authoritative 96-source compiler was built by the installed OpenC-native
SH-11 compiler. DMD, DUB, and Python were not invoked by that build:

```text
compiler SHA-256    e5fd8b31cf5e2809d1a3ed564038dadf70f497cd05c357c7c02b5af2b13c9a76
generated C SHA-256 dfaa790f3df05e5803996e5fae147c7dda1b9955beb04d40b7b0fdfd61ddd0c6
source fingerprint  b40457a76888f730cf20f72529c89f576b99fc1537f49f746e42aa89bf866b1e
```

The installed standalone distribution has the same compiler-source
fingerprint as the canonical tree.

## Stable project-semantic transcript

The published `openc.semantic_lsp_transcript.v1` contract is specified by
`schemas/SEMANTIC_LSP_TRANSCRIPT.schema.json`. The authored
`tests/tooling/sh12/session.json` fixture synchronizes two project documents
and one outside-root document. The verifier runs the same semantic exchange
after opposite document-open orders and requires byte-identical output.

```text
python scripts/verify_sh12_semantic_lsp.py --force
```

Result: **23/23 PASS**. Twenty live native cases cover advertised semantic
capabilities; three-document synchronization; document and function symbols;
typed hover; cross-document definition and references; reference ordering;
complete deterministic completion; project-root isolation; prepare-rename;
project-wide safe rename and edit ordering; keyword and declaration-collision
rejection; synchronized close; and clean shutdown. The remaining cases require
open-order-independent transcript bytes, JSON Schema validation, and verified
standalone-native provenance.

Both semantic transcripts are byte-identical at SHA-256:

```text
47467cb5d9cd6f0dcedcb3c94426bc10b480d05357f32d5c2adc3a061e39a454
```

The SH-11 regression verifier also passes **19/19** on the same compiler.
All 29 focused Python source tests pass.

## Required workflow scope

Native workflow schema `openc.windows_native_workflow.v5` adds
`native_semantic_language_service` after the complete SH-11 regression gate.
Standalone release schema `openc.self_host_standalone_release.v5` requires the
same 23 cases against relocated Stage 3. Required workflows do not execute the
retained D seed. Current conformance execution uses zero compatibility
fallback matches; the 93 historical rule-ID compatibility matches remain
explicitly disclosed.

The forced native full workflow passes **13/13** tasks. Fresh validation passes
278/278 in 28.872 seconds with 6,860,800 bytes peak private memory and
8,495,104 bytes peak working set. The 96-source self-rebuild completes in
780.621 seconds with 208,019,456 bytes peak private memory and 13,787,136 bytes
peak working set. It produces byte-identical compiler SHA-256
`e5fd8b31cf5e2809d1a3ed564038dadf70f497cd05c357c7c02b5af2b13c9a76`
and generated C SHA-256
`dfaa790f3df05e5803996e5fae147c7dda1b9955beb04d40b7b0fdfd61ddd0c6`.
The existing 90-second validation, 1,050-second rebuild, 16 MiB validation
memory, 256 MiB rebuild-private-memory, and 32 MiB rebuild-working-set ceilings
remain sufficient and unchanged.

The full workflow record is
`build-output/selfhost-sh12/full-workflow/full-workflow-result.json`.

The first daily workflow passes **12/12** tasks and executes all 278 fixtures
in 28.175 seconds. Repeating the exact inputs passes 12/12 with a 0.002-second
cache hit and executes zero fixtures.

Two independently assembled 1,504-entry standalone package manifests are
byte-identical at archive SHA-256:

```text
038fc6a0e1566df93fed06cd806857df0b1894cd1ce82d01429daf66f60fc4f7
```

Archive A and B assembled in 47.758 and 42.159 seconds. Complete relocated
verification took 1,585.759 seconds. The packaged compiler, relocated Stage 2,
and relocated Stage 3 are byte-identical at SHA-256
`e5fd8b31cf5e2809d1a3ed564038dadf70f497cd05c357c7c02b5af2b13c9a76`.
Generated C is byte-identical at
`dfaa790f3df05e5803996e5fae147c7dda1b9955beb04d40b7b0fdfd61ddd0c6`;
normalized Stage-2/Stage-3 PE is equal at
`06da6bc71b31a9d1264a9f492401dbdf53ce5392f94137bca3978b644871a29d`.

Relocated Stage 3 passes 23/23 SH-12 semantic language-service contracts,
19/19 SH-11 baseline language-service contracts, 21/21 SH-10 project-workflow
contracts, 12/12 SH-9 CLI contracts, 278/278 conformance fixtures, 35/35
runtime fixtures, 153/153 diagnostic contracts, and 4/4 maintained programs.
Infrastructure failures are zero. The closure records are:

- `build-output/selfhost-sh12/release/standalone-release-result.json`;
- `build-output/selfhost-sh12/release/native-release-workflow-result.json`.

## Next engineering milestone

SH-13 is **native editor integration and language-service resilience**:

1. ship a first-party editor client that launches the packaged native server;
2. add incremental, monotonic-version document synchronization;
3. add cancellation, workspace lifecycle, and bounded resource handling;
4. verify editor launch and protocol stress from the relocated standalone
   package.

Independent review remains welcome and nonblocking. Linux and freestanding
remain optional future targets.
