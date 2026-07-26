# OpenC compiler in OpenC

This directory contains the self-hosting implementation in canonical `.p`
source. The stage-0 D compiler builds `source/main.p` into a native Windows
executable. That executable implements the stage-0 byte-exact lexer and source
encoding rejection in OpenC. It performs one lexical pass, stores tokens and
diagnostics in OpenC-owned buffers, and attaches byte-accurate source
positions. The OpenC parser consumes those owned records and stores final
syntax records in a third owned buffer. Its lexical and parser observation
streams match stage 0 on every canonical `.p` source and focused probe. The
project frontend also loads JSON project records, resolves ordered source
units, composes logical modules/imports, and emits exact graph observations.
The semantic stages build OpenC-owned declaration, symbol, canonical type,
lexical-scope, constant-value, overload-selection, flow/safety, acceptance,
and canonical IR state and emit exact observations.

This is now a standalone, DMD-independent executable self-hosted compiler on
Windows x86-64 Hosted. It emits deterministic C11, invokes the shipped TinyCC
0.9.27 Win64 backend, links the next compiler stage, and reaches byte-exact
Stage-2/Stage-3 source and executable closure. SH-6 packages it with its source,
runtime, library inputs, backend, bootstrap audit seed, licenses, and integrity
records in a relocatable distribution. The gate contract is in
`SELF_HOSTING.md`; the machine-readable gate state is
`SELF_HOSTING_STATE.json`.

Run from the repository root after building stage 0:

```text
python compiler/selfhost/bootstrap.py
```

That command builds stage 1 and executes the 304-case lexer gate, 303-case
parser gate, 22-case project/module gate, 17-case declaration/symbol/type gate,
10 exact name/constant/overload comparisons, 232 flow/safety comparisons, and
full semantic-outcome/canonical-IR comparison. SH-2A through SH-2D, full SH-2,
SH-3A through SH-3D, and full SH-3 pass. SH-4A bootstrap D-source backend
parity, SH-4B Stage-1 self-compilation, SH-4C Stage-2/Stage-3 closure, and full
SH-4 also pass.

Run the SH-5 DMD-independent Windows closure proof with:

```text
python compiler/selfhost/bootstrap_windows_closure.py
```

The resulting native compiler exposes the public build command:

```text
openc build --project=path/to/openc.project.json --output=path/to/program.exe
```

Run the SH-4 proofs with a built Stage-1 executable and configured DMD:

```text
python compiler/selfhost/bootstrap_d_parity.py --stage1 build-output/selfhost-sh4/closure-final/openc-stage1.exe --output build-output/selfhost-sh4/parity-final
python compiler/selfhost/bootstrap_closure.py --output build-output/selfhost-sh4/closure-final
```

Run the complete SH-6 distribution proof with the commands recorded in
`release/SH6_STANDALONE_EVIDENCE.md`. SH-6 is **PASS**.
