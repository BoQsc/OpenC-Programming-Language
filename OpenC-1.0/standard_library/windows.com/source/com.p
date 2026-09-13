export struct Guid {
    u64 low;
    u64 high;
}

export struct HResult {
    i32 value;
}

export resource Apartment {
    usize module;
    bool initialized;
}

export resource Unknown {
    ptr byte value;
    bool owned;
}

external(c, "ocw_com_initialize") status win_com_initialize_runtime(
    u32 mode, out usize module
);
external(c, "ocw_com_uninitialize") void win_com_uninitialize_runtime(
    usize module
);
external(c, "ocw_com_create_stream") status win_com_create_stream_runtime(
    out ptr byte value
);
external(c, "ocw_com_query_interface") status win_com_query_runtime(
    ptr byte value, u64 iid_low, u64 iid_high, out ptr byte result
);
external(c, "ocw_com_add_ref") u32 win_com_add_ref_runtime(ptr byte value);
external(c, "ocw_com_release") u32 win_com_release_runtime(ptr byte value);

export Guid guid(u32 data1, u16 data2, u16 data3, u64 data4) {
    u64 low = cast(u64, data1) |
        (cast(u64, data2) << cast(usize, 32)) |
        (cast(u64, data3) << cast(usize, 48));
    return Guid{ low = low, high = data4 };
}

export Guid iid_unknown() {
    return Guid{
        low = cast(u64, 0), high = cast(u64, 5044031582654955712)
    };
}

export HResult hresult(i32 value) { return HResult{ value = value }; }
export bool succeeded(HResult value) { return value.value >= 0; }
export bool failed(HResult value) { return value.value < 0; }

export status as_status(HResult value) {
    if failed(value) { return status{ code = 1 }; }
    return status{ code = 0 };
}

export status initialize_multithreaded(out Apartment apartment) {
    usize module;
    status initialized = win_com_initialize_runtime(0, out module);
    if !initialized.ok { return initialized; }
    apartment = Apartment{ module = module, initialized = true };
    return status{ code = 0 };
}

export status initialize_apartment_threaded(out Apartment apartment) {
    usize module;
    status initialized = win_com_initialize_runtime(2, out module);
    if !initialized.ok { return initialized; }
    apartment = Apartment{ module = module, initialized = true };
    return status{ code = 0 };
}

export void apartment_destroy(own Apartment apartment) {
    if apartment.initialized { win_com_uninitialize_runtime(apartment.module); }
}

export bool valid(ref const Unknown value) {
    return value.owned;
}

export status memory_stream(
    ref const Apartment apartment,
    out Unknown stream
) {
    if !apartment.initialized { return status{ code = 1 }; }
    ptr byte value;
    status created = win_com_create_stream_runtime(out value);
    if !created.ok { return created; }
    stream = Unknown{ value = value, owned = true };
    return status{ code = 0 };
}

export status query_interface(
    ref const Unknown source,
    Guid iid,
    out Unknown result
) {
    if !valid(source) { return status{ code = 1 }; }
    ptr byte value;
    status queried = win_com_query_runtime(
        source.value, iid.low, iid.high, out value
    );
    if !queried.ok { return queried; }
    result = Unknown{ value = value, owned = true };
    return status{ code = 0 };
}

export u32 retain(ref const Unknown value) {
    if !valid(value) { return 0; }
    return win_com_add_ref_runtime(value.value);
}

export u32 reference_count(ref const Unknown value) {
    if !valid(value) { return 0; }
    win_com_add_ref_runtime(value.value);
    return win_com_release_runtime(value.value);
}

export status clone(ref const Unknown source, out Unknown result) {
    if !valid(source) { return status{ code = 1 }; }
    win_com_add_ref_runtime(source.value);
    result = Unknown{ value = source.value, owned = true };
    return status{ code = 0 };
}

export void unknown_destroy(own Unknown value) {
    if value.owned && valid(value) { win_com_release_runtime(value.value); }
}
