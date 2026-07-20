# OpenC Native Interface 1.0 — authored current baseline

Status: **AUTHOR-FINAL FOR SOURCE HANDOFF; INDEPENDENT ABI REVIEW AND EXECUTION PENDING**

The Native component provides an explicit boundary between OpenC and external binary interfaces. It does not provide C source compatibility and does not change Core's safe-by-default model.

## 1. External declarations

The canonical form is:

```c
external(c, "symbol_name") i32 native_function(i32 value);
```

An external function has no OpenC body. The first argument names the calling convention; the second is the exact external symbol. `c` identifies the target's declared C ABI, not ISO C source semantics.

An external operation whose contract cannot be made safe by its signature is declared `unsafe`:

```c
external(c, "native_copy") unsafe void native_copy(
    ptr byte destination,
    ptr const byte source,
    usize count
);
```

Calls to unsafe external functions require an `unsafe` region.

## 2. Layout declarations

```c
layout(c) struct NativePoint {
    i32 x;
    i32 y;
}
```

`layout(c)` requests the target C ABI layout for eligible fields. It is not valid for resources, references, slices, optionals, storage values, or fields with hidden ownership obligations.

The implementation records size, alignment, field offsets, target ABI identity, and compiler/provider identity in the build record.

## 3. Eligible boundary values

The portable Native 1.0 boundary permits:

```text
fixed-width integers
isize and usize under a pinned target
f32 and f64
bool only when the ABI mapping is declared
ptr T and ptr const T
layout(c) plain structs
plain enums with an explicit fixed-width base
void
```

Core `text`, slices, optionals, status values, resources, safe references, and ordinary OpenC structs do not cross the boundary without an explicit adapter.

## 4. Ownership and lifetime

A raw pointer parameter is non-owning unless the external declaration is paired with a documented ownership contract. OpenC ownership cannot be transferred implicitly across the boundary.

External allocation and release functions must be wrapped by domain-specific OpenC resource APIs that state:

```text
who allocates
who releases
which allocator family applies
alignment and extent
failure behavior
whether null is permitted
whether ownership transfers
```

A safe wrapper checks all preconditions it can enforce. If a caller must uphold a memory-safety condition, the wrapper remains unsafe.

## 5. Text and strings

Native text interoperation uses explicit encoded byte buffers. No implicit conversion exists between OpenC `text` and `char *`, UTF-16, platform strings, or null-terminated storage.

Adapters must define encoding, terminator, embedded-null behavior, length, ownership, and lifetime.

## 6. Unwinding and callbacks

Foreign unwinding may not cross an OpenC frame in Native 1.0. External exceptions, long jumps, and equivalent nonlocal control transfers must be contained by a foreign adapter.

General callbacks and first-class function values are outside Native 1.0. A future proposal may add them only with explicit lifetime, calling-convention, thread, and failure contracts.

## 7. Linking

Link inputs are project/build context, not source pragmas. A project declares external objects, static or dynamic libraries, search paths, framework/provider identifiers, and integrity records.

Source code cannot silently add arbitrary linker flags.

## 8. Evidence boundary

The parser and backends contain authored Native support. Native conformance requires real target ABI tests on every claimed target and independent ABI review. None is claimed executed by this source package.
