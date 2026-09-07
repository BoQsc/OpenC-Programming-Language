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
external(c, "ocw_library_close") void win_resources_close_runtime(usize module);

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

export void close(own Library library) {
    if library.open { win_resources_close_runtime(library.value); }
}
