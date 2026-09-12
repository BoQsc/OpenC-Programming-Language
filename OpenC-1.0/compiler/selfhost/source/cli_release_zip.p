import system.file;
import system.memory;
import system.path;
import system.text;

struct CliZipWriter {
    text archive_path;
    text root_name;
    usize offset;
    usize entries;
    usize input_bytes;
    usize peak_entry_bytes;
    bool first_piece;
    bool ok;
    DBuffer central;
    DBuffer manifest;
}

unsafe status cli_file_append_bytes(
    text output,
    ptr const byte data,
    usize length
) {
    return file.write_bytes(output, data, length);
}

unsafe status cli_file_create_directory(text directory) {
    return status{ code = 1 };
}

unsafe bool cli_release_ensure_directory(text directory) {
    usize length = text.byte_length(directory);
    if length == 0 { return true; }
    DBuffer prefix = d_buffer_create(length + 1);
    bool ok = true;
    usize index = 0;
    while ok && index < length {
        u8 value = byte_at_or_zero(directory, index);
        d_put_byte(prefix, value);
        if (value == 47 || value == 92) && prefix.length > 3 {
            cli_file_create_directory(d_buffer_text(prefix));
        }
        index = index + 1;
    }
    if ok {
        cli_file_create_directory(d_buffer_text(prefix));
    }
    d_buffer_destroy(prefix);
    return ok;
}

unsafe void cli_zip_put_u16(ref DBuffer output, usize value) {
    d_put_byte(output, cast(u8, value & 255));
    d_put_byte(output, cast(u8, (value >> 8) & 255));
}

unsafe void cli_zip_put_u32(ref DBuffer output, usize value) {
    usize index = 0;
    while index < 4 {
        d_put_byte(output, cast(u8, (value >> (index * 8)) & 255));
        index = index + 1;
    }
}

unsafe usize cli_zip_read_u16(
    ptr byte data,
    usize length,
    usize offset,
    ref bool valid
) {
    if offset > length || length - offset < 2 {
        valid = false;
        return 0;
    }
    return cast(usize, cast(u8, *(data + offset))) |
        (cast(usize, cast(u8, *(data + offset + 1))) << 8);
}

unsafe usize cli_zip_read_u32(
    ptr byte data,
    usize length,
    usize offset,
    ref bool valid
) {
    if offset > length || length - offset < 4 {
        valid = false;
        return 0;
    }
    usize value = 0;
    usize index = 0;
    while index < 4 {
        value = value |
            (cast(usize, cast(u8, *(data + offset + index))) << (index * 8));
        index = index + 1;
    }
    return value;
}

unsafe usize cli_zip_crc32(ptr byte data, usize length) {
    usize crc = 4294967295;
    usize index = 0;
    while index < length {
        crc = crc ^ cast(usize, cast(u8, *(data + index)));
        usize bit = 0;
        while bit < 8 {
            if (crc & 1) != 0 {
                crc = (crc >> 1) ^ 3988292384;
            } else {
                crc = crc >> 1;
            }
            bit = bit + 1;
        }
        index = index + 1;
    }
    return (~crc) & 4294967295;
}

unsafe bool cli_zip_bytes_equal(
    ptr byte left,
    ptr byte right,
    usize length
) {
    usize index = 0;
    while index < length {
        if cast(u8, *(left + index)) != cast(u8, *(right + index)) {
            return false;
        }
        index = index + 1;
    }
    return true;
}

unsafe bool cli_zip_safe_name(text name, text root_name) {
    usize root_length = text.byte_length(root_name);
    usize length = text.byte_length(name);
    if length <= root_length + 1 ||
        !span_equals_ascii(name, 0, root_length, root_name) ||
        byte_at_or_zero(name, root_length) != 47 ||
        byte_at_or_zero(name, 0) == 47 ||
        native_contains(name, "../") || native_contains(name, "..\\") ||
        native_contains(name, ":") || native_contains(name, "\\") {
        return false;
    }
    return true;
}

unsafe bool cli_zip_write_piece(
    ref CliZipWriter writer,
    ptr byte data,
    usize length
) {
    if !writer.ok { return false; }
    status written = status{ code = 1 };
    if writer.first_piece {
        written = file.write_bytes(writer.archive_path, data, length);
        writer.first_piece = false;
    } else {
        written = cli_file_append_bytes(writer.archive_path, data, length);
    }
    writer.ok = written.ok;
    if written.ok { writer.offset = writer.offset + length; }
    return written.ok;
}

unsafe void cli_zip_manifest_line(
    ref CliZipWriter writer,
    text entry_name,
    ptr byte data,
    usize length
) {
    DBuffer hash = d_buffer_create(65);
    winmd_sha256_hex(data, length, hash);
    d_put(writer.manifest, d_buffer_text(hash));
    d_put(writer.manifest, "  ");
    d_put(writer.manifest, entry_name);
    d_put(writer.manifest, "\n");
    if !hash.ok || !writer.manifest.ok { writer.ok = false; }
    d_buffer_destroy(hash);
}
