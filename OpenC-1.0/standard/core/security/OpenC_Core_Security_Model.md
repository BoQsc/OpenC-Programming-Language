# OpenC Core Candidate 2 — Implementation Readiness Security Model

## Safe-code guarantees

For valid safe Core source, the language guarantees:

- source is decoded and tokenized deterministically;
- statically invalid source is rejected rather than deferred into arbitrary runtime behavior;
- initialized-before-read and path-sensitive output proof;
- checked integer arithmetic, shifts, bounds, optional extraction, and conversions;
- non-null safe references and bounded slices;
- owner lifetime outlives every safe borrow and slice;
- no use-after-move, double discharge, hidden owner copy, or partial resource publication;
- no typed access outside one active compatible lifetime generation;
- deterministic evaluation and complete LIFO cleanup on structured exits;
- no hidden exception path and no residual arbitrary undefined-behavior category.

## Unsafe boundary

Unsafe code may acquire raw addresses, perform pointer arithmetic and dereference, reinterpret values or pointers, and call declared unsafe operations. It remains subject to typing, sequencing, ownership, provenance, extent, alignment, lifetime, initialization, constness, representation-validity, and target-fault rules.

A violated unsafe precondition produces only one target-declared fault consequence. It does not license unrelated compiler invention or erase effects sequenced before the target physically prevents observation.

## Pointer and representation safety

A raw pointer carries abstract provenance, extent, offset, pointed-to type/constness, lifetime generation, and one-past state. Arithmetic never changes provenance. Address-of is limited to stable addressable locations.

`ptr const byte` may read initialized non-padding representation bytes. `ptr byte` may write byte objects, byte-array elements, or declared raw provider storage. It cannot corrupt the representation of a live non-byte typed object. A low-level representation rewrite first ends or invalidates typed lifetime and reconstructs a valid value before safe access resumes.

## Checked failures

Bounds errors, checked overflow, invalid shifts, division by zero, invalid optional extraction, and similar dynamic violations in otherwise valid safe source are structured checked failures. They run required no-fail cleanup and terminate the declared execution boundary with stable diagnostic identity.

## Recoverable failures

Recoverable operations return `status`. No hidden exception path exists. `out` values and ownership obligations publish transactionally only after success proof. Losing the final unresolved proof carrier is invalid.

## Resource and cleanup safety

Resource values are never copied by ordinary syntax. Ownership begins and ends exactly once. Construction reserves stable sources and commits atomically. Movement is explicit through domain operations.

A scope cleanup target is exported as no-fail for every valid input. It may contain internal unsafe work only when a safe wrapper proves all preconditions and admits no target fault for valid input. Fallible protocol completion is explicit before no-fail release or discard.

## Numeric variants

Ordinary arithmetic is checked. The safe wrapping and saturating intrinsic sets are closed and exact. Core defines no separate unchecked arithmetic operation. `cast_unchecked` remains a narrowly specified unsafe integer conversion and does not introduce arbitrary behavior.

## Non-goals

Core safety does not guarantee application logic correctness, availability, real-time response, protection from malicious external code, absence of algorithmic denial of service, or Hosted/Native/Concurrent behavior. Those components carry separate contracts and claims.
