# Pointer Provenance and Unsafe Validation

A raw pointer abstract value tracks:

```text
nullness
pointed-to type and constness
provenance identity
byte offset
extent
lifetime generation
one-past state
```

Address-of creates provenance only for a finite addressable stable location. Derivation preserves provenance. Arithmetic is bounded from the first element/byte through one-past. Reinterpretation changes pointed-to type but not provenance or lifetime.

Typed dereference requires non-null, in-bounds, non-one-past, aligned access to a compatible active object lifetime. Representation reads through `ptr const byte` exclude padding and uninitialized bytes. Byte writes cannot corrupt a live non-byte typed representation.

Unsafe violations produce only a target-record fault outcome. The optimizer cannot infer unrelated impossibility from a possible unsafe fault.
