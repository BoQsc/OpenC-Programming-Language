module openc.std.system_memory;

import openc.runtime.memory : opencAlloc, opencCalloc, opencClear, opencCopy, opencFree, opencMove, opencRealloc;
import openc.runtime.types : OpenCByte, usize;

void* alloc(usize size) { return opencAlloc(size); }
void* allocZeroed(usize count, usize size) { return opencCalloc(count, size); }
void* resize(void* pointer, usize size) { return opencRealloc(pointer, size); }
void free(void* pointer) nothrow { opencFree(pointer); }
pragma(inline, true)
usize load_usize(void* pointer) { return *cast(usize*) pointer; }
pragma(inline, true)
void store_usize(void* pointer, usize value) { *cast(usize*) pointer = value; }
void copy(void* destination, const(void)* source, usize count) { opencCopy(destination, source, count); }
void move(void* destination, const(void)* source, usize count) { opencMove(destination, source, count); }
void clear(void* destination, usize count) { opencClear(destination, count); }
