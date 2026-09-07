import windows.foundation;

external(c, "ocw_console_write") status win_console_write_runtime(
    ptr const byte wide, usize units, text utf8, bool standard_error
);

void release_utf16(own foundation.Utf16 value) {
    foundation.utf16_destroy(value);
}

status write_to(text value, bool standard_error) {
    foundation.Utf16 wide;
    status encoded = foundation.encode_utf16(value, out wide);
    if !encoded.ok { return encoded; }
    scope release_utf16(wide);
    return win_console_write_runtime(
        wide.data, wide.units, value, standard_error
    );
}

export status write(text value) { return write_to(value, false); }
export status write_error(text value) { return write_to(value, true); }
