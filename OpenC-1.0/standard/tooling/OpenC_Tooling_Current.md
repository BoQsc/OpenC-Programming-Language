# OpenC Tooling and Diagnostics 1.0 — release-candidate baseline

Status: **OWNER-RATIFIED; WINDOWS X86-64 BUILD AND TEST PASS**

This component standardizes the interoperable surfaces of OpenC tools. It does not require one implementation architecture, but the first-party implementation reuses one compiler library across all tools.

## 1. Required commands

```text
openc check
openc build
openc fmt
openc info
openc explain
openc validate
openc lsp --stdio
```

Hosted-capable implementations may additionally provide:

```text
openc run
openc test
openc eval
openc live
```

## 2. Command syntax

Classical CLI syntax is primary:

```text
openc check source/main --profile=strict --diagnostics-format=jsonl
```

The OpenC-style alternative is also accepted:

```text
openc 'check(file="source/main", profile="strict", diagnostics_format="jsonl")'
```

Both normalize to one command-request record before dispatch. Ambiguous or conflicting values are rejected rather than resolved by last-wins guessing.

## 3. Diagnostics

A machine-readable diagnostic contains:

```text
severity
phase
stable rule ID
category
message
primary source span
related source spans
notes
safe help actions
source/expansion trace
active edition, profile, target, and extension context
```

Human wording may improve without changing rule identity. Tools must not require scraping terminal text.

## 4. Formatter

The canonical formatter is deterministic:

```text
four-space indentation
braces on the declaration/control line
semicolons retained
LF output
one final newline
100-column target width
comments preserved
no declaration, import, or field reordering
```

Formatting cannot change semantic meaning.

## 5. Language server

The language server uses JSON-RPC over standard input/output and supports, at minimum:

```text
text synchronization
rule-ID diagnostics
document symbols
hover
definition
references
completion
safe rename
formatting
```

It reuses the compiler's source manager, parser, name resolver, type checker, ownership model, and diagnostic engine.

## 6. Project context

The conventional project and lock files are:

```text
openc.project.json
openc.lock.json
```

They are tooling conventions, not source-language extensions. Project context maps logical modules to explicit source files, target context, profiles, generated source, dependencies, runtime providers, and output roots.

## 7. Conformance adapter

The adapter accepts structured fixture requests and reports:

```text
implementation identity
source and context hashes
fixture kind
phase reached
accept/reject/runtime outcome
diagnostics
stdout/stderr/exit status when executed
unsupported facilities
implementation limits
infrastructure failure
```

Rejecting everything, crashing, timing out, or claiming unsupported for a mandatory Core facility is not a pass.

## 8. Evidence states

Tooling records distinguish:

```text
AUTHORED
STRUCTURALLY_CHECKED
REVIEWED
EXECUTION_PENDING
EXECUTED
RELEASE_READY
RELEASED
```

A source package never upgrades itself to `EXECUTED` merely because build or test scripts are present.

## 9. First-party source

The current first-party source lives under `compiler/`, `tools/`, `scripts/`,
and `release/`. The required 1.0 command implementations build and pass their
Windows x86-64 test and conformance gates. Optional eval/live modes remain
experimental and outside the supported 1.0 claim.
