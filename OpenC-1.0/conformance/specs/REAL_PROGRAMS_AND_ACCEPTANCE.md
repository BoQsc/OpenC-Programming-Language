# Maintained Core Programs

Before Core 1.0 freeze, three independently maintained programs are required.

## Program A — deterministic computation

Uses modules, functions, constants, structs, enums, arrays, slices, loops, switch, checked arithmetic, and text values without Hosted I/O.

## Program B — flow and ownership

Uses optional values, status/out, resources, transactional construction, domain movement, scope cleanup, borrows, and failure paths.

## Program C — unsafe boundary

Uses typed storage, construct/destroy, raw pointers, provenance, bounds/alignment checks, byte access, and a safe wrapper around a narrow unsafe operation.

Each program has source hashes, expected semantic result, supported targets, implementation revision, build commands, diagnostics, runtime evidence, and a maintainer not solely dependent on the primary specification author.
