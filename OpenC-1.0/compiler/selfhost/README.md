# OpenC compiler-in-OpenC frontend

This directory begins the self-hosting implementation in canonical `.p`
source. The stage-0 D compiler builds `source/main.p` into a native Windows
executable. That executable implements the stage-0 byte-exact lexer and source
encoding rejection in OpenC. It performs one lexical pass, stores tokens and
diagnostics in OpenC-owned buffers, and attaches byte-accurate source
positions. Its versioned observation stream matches stage 0 on every
canonical `.p` source and focused lexical probe.

This is executable self-hosting evidence, not a completed self-hosted compiler.
It does not yet parse declarations, build semantic state or IR, emit objects,
link programs, or compile itself. Those capabilities are tracked by
`SELF_HOSTING.md` and must not be inferred from the lexer executable. The
machine-readable current gate state is `SELF_HOSTING_STATE.json`.

Run from the repository root after building stage 0:

```text
python compiler/selfhost/bootstrap.py
```

That command builds stage 1, makes it lex its own source, and executes the
300-case SH-2A/SH-2B parity gate. The next milestone is SH-2C: parser syntax
types, declarations, types, expressions, statements, and recovery.
