# Implementation Gates

## I0 — Complete source frontend

All grammar productions parse; malformed source rejects at the correct source/lexical/syntax phase; AST and spans export deterministically.

## I1 — Names, types, constants, overloads

All declarations, module composition, conversions, constant expressions, and overload rules execute.

## I2 — Flow and recoverable failure

CFG, initialization, optional presence, loops/merges, and status/out lineage execute.

## I3 — Ownership and borrowing

Resources, movement, transactional construction, cleanup, and borrow exclusivity execute.

## I4 — Storage, pointers, unsafe

Typed lifetimes, provenance, alignment, byte access, safe wrappers, and target faults execute.

## I5 — Execution

An interpreter or backend executes every Core runtime fixture and the three maintained Core program classes.

Every gate records evidence using `schemas/IMPLEMENTATION_RECORD.schema.json`.
