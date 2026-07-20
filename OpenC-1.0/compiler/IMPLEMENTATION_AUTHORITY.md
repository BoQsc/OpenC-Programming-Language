# OpenC compiler implementation authority

## Canonical reference source

The canonical authored OpenC 1.0 reference implementation is written in D and lives under:

```text
compiler/source/
```

Its public entry point is `compiler/source/app/main.d`, and its compiler library is under `compiler/source/openc/`.

## Bootstrap source

The Python source under `compiler/bootstrap/python/` is informative bootstrap material. It is preserved because it may help future bring-up and cross-checking, but it is not a second current implementation authority.

## Authority boundary

When implementation behavior conflicts with the current normative standard:

```text
the standard is authoritative
the implementation contains a defect
```

When the implementation reveals an ambiguity or contradiction in the standard, maintainers must record a specification finding and resolve it through the accepted change process. They must not silently redefine the language in source code.

## Evidence state

```text
D source authored:           yes
D source compiled here:      no
D tests executed here:       no
Python bootstrap executed:   no
platform behavior verified:  no
```
