import system.memory;
import system.text;

export resource File {
    ptr byte handle;
    bool open;
}

external(c, "oc_file_open_read") status runtime_open_read(text path, out File file);
external(c, "oc_file_open_write") status runtime_open_write(text path, bool truncate, out File file);
external(c, "oc_file_read_all") status runtime_read_all(ref File file, out memory.Bytes bytes);
external(c, "oc_file_write_all") status runtime_write_all(ref File file, text value);
external(c, "oc_file_flush") status runtime_flush(ref File file);
external(c, "oc_file_close") void runtime_close(own File file);

export status open_read(text path, out File file) {
    return runtime_open_read(path, out file);
}

export status open_write(text path, bool truncate, out File file) {
    return runtime_open_write(path, truncate, out file);
}

export status read_all(ref File file, out memory.Bytes bytes) {
    return runtime_read_all(file, out bytes);
}

export status write_all(ref File file, text value) {
    return runtime_write_all(file, value);
}

export status read_text(text path, out text value) {
    File file;
    status opened = open_read(path, out file);
    if !opened.ok {
        return opened;
    }
    scope close(file);

    memory.Bytes bytes;
    status read = read_all(ref file, out bytes);
    if !read.ok {
        return read;
    }
    scope memory.bytes_destroy(bytes);
    return text.decode_utf8(ref bytes, out value);
}

export status write_text(text path, text value) {
    File file;
    status opened = open_write(path, true, out file);
    if !opened.ok {
        return opened;
    }
    scope close(file);

    status written = write_all(ref file, value);
    if !written.ok {
        return written;
    }
    return flush(ref file);
}

export status flush(ref File file) {
    return runtime_flush(file);
}

export void close(own File file) {
    runtime_close(file);
}
