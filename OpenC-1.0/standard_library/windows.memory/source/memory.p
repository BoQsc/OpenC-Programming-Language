import windows.raw.memory;

export resource Heap {
    usize value;
    bool owned;
}

export resource Block {
    usize heap;
    own ptr byte data;
    usize length;
}

external(c, "ocw_heap_create") status win_memory_heap_create_runtime(out usize heap);
external(c, "ocw_process_heap") usize win_memory_process_heap_runtime();
external(c, "ocw_heap_allocate") status win_memory_allocate_runtime(
    usize heap, usize length, out own ptr byte data
);
external(c, "ocw_heap_resize") status win_memory_resize_runtime(
    usize heap, own ptr byte data, usize length, out own ptr byte resized
);
external(c, "ocw_heap_free") void win_memory_free_runtime(
    usize heap, ptr byte data
);
external(c, "ocw_heap_destroy") void win_memory_heap_destroy_runtime(usize heap);

export status create(out Heap heap) {
    usize value;
    status result = win_memory_heap_create_runtime(out value);
    if !result.ok { return result; }
    heap = Heap{ value = value, owned = true };
    return status{ code = 0 };
}

export Heap process_heap() {
    return Heap{ value = win_memory_process_heap_runtime(), owned = false };
}

export status allocate(ref Heap heap, usize length, out Block block) {
    ptr byte data;
    status result = win_memory_allocate_runtime(heap.value, length, out data);
    if !result.ok { return result; }
    block = Block{ heap = heap.value, own data = data, length = length };
    return status{ code = 0 };
}

export status resize(own Block block, usize length, out Block resized) {
    usize heap = block.heap;
    ptr byte data;
    status result = win_memory_resize_runtime(
        heap, block.data, length, out data
    );
    if !result.ok { return result; }
    resized = Block{ heap = heap, own data = data, length = length };
    return status{ code = 0 };
}

export void block_destroy(own Block block) {
    win_memory_free_runtime(block.heap, block.data);
}

export void heap_destroy(own Heap heap) {
    if heap.owned { win_memory_heap_destroy_runtime(heap.value); }
}
