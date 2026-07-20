module openc.runtime.memory;

import openc.runtime.checked : opencCheckedFailure;
import openc.runtime.types : OpenCByte, Status, usize;
import core.stdc.stdlib : calloc, free, malloc, realloc;
import core.stdc.string : memcpy, memmove, memset;

extern(C) void* opencAlloc(usize size) {
    if (size == 0) size = 1;
    auto pointer = malloc(size);
    if (pointer is null) opencCheckedFailure("memory allocation failed");
    return pointer;
}

extern(C) void* opencCalloc(usize count, usize size) {
    if (count == 0 || size == 0) return opencAlloc(1);
    auto pointer = calloc(count, size);
    if (pointer is null) opencCheckedFailure("zeroed memory allocation failed");
    return pointer;
}

extern(C) void* opencRealloc(void* pointer, usize size) {
    if (pointer is null) return opencAlloc(size);
    if (size == 0) size = 1;
    auto result = realloc(pointer, size);
    if (result is null) opencCheckedFailure("memory reallocation failed");
    return result;
}

extern(C) void opencFree(void* pointer) nothrow {
    if (pointer !is null) free(pointer);
}

extern(C) void opencCopy(void* destination, const(void)* source, usize count) {
    if (count && (destination is null || source is null)) opencCheckedFailure("memory copy uses null pointer");
    memcpy(destination, source, count);
}

extern(C) void opencMove(void* destination, const(void)* source, usize count) {
    if (count && (destination is null || source is null)) opencCheckedFailure("memory move uses null pointer");
    memmove(destination, source, count);
}

extern(C) void opencClear(void* destination, usize count) {
    if (count && destination is null) opencCheckedFailure("memory clear uses null pointer");
    memset(destination, 0, count);
}
