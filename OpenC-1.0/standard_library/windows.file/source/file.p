import system.text;
import windows.foundation;
import windows.raw.file;

export resource File {
    usize value;
    bool open;
}

export resource Bytes {
    own ptr byte data;
    usize length;
}

export struct OpenOptions {
    bool write;
    bool create;
    bool truncate;
    bool exclusive;
}

external(c, "ocw_file_open") status win_file_open_runtime(
    ptr const byte path, bool write, bool create, bool truncate,
    bool exclusive, out usize handle
);
external(c, "ocw_file_read") status win_file_read_runtime(
    usize handle, out own ptr byte data, out usize length
);
external(c, "ocw_file_write") status win_file_write_runtime(
    usize handle, ptr const byte data, usize length
);
external(c, "ocw_file_write_text") status win_file_write_text_runtime(
    usize handle, text value
);
external(c, "ocw_file_write_byte") status win_file_write_byte_runtime(
    usize handle, byte value
);
external(c, "ocw_file_flush") status win_file_flush_runtime(usize handle);
external(c, "ocw_file_remove") status win_file_remove_runtime(ptr const byte path);
external(c, "ocw_close_handle") void win_file_close_runtime(usize handle);
external(c, "ocw_buffer_free") void win_file_buffer_free_runtime(ptr byte data);

void release_utf16(own foundation.Utf16 value) {
    foundation.utf16_destroy(value);
}

export OpenOptions read_options() {
    return OpenOptions{ write = false, create = false, truncate = false, exclusive = false };
}

export OpenOptions create_options() {
    return OpenOptions{ write = true, create = true, truncate = false, exclusive = true };
}

export OpenOptions replace_options() {
    return OpenOptions{ write = true, create = true, truncate = true, exclusive = false };
}

export status open(text path, OpenOptions options, out File file) {
    foundation.Utf16 wide;
    status encoded = foundation.encode_utf16(path, out wide);
    if !encoded.ok { return encoded; }
    scope release_utf16(wide);
    usize handle;
    status opened = win_file_open_runtime(
        wide.data, options.write, options.create, options.truncate,
        options.exclusive, out handle
    );
    if !opened.ok { return opened; }
    file = File{ value = handle, open = true };
    return status{ code = 0 };
}

export status open_read(text path, out File file) {
    OpenOptions options = read_options();
    status result = open(path, options, out file);
    if !result.ok { return result; }
    return result;
}

export status create_new(text path, out File file) {
    OpenOptions options = create_options();
    status result = open(path, options, out file);
    if !result.ok { return result; }
    return result;
}

export status replace(text path, out File file) {
    OpenOptions options = replace_options();
    status result = open(path, options, out file);
    if !result.ok { return result; }
    return result;
}

export status read_bytes(ref File file, out Bytes bytes) {
    ptr byte data;
    usize length;
    status read = win_file_read_runtime(file.value, out data, out length);
    if !read.ok { return read; }
    bytes = Bytes{ own data = data, length = length };
    return status{ code = 0 };
}

export status read_text(ref File file, out foundation.OwnedText value) {
    ptr byte data;
    usize length;
    status read = win_file_read_runtime(file.value, out data, out length);
    if !read.ok { return read; }
    value = foundation.OwnedText{ own data = data, length = length };
    return status{ code = 0 };
}

export status write_bytes(ref File file, const byte[] data) {
    for usize index = 0; index < data.length; index += 1 {
        byte value = data[index];
        status written = win_file_write_byte_runtime(file.value, value);
        if !written.ok { return written; }
    }
    return status{ code = 0 };
}

export status write_text(ref File file, text value) {
    return win_file_write_text_runtime(file.value, value);
}

export status flush(ref File file) {
    return win_file_flush_runtime(file.value);
}

export status remove(text path) {
    foundation.Utf16 wide;
    status encoded = foundation.encode_utf16(path, out wide);
    if !encoded.ok { return encoded; }
    scope release_utf16(wide);
    return win_file_remove_runtime(wide.data);
}

export void close(own File file) {
    if file.open { win_file_close_runtime(file.value); }
}

export void bytes_destroy(own Bytes bytes) {
    win_file_buffer_free_runtime(bytes.data);
}
