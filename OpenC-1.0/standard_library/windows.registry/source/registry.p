import windows.foundation;

export resource Key {
    usize value;
    bool open;
}

external(c, "ocw_registry_open_current_user") status win_registry_open_runtime(
    ptr const byte subkey, bool write, out usize key
);
external(c, "ocw_registry_read_text") status win_registry_read_runtime(
    usize key, ptr const byte name,
    out own ptr byte data, out usize length
);
external(c, "ocw_registry_close") void win_registry_close_runtime(usize key);

void release_utf16(own foundation.Utf16 value) {
    foundation.utf16_destroy(value);
}

export status open_current_user(text subkey, bool write, out Key key) {
    foundation.Utf16 wide;
    status encoded = foundation.encode_utf16(subkey, out wide);
    if !encoded.ok { return encoded; }
    scope release_utf16(wide);
    usize value;
    status result = win_registry_open_runtime(wide.data, write, out value);
    if !result.ok { return result; }
    key = Key{ value = value, open = true };
    return status{ code = 0 };
}

export status read_text(
    ref Key key, text name, out foundation.OwnedText value
) {
    foundation.Utf16 wide;
    status encoded = foundation.encode_utf16(name, out wide);
    if !encoded.ok { return encoded; }
    scope release_utf16(wide);
    ptr byte data;
    usize length;
    status result = win_registry_read_runtime(
        key.value, wide.data, out data, out length
    );
    if !result.ok { return result; }
    value = foundation.OwnedText{ own data = data, length = length };
    return status{ code = 0 };
}

export void close(own Key key) {
    if key.open { win_registry_close_runtime(key.value); }
}
