import windows.foundation;

external(c, "ocw_shell_local_app_data") status win_shell_local_data_runtime(
    out own ptr byte data, out usize length
);
external(c, "ocw_shell_open") status win_shell_open_runtime(ptr const byte target);

void release_utf16(own foundation.Utf16 value) {
    foundation.utf16_destroy(value);
}

export status local_app_data(out foundation.OwnedText path) {
    ptr byte data;
    usize length;
    status result = win_shell_local_data_runtime(out data, out length);
    if !result.ok { return result; }
    path = foundation.OwnedText{ own data = data, length = length };
    return status{ code = 0 };
}

export status open(text target) {
    foundation.Utf16 wide;
    status encoded = foundation.encode_utf16(target, out wide);
    if !encoded.ok { return encoded; }
    scope release_utf16(wide);
    return win_shell_open_runtime(wide.data);
}
