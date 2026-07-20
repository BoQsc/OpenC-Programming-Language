# OpenC Core Candidate 2 — Consolidated Rationale

This document is informative. Normative authority belongs to the Core Candidate 2 rulebook and EBNF.

## 1. Why Core Candidate 2 exists

OpenC began as an attempt to make systems-language rules open, referenceable, diagnosable, and executable by tools. Early drafts explored far more territory than a first implementation could reasonably validate. Core Candidate 2 therefore narrows the mandatory language, consolidates contradictory or duplicated rules, and separates Core from Hosted services, Native interoperability, script/live conveniences, critical assurance policy, and provisional concurrency.

The candidate follows one discipline:

```text
ordinary language meaning first
explicit safety boundaries second
provider and environment facilities outside Core
implementation evidence before freeze
```

## 2. C-shaped, not C-compatible

OpenC keeps direct declarations, braces, semicolons, ordinary functions, structs, arrays, and familiar expression operators where those forms remain clear.

```c
i32 add(i32 a, i32 b) {
    return a + b;
}
```

It does not preserve C source compatibility, textual inclusion, historical integer names, silent pointer decay, implicit lossy conversion, uninitialized reads, or arbitrary undefined behavior. Existing C code is migration input, not the definition of OpenC.

## 3. Word-shaped declaration constructors

OpenC declarations avoid C's symbolic declarator grammar.

```c
ref Player player;
ref const Player view;
ptr Player address;
optional Player maybe;
storage Player slot;
```

`&` and `*` remain available as classical low-level expression operators inside explicit unsafe work, but they do not alter declaration shape. This keeps declarations readable left-to-right while preserving familiar low-level expression syntax.

## 4. One grammar authority

Core Candidate 2 has one normative EBNF. Prose may impose semantic restrictions on a parsed form, but it cannot create ungrammatical syntax. A mismatch is a specification defect rather than an invitation for implementations to guess.

The `when` model is intentionally narrower than the runtime expression language. It accepts immutable declared build-context values and a finite set of boolean/comparison operations. It cannot inspect the host filesystem, environment, network, clock, or random state.

## 5. Deterministic evaluation

OpenC defines operand, argument, initializer, assignment, return-preparation, and cleanup ordering. Determinism improves portability, diagnostics, testing, and security review. Optimizers remain free to transform code only when observable values, ownership transitions, failures, and sequencing edges remain equivalent.

## 6. No arbitrary undefined-behavior category

Every Core operation has one finite outcome:

```text
defined success
required source rejection
recoverable status failure
structured checked failure
declared implementation-limit rejection
declared target-dependent success
bounded target fault after an unsafe precondition violation
```

Unsafe code transfers responsibility for specific low-level preconditions; it does not erase typing, ownership, lifetime, sequencing, or target rules. An unsafe fault does not grant the optimizer permission to invent unrelated behavior.

## 7. Recoverable failure through `status` and `out`

OpenC uses visible ordinary control flow rather than hidden exceptions or wrapper-heavy declarations.

```c
i32 value;
status result = parse(out value);

if !result.ok {
    return result.code;
}

use(value);
```

`status.ok` is derived from `status.code == 0`. An out call establishes compiler-only proof lineage: success publishes every output; failure publishes none. This makes partial output publication unrepresentable and integrates failure handling with definite initialization.

## 8. Explicit ownership and resources

Resource values are non-copyable and carry exactly-once obligations. Ownership movement is domain-specific rather than expressed through a generic `move(value)` operation.

Resource construction is transactional. Ownership sources are reserved while field expressions are evaluated and move only at one non-failing commit point. Before commit, failure leaves every source owner unchanged. This prevents half-moved resources and hidden rollback destructors.

## 9. No-fail structured cleanup

A `scope` action is registered near the obligation it discharges and runs in deterministic reverse order on every structured exit.

```c
Buffer buffer = buffer_create(size);
scope buffer_destroy(buffer);
```

Only statically no-fail `void` cleanup targets are eligible. Fallible `finish`, `flush`, or `commit` operations remain explicit ordinary status-handling steps. A separate no-fail release or discard operation performs obligation discharge. This avoids hidden cleanup-failure precedence, aggregation, or loss.

Unsafe target faults are outside the structured cleanup guarantee because the target may physically prevent continued execution.

## 10. Borrowing, storage, and raw pointers

Safe references and slices are non-null, non-owning, lifetime-checked views. Mutable access follows the ordinary exclusivity rule: many read borrows or one write borrow.

Typed storage is not an object. `construct` accepts an exact typed value, begins one object lifetime only after complete preparation, and is valid only while initializing one new stable mutable local reference. `destroy` ends that lifetime and invalidates dependent references and typed pointer use.

Raw pointers carry an abstract origin, extent, offset, lifetime generation, type, and constness. A backend may erase this metadata only when static proof or target instrumentation preserves the specified semantics. Pointer arithmetic cannot manufacture new provenance.

## 11. Exact numeric behavior

Fixed-width integers have stable widths and representations. Ordinary integer arithmetic is checked. Wrapping and saturating behavior are named explicitly. Core uses a closed safe intrinsic set for wrapping and saturating arithmetic. A redundant general unchecked-arithmetic family is deliberately absent; narrowly defined `cast_unchecked` remains an unsafe integer-conversion operation.

Floating types use fixed binary formats and defined rounding. Compile-time evaluation follows the same representational and failure rules as runtime evaluation.

## 12. Logical modules, not textual inclusion

Project context assigns source units to logical modules. Imports are source-unit local; declarations assigned to one module form one order-independent declaration set. Filesystem layout and source extensions are tooling policy, not source-language semantics.

Core rejects import cycles for the first release candidate. This keeps initialization, visibility, and dependency behavior simple enough to implement and audit.

## 13. Text, bytes, arrays, and slices

`text` is an immutable sequence of Unicode scalar values. Its `.length` counts scalars. Direct numeric indexing and ambiguous byte access are absent from Core. Encoding conversions belong to explicit Hosted or library contracts.

Fixed arrays are bounded values whose length is part of the type. Slices are bounded non-owning views carrying provenance, lifetime, length, and mutability. Neither silently decays into a raw pointer.

## 14. Optional values and aggregates

Absence is written `optional T`, not `T?` or an implicit null state. `.present` refines flow; `.value` is checked unless presence is proven.

Plain structs use named initialization, explicit defaults, recursive value copy, and recursive equality. Resource-bearing fields are prohibited in ordinary structs so ownership obligations cannot hide inside apparently copyable values.

## 15. Functions and overloads

Functions retain direct return-type-first declarations. Parameters and return types remain explicit. Overload resolution prefers one exact match; otherwise it accepts only one unique candidate through the finite set of Core lossless implicit conversions. Return type alone never distinguishes overloads.

This avoids hidden conversion-distance rankings and keeps diagnostics reproducible across implementations.

## 16. Target model and portability

Core has one declared target record for pointer width, endianness, object size/alignment, provenance behavior, faults, and implementation limits. Cross-compilation uses target facts, never undeclared host facts.

Ordinary struct layout is target-defined and reportable, but it is not a portable wire or foreign ABI contract. Native interoperability remains a separate candidate specification.

## 17. Diagnostics and conformance

Every normative rule has a stable ID. Diagnostics record phase, category, severity, primary span, related spans, and source trace. Human wording may improve without breaking machine-readable identity.

A parser claim, semantic-checker claim, runtime claim, and complete Core claim are separate. Candidate completion does not imply executed conformance.

## 18. Deliberately outside Core Candidate 2

The following are intentionally separate or deferred:

```text
Hosted I/O, files, paths, process, allocator, and encoding providers
Native ABI/FFI and linker syntax
script and live conveniences
strict and critical assurance policy
threads, atomics, shared state, channels, time, cancellation, and groups
nested arrays and nested optionals
generics, methods, closures, async functions, and coroutines
source-file extension policy
release governance and licensing
```

Exclusion is not a judgment that a feature is useless. It protects a coherent and implementable Core boundary.

## 19. What candidate completion means

Core Candidate 2 is complete as an authored, integrated, structurally checked candidate. It still requires:

```text
owner ratification of candidate decisions
independent grammar review
independent safety and ownership review
complete implementation exercise
execution of the full conformance corpus
real-program usability review
Core 1.0 freeze and release authorization
```

Implementation findings may reopen any candidate rule before freeze.


## 20. Implementation-readiness corrections

The implementation-readiness revision closes defects discovered by an internal adversarial review before external review begins. The most significant corrections are deterministic lexical maximal-munch and word classification, code-point-explicit escape grammar, a normative precedence table, closed switch and loop algorithms, portable source spans, finite address-of and type-query domains, representation-safe byte access, and a closed wrapping/saturating intrinsic set.

These corrections are not feature expansion. They remove implementation guesswork and prevent a compiler from becoming an accidental second specification.
