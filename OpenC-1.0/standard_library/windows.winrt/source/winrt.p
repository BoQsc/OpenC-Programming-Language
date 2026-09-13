import windows.com;

export resource Runtime {
    usize module;
    bool initialized;
}

export resource HString {
    usize value;
    bool owned;
}

external(c, "ocw_winrt_initialize") status win_winrt_initialize_runtime(
    u32 mode, out usize module
);
external(c, "ocw_winrt_uninitialize") void win_winrt_uninitialize_runtime(
    usize module
);
external(c, "ocw_winrt_string_create") status win_winrt_string_create_runtime(
    text value, out usize handle
);
external(c, "ocw_winrt_string_delete") void win_winrt_string_delete_runtime(
    usize handle
);
external(c, "ocw_winrt_activation_factory") status win_winrt_factory_runtime(
    usize class_name, u64 iid_low, u64 iid_high, out ptr byte value
);
external(c, "ocw_winrt_activate_instance") status win_winrt_activate_runtime(
    ptr byte factory, out ptr byte value
);
external(c, "ocw_winrt_runtime_class_name") status win_winrt_class_name_runtime(
    ptr byte value, out usize class_name
);
external(c, "ocw_winrt_trust_level") status win_winrt_trust_level_runtime(
    ptr byte value, out i32 trust_level
);

export com.Guid iid_activation_factory() {
    return com.Guid{
        low = cast(u64, 53), high = cast(u64, 5044031582654955712)
    };
}

export com.Guid iid_inspectable() {
    return com.Guid{
        low = cast(u64, 5506408304190350048),
        high = cast(u64, 10384755819606923932)
    };
}

export status initialize_multithreaded(out Runtime runtime) {
    usize module;
    status initialized = win_winrt_initialize_runtime(1, out module);
    if !initialized.ok { return initialized; }
    runtime = Runtime{ module = module, initialized = true };
    return status{ code = 0 };
}

export status initialize_apartment_threaded(out Runtime runtime) {
    usize module;
    status initialized = win_winrt_initialize_runtime(0, out module);
    if !initialized.ok { return initialized; }
    runtime = Runtime{ module = module, initialized = true };
    return status{ code = 0 };
}

export void runtime_destroy(own Runtime runtime) {
    if runtime.initialized { win_winrt_uninitialize_runtime(runtime.module); }
}

export status string_create(text value, out HString string) {
    usize handle;
    status created = win_winrt_string_create_runtime(
        value, out handle
    );
    if !created.ok { return created; }
    string = HString{ value = handle, owned = true };
    return status{ code = 0 };
}

export bool valid(ref const HString value) { return value.value != 0; }

export void string_destroy(own HString value) {
    if value.owned && valid(value) {
        win_winrt_string_delete_runtime(value.value);
    }
}

export status activation_factory(
    ref const HString class_name,
    com.Guid iid,
    out com.Unknown factory
) {
    if !valid(class_name) { return status{ code = 1 }; }
    ptr byte value;
    status activated = win_winrt_factory_runtime(
        class_name.value, iid.low, iid.high, out value
    );
    if !activated.ok { return activated; }
    factory = com.Unknown{ value = value, owned = true };
    return status{ code = 0 };
}

export status activate_instance(
    ref const com.Unknown factory,
    out com.Unknown value
) {
    if !com.valid(factory) { return status{ code = 1 }; }
    ptr byte activated_value;
    status activated = win_winrt_activate_runtime(
        factory.value, out activated_value
    );
    if !activated.ok { return activated; }
    value = com.Unknown{ value = activated_value, owned = true };
    return status{ code = 0 };
}

export status runtime_class_name(
    ref const com.Unknown value,
    out HString class_name
) {
    if !com.valid(value) { return status{ code = 1 }; }
    usize handle;
    status read = win_winrt_class_name_runtime(value.value, out handle);
    if !read.ok { return read; }
    class_name = HString{ value = handle, owned = true };
    return status{ code = 0 };
}

export status trust_level(
    ref const com.Unknown value,
    out i32 level
) {
    if !com.valid(value) { return status{ code = 1 }; }
    i32 observed;
    status read = win_winrt_trust_level_runtime(value.value, out observed);
    if !read.ok { return read; }
    level = observed;
    return status{ code = 0 };
}
