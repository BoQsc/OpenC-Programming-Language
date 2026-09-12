import windows.foundation;

export resource Library {
    usize value;
    bool open;
}

external(c, "ocw_module_path") status win_resources_module_path_runtime(
    out own ptr byte data, out usize length
);
external(c, "ocw_library_load_system") status win_resources_load_runtime(
    ptr const byte name, out usize module
);
external(c, "ocw_library_load_absolute") status win_resources_load_absolute_runtime(
    ptr const byte name, out usize module
);
external(c, "ocw_library_close") void win_resources_close_runtime(usize module);
external(c, "ocw_library_symbol") status win_resources_symbol_runtime(
    usize module, ptr const byte ascii_z_name, out usize address
);
external(c, "ocw_library_call_i32_two") i32 win_resources_call_i32_two_runtime(
    usize address, i32 left, i32 right
);

void release_utf16(own foundation.Utf16 value) {
    foundation.utf16_destroy(value);
}

export status executable_path(out foundation.OwnedText path) {
    ptr byte data;
    usize length;
    status result = win_resources_module_path_runtime(out data, out length);
    if !result.ok { return result; }
    path = foundation.OwnedText{ own data = data, length = length };
    return status{ code = 0 };
}

export status load_system(text name, out Library library) {
    foundation.Utf16 wide;
    status encoded = foundation.encode_utf16(name, out wide);
    if !encoded.ok { return encoded; }
    scope release_utf16(wide);
    usize module;
    status result = win_resources_load_runtime(wide.data, out module);
    if !result.ok { return result; }
    library = Library{ value = module, open = true };
    return status{ code = 0 };
}

export status load_absolute(text path, out Library library) {
    foundation.Utf16 wide;
    status encoded = foundation.encode_utf16(path, out wide);
    if !encoded.ok { return encoded; }
    scope release_utf16(wide);
    usize module;
    status result = win_resources_load_absolute_runtime(
        wide.data, out module
    );
    if !result.ok { return result; }
    library = Library{ value = module, open = true };
    return status{ code = 0 };
}

export void close(own Library library) {
    if library.open { win_resources_close_runtime(library.value); }
}

export unsafe status symbol_ascii_z(
    ref const Library library,
    ptr const byte name,
    out usize address
) {
    if !library.open { return status{ code = 1 }; }
    usize resolved;
    status result = win_resources_symbol_runtime(
        library.value, name, out resolved
    );
    if !result.ok { return result; }
    address = resolved;
    return status{ code = 0 };
}

export unsafe i32 call_i32_two(
    usize address,
    i32 left,
    i32 right
) {
    return win_resources_call_i32_two_runtime(address, left, right);
}
