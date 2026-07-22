# OpenC 1.0 release scope

## Supported claim

OpenC 1.0 ships an owner-certified Core and Hosted source distribution plus a
reference implementation verified on Windows 10 x86-64 with the recorded DMD,
DUB, linker, and Python toolchain.

The required 1.0 implementation gates are Windows debug/release builds, the D
and Python tests, the complete authored conformance manifest, runtime fixtures,
maintained programs, structure/source-completeness checks, deterministic source
archives, and the local licensing/governance authorization.

Canonical OpenC source uses `.p`. The source distribution also contains an
executed compiler-in-OpenC frontend with SH-1 bootstrap, SH-2A exact lexical
parity, SH-2B owned single-pass lexer state, SH-2C exact parser parity, SH-2D
exact project/module parity, and full syntactic/project SH-2 parity. Semantic
and IR parity (SH-3) plus bootstrap self-compilation and closure (SH-4) also
pass. The self-hosted compiler still uses its D bootstrap backend and a
configured DMD. DMD independence (SH-5) and standalone packaging (SH-6) are
separately tracked future gates, not prerequisites retroactively added to the
D-bootstrap 1.0 claim.

## Experimental source included without a support claim

Linux, freestanding, standalone C providers, Native interfaces, script/live,
and Concurrent material may be included for continued development. It is not a
claimed 1.0 binary target, is not verified by the 1.0 release record, and does
not block the Windows x86-64 Hosted release.

Adding a supported target later requires its own target record, native build and
runtime evidence, maintained-program execution, provider tests, artifact
checksums, and owner authorization. No current source file implies that future
claim.

## Evidence limits

Passing the 268-fixture authored conformance set is concrete executable
evidence, not a mathematical proof of every behavior. Dedicated fixtures cover
331 of 466 active Core rules; 135 rules remain on the documented authoring
backlog. This gap is disclosed and does not convert those rules into optional
language semantics.

The 174-production grammar and parser pass structural/build/suite validation;
dedicated positive/rejection evidence pairs for every individual production
remain an explicit future evidence improvement.
