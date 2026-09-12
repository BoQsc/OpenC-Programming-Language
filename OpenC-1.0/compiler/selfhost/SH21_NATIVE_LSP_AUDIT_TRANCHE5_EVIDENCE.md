# SH-21 OpenC-native LSP audit tranche 5 evidence

Status: **PASS FOR THIS TRANCHE; SH-21 REMAINS ACTIVE**.

## Boundary closed

The public OpenC-authored command

```text
openc lsp-audit --output=REPORT.json
```

now owns the required language-service regression gate that previously depended
on `scripts/verify_sh11_lsp.py` and `scripts/verify_sh12_semantic_lsp.py`. It
constructs canonical byte-counted JSON-RPC request streams, runs isolated server
sessions through the guarded native process runner, decodes every response
frame, and emits `openc.native_lsp_audit.v1` JSON. The command invokes no
Python, D, C, TinyCC, Microsoft CRT, shell, assembler, or external linker.

The internal `--lsp-audit-batch` adapter reads a bounded request stream from an
evidence file, validates every exact `Content-Length` boundary, and submits each
decoded body to the same `lsp_handle_message` state machine used by public
`openc lsp --stdio`. Server responses still pass through the production
`lsp_send` byte-framing path. This avoids adding another fragile stdin-pipe
implementation to the process runner while retaining real child-process,
framing, lifecycle, and response verification. Public standard-input framing is
unchanged and remains owned by the native backend.

## Native checks

The audit passes 42/42 named checks across four independent session shapes:

- primary lifecycle, initialization identity and capabilities, UTF-8 positions,
  full document synchronization, native diagnostics, formatting, close,
  unknown-method behavior, shutdown behavior, and a byte-deterministic repeat;
- request-before-initialize and exit-without-shutdown rejection;
- duplicate-initialize rejection followed by a clean shutdown;
- three-document synchronization, project-root isolation, document and function
  symbols, typed hover, cross-document definition and references, sorted
  completion, prepare-rename, deterministic safe rename, rejected unsafe and
  colliding renames, close invalidation, shutdown, and a byte-deterministic
  repeat.

The native response observations are:

```text
primary response frames:       10
semantic response frames:      17
primary wire SHA-256:          d85f8af89a953cae4ee1fbfa62cc6de81e917dee77f1c4b2a739f3f79f06bad6
semantic wire SHA-256:         41a3b7118176c157dc4809f5f855b81d479c391a31b9b29f89b7b610b38687e1
```

The decoder rejects missing or malformed prefixes, empty or non-decimal
lengths, frames above 1 MiB, truncated headers and bodies, trailing non-frame
bytes, and bodies without a JSON-RPC 2.0 object marker. Request-stream buffers
are capped at 64 KiB; an explicit 65,537-byte aggregate request-stream probe is
rejected before decoding. Normal child capture remains capped at 4 MiB and
contained by the 256 MiB Job/private and 64 MiB working-set rules.

## Independent compatibility evidence

The retained Python verifiers are no longer required workflow owners. As an
optional external compatibility check against the final compiler, they still
pass:

```text
SH-11 lifecycle/document LSP:  19/19
SH-12 semantic project LSP:    23/23
SH-11 transcript SHA-256:      9526c85e64b15d630380235224d5bcab808d656d403ad02d099561592cb107dd
SH-12 transcript SHA-256:      47467cb5d9cd6f0dcedcb3c94426bc10b480d05357f32d5c2adc3a061e39a454
```

Those checks exercise the public operating-system stdin/stdout transport and
confirm that the native audit integration did not change its contract.

## Closure, workflow, and resource evidence

The final compiler contains 120 canonical OpenC source units and 1,711,619
source bytes. Two generations are byte-identical:

```text
executable bytes:       5,525,504
Stage 2 SHA-256:        4dbf142cbd8ac6d22ad12a7842da78a6ebd6c6310d7cf7e5dcff2eb0bdfc995d
Stage 3 SHA-256:        4dbf142cbd8ac6d22ad12a7842da78a6ebd6c6310d7cf7e5dcff2eb0bdfc995d
```

The measured fully validating rebuild completed in 21.090 seconds and peaked at
220,975,104 private bytes and 48,021,504 working-set bytes. The native LSP audit
completed in 1.417 seconds and peaked at 5,644,288 private bytes and 6,512,640
working-set bytes. All remain below the 25-second, 256 MiB private, and 64 MiB
working-set gates.

The integrated daily workflow passes 7/7 tasks. The integrated full workflow
passes 11/11 tasks, 278/278 conformance, 5/5 programs, all four process guards,
366/366 required-file checks, the PE and LSP audits, both self-builds, and exact
fixed-point comparison. It completed in 143.130 seconds with the controller at
35,852,288 peak private bytes and 30,113,792 peak working-set bytes. Its report
records no Python, D, C compiler, TinyCC, assembler, or external linker use. A
copy renamed to `renamed-sh21-tranche5.exe` also passes the complete 7/7 daily
workflow.

## Remaining SH-21 work

The next engineering slice is OpenC-native benchmark sampling and enforcement
of the existing SH-20 throughput/resource gates. Deterministic release/archive
ownership and the separately named optional historical bootstrap/audit kit then
remain before SH-21 can close.
