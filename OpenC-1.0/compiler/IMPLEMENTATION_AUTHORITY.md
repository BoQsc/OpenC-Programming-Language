# OpenC compiler implementation authority

## Canonical reference source

The canonical authored OpenC 1.0 compiler is written in OpenC and lives under:

```text
compiler/selfhost/source/
```

Its project manifest is `compiler/selfhost/openc.project.json`; its public
entry point and compiler subsystems are the canonical `.p` sources named by
that manifest.

## Legacy bootstrap and comparison source

The D source under `compiler/source/` records the earlier stage-0 reference
implementation. The Python source under `compiler/bootstrap/python/` records
an earlier informative bootstrap. Both may help historical audit, bring-up,
and differential investigation, but neither is a current implementation
authority or a required compiler dependency. Both are excluded from the
standalone compiler distribution.

## Authority boundary

When implementation behavior conflicts with the current normative standard:

```text
the standard is authoritative
the implementation contains a defect
```

When the implementation reveals an ambiguity or contradiction in the standard, maintainers must record a specification finding and resolve it through the accepted change process. They must not silently redefine the language in source code.

## Evidence state

```text
OpenC compiler source:       canonical
OpenC native closure:        verified on Windows x86-64 Hosted
D source:                    retained legacy bootstrap/reference snapshot
D required by native build:  no
Python source:               retained informative bootstrap/audit material
Python required by openc:    no
TinyCC backend:              optional historical differential-audit component
Normal artifact backend:     OpenC-owned x64/PE32+; no external toolchain
```
