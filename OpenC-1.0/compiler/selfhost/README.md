# OpenC compiler-in-OpenC seed

This directory begins the self-hosting implementation in canonical `.p`
source. The stage-0 D compiler builds `source/main.p` into a native Windows
executable. That executable reads UTF-8 OpenC source, performs deterministic
scalar-based lexical scanning, rejects unterminated strings/comments and
unbalanced delimiters, and successfully scans its own source.

This is executable self-hosting evidence, not a completed self-hosted compiler.
It does not yet parse declarations, build semantic state or IR, emit objects,
link programs, or compile itself. Those capabilities are tracked by
`SELF_HOSTING.md` and must not be inferred from the seed executable. The
machine-readable current gate state is `SELF_HOSTING_STATE.json`.

Run from the repository root after building stage 0:

```text
python compiler/selfhost/bootstrap.py
```
