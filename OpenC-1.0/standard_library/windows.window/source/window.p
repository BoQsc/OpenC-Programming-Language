import windows.foundation;
import windows.raw.window;

export struct Window { usize value; }

external(c, "ocw_window_desktop") status win_window_desktop_runtime(out usize window);
external(c, "ocw_window_valid") bool win_window_valid_runtime(usize window);
external(c, "ocw_window_title") status win_window_title_runtime(
    usize window, out own ptr byte data, out usize length
);
external(c, "ocw_message_box") status win_window_message_runtime(
    usize owner, ptr const byte message, ptr const byte title,
    u32 flags, out i32 selection
);

void release_utf16(own foundation.Utf16 value) {
    foundation.utf16_destroy(value);
}

export status desktop(out Window window) {
    usize value;
    status result = win_window_desktop_runtime(out value);
    if !result.ok { return result; }
    window = Window{ value = value };
    return status{ code = 0 };
}

export bool valid(Window window) {
    return win_window_valid_runtime(window.value);
}

export status title(Window window, out foundation.OwnedText value) {
    usize handle = window.value;
    ptr byte data;
    usize length;
    status result = win_window_title_runtime(
        handle, out data, out length
    );
    if !result.ok { return result; }
    value = foundation.OwnedText{ own data = data, length = length };
    return status{ code = 0 };
}

export status message_box(
    Window owner, text message, text title_text, u32 flags, out i32 selection
) {
    foundation.Utf16 wide_message;
    status encoded_message = foundation.encode_utf16(message, out wide_message);
    if !encoded_message.ok { return encoded_message; }
    scope release_utf16(wide_message);
    foundation.Utf16 wide_title;
    status encoded_title = foundation.encode_utf16(title_text, out wide_title);
    if !encoded_title.ok { return encoded_title; }
    scope release_utf16(wide_title);
    status result = win_window_message_runtime(
        owner.value, wide_message.data, wide_title.data, flags, out selection
    );
    if !result.ok { return result; }
    return result;
}
