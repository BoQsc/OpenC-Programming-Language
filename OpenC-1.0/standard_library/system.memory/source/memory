export resource Bytes {
    own ptr byte data;
    usize length;
}

external(c, "oc_memory_allocate") own ptr byte runtime_allocate(usize size, usize alignment);
external(c, "oc_memory_release") void runtime_release(own ptr byte allocation);
external(c, "oc_memory_copy") void runtime_copy(ptr byte destination, ptr const byte source, usize size);
external(c, "oc_memory_move") void runtime_move(ptr byte destination, ptr const byte source, usize size);
external(c, "oc_memory_clear") void runtime_clear(ptr byte destination, usize size);

export status allocate(usize size, out Bytes bytes) {
    ptr byte allocation = runtime_allocate(size, 1);

    bytes = Bytes{
        own data = allocation,
        length = size
    };

    return status{ code = 0 };
}

export void bytes_destroy(own Bytes bytes) {
    runtime_release(bytes.data);
}

export void copy(ref Bytes destination, ref const Bytes source, usize count) {
    if count > destination.length || count > source.length {
        return;
    }

    unsafe {
        runtime_copy(destination.data, source.data, count);
    }
}

export void move(ref Bytes destination, ref const Bytes source, usize count) {
    if count > destination.length || count > source.length {
        return;
    }

    unsafe {
        runtime_move(destination.data, source.data, count);
    }
}

export void clear(ref Bytes bytes) {
    unsafe {
        runtime_clear(bytes.data, bytes.length);
    }
}
