import system.text;
import windows.raw.foundation;

export resource Utf16 {
    own ptr byte data;
    usize units;
}

export resource OwnedText {
    own ptr byte data;
    usize length;
}

external(c, "ocw_utf16_encode") status win_foundation_encode_runtime(
    text value, out own ptr byte data, out usize units
);
external(c, "ocw_utf16_decode") status win_foundation_decode_runtime(
    ptr const byte data, usize units,
    out own ptr byte utf8_data, out usize utf8_length
);
external(c, "ocw_buffer_free") void win_foundation_free_runtime(ptr byte data);
external(c, "ocw_last_error") u32 win_foundation_last_error_runtime();
external(c, "ocw_format_error") status win_foundation_format_error_runtime(
    u32 code, out own ptr byte data, out usize length
);
external(c, "ocw_text_view") unsafe text win_foundation_view_runtime(
    ptr byte data, usize length
);

export status encode_utf16(text value, out Utf16 encoded) {
    ptr byte data;
    usize units;
    status result = win_foundation_encode_runtime(value, out data, out units);
    if !result.ok { return result; }
    encoded = Utf16{ own data = data, units = units };
    return status{ code = 0 };
}

export status decode_utf16(ref const Utf16 value, out OwnedText decoded) {
    ptr byte data;
    usize length;
    status result = win_foundation_decode_runtime(
        value.data, value.units, out data, out length
    );
    if !result.ok { return result; }
    decoded = OwnedText{ own data = data, length = length };
    return status{ code = 0 };
}

export status format_error(u32 code, out OwnedText message) {
    ptr byte data;
    usize length;
    status result = win_foundation_format_error_runtime(
        code, out data, out length
    );
    if !result.ok { return result; }
    message = OwnedText{ own data = data, length = length };
    return status{ code = 0 };
}

export u32 last_error() {
    return win_foundation_last_error_runtime();
}

export unsafe text view(ref const OwnedText value) {
    return win_foundation_view_runtime(value.data, value.length);
}

export void utf16_destroy(own Utf16 value) {
    win_foundation_free_runtime(value.data);
}

export void text_destroy(own OwnedText value) {
    win_foundation_free_runtime(value.data);
}
