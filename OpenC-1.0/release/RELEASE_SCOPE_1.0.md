# OpenC 1.0 release scope

## Supported claim

OpenC 1.0 ships an owner-certified Core and Hosted source distribution plus a
standalone reference implementation verified on Windows 10 x86-64. The
OpenC-native compiler and shipped TinyCC backend do not require DMD, DUB, or
Python to build OpenC projects. The retained D/DUB/Python toolchain remains
recorded for audit, legacy conformance, and reference-implementation regression
evidence.

The required 1.0 implementation gates are Windows debug/release builds, the D
and Python tests, the complete authored conformance manifest, runtime fixtures,
maintained programs, structure/source-completeness checks, deterministic source
archives, and the local licensing/governance authorization.

Canonical OpenC source uses `.p`. The source distribution also contains an
executed compiler-in-OpenC frontend with SH-1 bootstrap, SH-2A exact lexical
parity, SH-2B owned single-pass lexer state, SH-2C exact parser parity, SH-2D
exact project/module parity, and full syntactic/project SH-2 parity. Semantic
and IR parity (SH-3) plus bootstrap self-compilation and closure (SH-4) also
pass. DMD-independent Windows self-hosting (SH-5) passes through deterministic
C11 emission and the shipped TinyCC 0.9.27 Win64 backend. Standalone packaging
and distribution verification (SH-6) also pass: the relocatable package
rebuilds the compiler through byte-identical native stages and passes the full
authored conformance and maintained-program gates.

The supported standalone library mode is the six compiler-provided
`system.file`, `system.io`, `system.memory`, `system.path`, `system.process`,
and `system.text` modules backed by the packaged Windows C runtime and native
shim. Authored Native-provider `.p` sources are distributed as future work and
are not part of the supported 1.0 package claim.

## Experimental source included without a support claim

Linux, freestanding, Native interfaces, script/live, and Concurrent material
may be included for continued development. It is not a claimed 1.0 binary
target, is not verified by the 1.0 release record, and does not block the
Windows x86-64 Hosted release.

Adding a supported target later requires its own target record, native build and
runtime evidence, maintained-program execution, provider tests, artifact
checksums, and owner authorization. No current source file implies that future
claim.

## Evidence limits

Passing the 278-fixture authored conformance set is concrete executable
evidence, not a mathematical proof of every behavior. Dedicated fixtures cover
all 466 active Core rules, and all 174 grammar productions name executed
accepting/rejecting fixture pairs. The dedicated authoring backlog is empty.
