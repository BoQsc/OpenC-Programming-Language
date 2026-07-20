# OpenC Hosted Environment 1.0 — release-candidate baseline

Status: **OWNER-RATIFIED; WINDOWS X86-64 REFERENCE EXECUTION PASS**

This component defines the minimum Hosted environment supplied alongside OpenC Core. It does not alter Core syntax or Core safety rules. A Hosted implementation provides a process entry point, standard console streams, dynamic byte allocation, files, paths, process arguments, and UTF-8 conversion through the modules listed here.

## 1. Conformance identity

A conforming Hosted implementation reports all of:

```text
openc.environment.hosted
openc.library.system.io
openc.library.system.memory
openc.library.system.file
openc.library.system.path
openc.library.system.process
openc.library.system.text
```

A missing module or provider is a visible unsupported-capability diagnostic. Hosted support is not implied by Core conformance.

## 2. Program entry and termination

A Hosted executable contains exactly one selected entry function:

```c
i32 main() {
    return 0;
}
```

The implementation initializes process arguments before calling `main`, converts the returned `i32` to the target process exit status, runs all structured Core cleanup before returning from `main`, and then releases process-provider state.

A checked failure not handled by the program terminates through the declared checked-failure provider. It is not converted into successful exit.

## 3. `system.io`

```c
export void print(text value);
export void println(text value);
export void print(i8 value);
export void print(i16 value);
export void print(i32 value);
export void print(i64 value);
export void print(u8 value);
export void print(u16 value);
export void print(u32 value);
export void print(u64 value);
export void print(isize value);
export void print(usize value);
export void print(bool value);
export void error(text value);
```

`print` emits the exact UTF-8 encoding of a text value or the canonical decimal/boolean representation of a primitive value. `println` appends the target's declared console line ending after the text. `error` writes to the standard diagnostic stream.

Console operations preserve source order within one thread. A provider failure is a defined Hosted provider failure; it does not become undefined behavior.

## 4. `system.memory`

```c
export resource Bytes {
    own ptr byte data;
    usize length;
}

export status allocate(usize size, out Bytes bytes);
export void bytes_destroy(own Bytes bytes);
export void copy(ref Bytes destination, ref const Bytes source, usize count);
export void move(ref Bytes destination, ref const Bytes source, usize count);
export void clear(ref Bytes bytes);
```

`allocate` publishes one `Bytes` owner only on successful status proof. Zero-size allocation yields a valid owner whose length is zero. `bytes_destroy` is no-fail and may be registered with `scope`.

`copy` requires non-overlapping ranges. `move` permits overlap. Both require `count` not to exceed either buffer length; the safe wrappers check this before reaching the native byte operation. `clear` writes zero to every owned byte.

## 5. `system.file`

```c
export resource File {
    ptr byte handle;
    bool open;
}

export status open_read(text path, out File file);
export status open_write(text path, bool truncate, out File file);
export status read_all(ref File file, out memory.Bytes bytes);
export status write_all(ref File file, text value);
export status read_text(text path, out text value);
export status write_text(text path, text value);
export status flush(ref File file);
export void close(own File file);
```

A successful open begins one file ownership obligation. Failure publishes no file. `close` is no-fail and exactly-once; the provider may record a close failure diagnostically but cannot leave a caller-visible owner live.

`read_all` publishes one independently owned byte buffer on success. End of file is successful completion, not an operational failure. `write_all` attempts to write the complete UTF-8 byte sequence. `read_text` and `write_text` are whole-file convenience operations that acquire and close their file internally; `read_text` rejects invalid UTF-8. `flush` is the explicit fallible protocol-completion operation and therefore is not a `scope` cleanup substitute for `close`.

## 6. `system.path`

```c
export status join(text left, text right, out memory.Bytes bytes);
export bool is_absolute(text value);
```

Paths are target path values represented at this boundary as immutable text and encoded to provider-native form explicitly. `join` produces owned UTF-8 bytes containing the target-normalized path representation. It performs no filesystem access. `is_absolute` is purely lexical for the active target.

## 7. `system.process`

```c
export usize argument_count();
export text argument(usize index);
export text current_directory();
```

Arguments are immutable borrowed text values valid for the lifetime of the Hosted process provider. Out-of-range access causes a defined bounds failure. `current_directory` returns an immutable process-provider value; changing the current directory is not part of Hosted 1.0.

## 8. `system.text`

```c
export status decode_utf8(ref const memory.Bytes bytes, out text value);
export status encode_utf8(text value, out memory.Bytes bytes);
export usize length(text value);
export status scalar_at(text value, usize index, out u32 scalar);
export usize byte_length(text value);
export status byte_at(text value, usize index, out u8 byte_value);
export bool equal(text left, text right);
export i32 compare(text left, text right);
```

`decode_utf8` validates the complete input. Failure publishes no text value.
`encode_utf8` publishes an owned byte buffer containing the exact UTF-8
encoding. `length` counts Unicode scalar values, while `byte_length` counts
UTF-8 bytes. `scalar_at` publishes one checked scalar and `byte_at` publishes
one checked UTF-8 byte; each fails without publishing when its index is outside
the text. Byte access does not weaken text validity because every `text` value
remains well-formed UTF-8. `compare` performs deterministic scalar-value
lexicographic ordering and returns a negative, zero, or positive value.

Hosted 1.0 performs no implicit normalization and no locale-sensitive comparison.

## 9. Provider and target obligations

Every Hosted provider reports:

```text
target triple
console encoding and line ending
path model
allocator alignment guarantees
maximum allocation size
file-provider limitations
process argument encoding
```

Cross-compilation uses target providers; it never borrows the build host's console, filesystem, path, or process behavior.

## 10. Evidence boundary

The first-party source implementations live under `standard_library/` and
`runtime/`. The D implementation builds and passes the Windows x86-64 Hosted
tests, runtime fixtures, and maintained-program gate. Other target providers
remain experimental until their own target execution is recorded.
