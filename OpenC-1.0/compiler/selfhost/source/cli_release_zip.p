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

unsafe bool cli_zip_add_data(
    ref CliZipWriter writer,
    text entry_name,
    ptr byte data,
    usize length,
    bool add_to_manifest
) {
    if !writer.ok || length > 16777216 { writer.ok = false; return false; }
    DBuffer full_name = d_buffer_create(
        text.byte_length(writer.root_name) + text.byte_length(entry_name) + 2
    );
    d_put(full_name, writer.root_name);
    d_put(full_name, "/");
    d_put(full_name, entry_name);
    usize name_length = full_name.length;
    if !full_name.ok || name_length > 65535 {
        d_buffer_destroy(full_name);
        writer.ok = false;
        return false;
    }
    usize crc = cli_zip_crc32(data, length);
    usize local_offset = writer.offset;
    DBuffer local = d_buffer_create(30 + name_length);
    cli_zip_put_u32(local, 67324752);
    cli_zip_put_u16(local, 20);
    cli_zip_put_u16(local, 0);
    cli_zip_put_u16(local, 0);
    cli_zip_put_u16(local, 0);
    cli_zip_put_u16(local, 33);
    cli_zip_put_u32(local, crc);
    cli_zip_put_u32(local, length);
    cli_zip_put_u32(local, length);
    cli_zip_put_u16(local, name_length);
    cli_zip_put_u16(local, 0);
    d_put(local, d_buffer_text(full_name));
    bool wrote = local.ok &&
        cli_zip_write_piece(writer, local.data, local.length) &&
        cli_zip_write_piece(writer, data, length);

    cli_zip_put_u32(writer.central, 33639248);
    cli_zip_put_u16(writer.central, 788);
    cli_zip_put_u16(writer.central, 20);
    cli_zip_put_u16(writer.central, 0);
    cli_zip_put_u16(writer.central, 0);
    cli_zip_put_u16(writer.central, 0);
    cli_zip_put_u16(writer.central, 33);
    cli_zip_put_u32(writer.central, crc);
    cli_zip_put_u32(writer.central, length);
    cli_zip_put_u32(writer.central, length);
    cli_zip_put_u16(writer.central, name_length);
    cli_zip_put_u16(writer.central, 0);
    cli_zip_put_u16(writer.central, 0);
    cli_zip_put_u16(writer.central, 0);
    cli_zip_put_u16(writer.central, 0);
    cli_zip_put_u32(writer.central, 2175008768);
    cli_zip_put_u32(writer.central, local_offset);
    d_put(writer.central, d_buffer_text(full_name));
    writer.ok = writer.ok && writer.central.ok && wrote;
    if add_to_manifest {
        cli_zip_manifest_line(writer, entry_name, data, length);
    }
    writer.entries = writer.entries + 1;
    writer.input_bytes = writer.input_bytes + length;
    if length > writer.peak_entry_bytes { writer.peak_entry_bytes = length; }
    d_buffer_destroy(local);
    d_buffer_destroy(full_name);
    return writer.ok;
}

unsafe bool cli_zip_add_file(
    ref CliZipWriter writer,
    text entry_name,
    text source_path,
    bool add_to_manifest
) {
    ptr byte data;
    usize length;
    status loaded = file.read_bytes_raw(source_path, out data, out length);
    if !loaded.ok { writer.ok = false; return false; }
    bool added = cli_zip_add_data(
        writer, entry_name, data, length, add_to_manifest
    );
    memory.free(data);
    return added;
}

unsafe CliZipWriter cli_zip_writer_create(
    text archive_path,
    text root_name,
    bool manifest_enabled
) {
    usize manifest_capacity = 1;
    if manifest_enabled { manifest_capacity = 524288; }
    return CliZipWriter{
        archive_path = archive_path,
        root_name = root_name,
        offset = 0,
        entries = 0,
        input_bytes = 0,
        peak_entry_bytes = 0,
        first_piece = true,
        ok = true,
        central = d_buffer_create(2097152),
        manifest = d_buffer_create(manifest_capacity)
    };
}

unsafe bool cli_zip_writer_finish(ref CliZipWriter writer) {
    usize central_offset = writer.offset;
    bool wrote = cli_zip_write_piece(
        writer, writer.central.data, writer.central.length
    );
    usize central_length = writer.central.length;
    DBuffer end = d_buffer_create(22);
    cli_zip_put_u32(end, 101010256);
    cli_zip_put_u16(end, 0);
    cli_zip_put_u16(end, 0);
    cli_zip_put_u16(end, writer.entries);
    cli_zip_put_u16(end, writer.entries);
    cli_zip_put_u32(end, central_length);
    cli_zip_put_u32(end, central_offset);
    cli_zip_put_u16(end, 0);
    wrote = wrote && end.ok &&
        cli_zip_write_piece(writer, end.data, end.length);
    d_buffer_destroy(end);
    return wrote && writer.ok && writer.entries != 0;
}

unsafe void cli_zip_writer_destroy(ref CliZipWriter writer) {
    d_buffer_destroy(writer.manifest);
    d_buffer_destroy(writer.central);
}

unsafe bool cli_zip_verify_extract(
    text archive_path,
    text root_name,
    text extraction_root,
    bool extract,
    usize expected_entries,
    ref usize archive_bytes,
    ref usize entries,
    ref usize peak_entry_bytes
) {
    ptr byte data;
    usize length;
    status loaded = file.read_bytes_raw(archive_path, out data, out length);
    if !loaded.ok { return false; }
    if length == 0 || length > 67108864 {
        memory.free(data);
        return false;
    }
    archive_bytes = length;
    usize entry_count = 0;
    usize peak_entry = 0;
    bool valid = true;
    usize cursor = 0;
    usize central_offset = 0;
    text previous = "";
    while valid && cursor + 4 <= length &&
        cli_zip_read_u32(data, length, cursor, valid) == 67324752 {
        usize flags = cli_zip_read_u16(data, length, cursor + 6, valid);
        usize method = cli_zip_read_u16(data, length, cursor + 8, valid);
        usize crc = cli_zip_read_u32(data, length, cursor + 14, valid);
        usize compressed = cli_zip_read_u32(data, length, cursor + 18, valid);
        usize uncompressed = cli_zip_read_u32(data, length, cursor + 22, valid);
        usize name_length = cli_zip_read_u16(data, length, cursor + 26, valid);
        usize extra_length = cli_zip_read_u16(data, length, cursor + 28, valid);
        usize name_offset = cursor + 30;
        usize payload = name_offset + name_length + extra_length;
        if !valid || flags != 0 || method != 0 || compressed != uncompressed ||
            uncompressed > 16777216 || name_offset > length ||
            name_length > length - name_offset || payload > length ||
            compressed > length - payload {
            valid = false;
        } else {
            text name = text.from_utf8(data + name_offset, name_length);
            if !cli_zip_safe_name(name, root_name) || name == previous ||
                cli_zip_crc32(data + payload, compressed) != crc {
                valid = false;
            } else {
                previous = name;
                if extract {
                    text destination = path.join(extraction_root, name);
                    if !cli_release_ensure_directory(path.directory(destination)) {
                        valid = false;
                    } else {
                        status written = file.write_bytes(
                            destination, data + payload, compressed
                        );
                        valid = written.ok;
                    }
                }
                entry_count = entry_count + 1;
                if compressed > peak_entry {
                    peak_entry = compressed;
                }
                cursor = payload + compressed;
            }
        }
    }
    central_offset = cursor;
    usize central_entries = 0;
    while valid && central_entries < entry_count {
        if cli_zip_read_u32(data, length, cursor, valid) != 33639248 {
            valid = false;
        } else {
            usize method = cli_zip_read_u16(data, length, cursor + 10, valid);
            usize crc = cli_zip_read_u32(data, length, cursor + 16, valid);
            usize size = cli_zip_read_u32(data, length, cursor + 20, valid);
            usize unpacked = cli_zip_read_u32(data, length, cursor + 24, valid);
            usize name_length = cli_zip_read_u16(data, length, cursor + 28, valid);
            usize extra = cli_zip_read_u16(data, length, cursor + 30, valid);
            usize comment = cli_zip_read_u16(data, length, cursor + 32, valid);
            usize local = cli_zip_read_u32(data, length, cursor + 42, valid);
            usize name_offset = cursor + 46;
            usize next = name_offset + name_length + extra + comment;
            usize local_crc = cli_zip_read_u32(data, length, local + 14, valid);
            usize local_size = cli_zip_read_u32(data, length, local + 18, valid);
            usize local_name_length = cli_zip_read_u16(
                data, length, local + 26, valid
            );
            if !valid || method != 0 || size != unpacked || crc != local_crc ||
                size != local_size || name_length != local_name_length ||
                name_offset > length || name_length > length - name_offset ||
                local + 30 > length || name_length > length - local - 30 ||
                !cli_zip_bytes_equal(
                    data + name_offset, data + local + 30, name_length
                ) || next > length {
                valid = false;
            } else {
                cursor = next;
                central_entries = central_entries + 1;
            }
        }
    }
    usize central_length = cursor - central_offset;
    if valid {
        usize signature = cli_zip_read_u32(data, length, cursor, valid);
        usize disk_entries = cli_zip_read_u16(data, length, cursor + 8, valid);
        usize total_entries = cli_zip_read_u16(data, length, cursor + 10, valid);
        usize recorded_central_length = cli_zip_read_u32(
            data, length, cursor + 12, valid
        );
        usize recorded_central_offset = cli_zip_read_u32(
            data, length, cursor + 16, valid
        );
        usize comment = cli_zip_read_u16(data, length, cursor + 20, valid);
        valid = valid && signature == 101010256 && disk_entries == entry_count &&
            total_entries == entry_count && recorded_central_length == central_length &&
            recorded_central_offset == central_offset && comment == 0 &&
            cursor + 22 == length && entry_count == expected_entries;
    }
    entries = entry_count;
    peak_entry_bytes = peak_entry;
    memory.free(data);
    return valid;
}

unsafe bool cli_release_files_equal(text left_path, text right_path) {
    ptr byte left;
    usize left_length;
    status left_loaded = file.read_bytes_raw(
        left_path, out left, out left_length
    );
    if !left_loaded.ok { return false; }
    if left_length > 67108864 {
        memory.free(left);
        return false;
    }
    ptr byte right;
    usize right_length;
    status right_loaded = file.read_bytes_raw(
        right_path, out right, out right_length
    );
    bool equal = false;
    if right_loaded.ok {
        equal = left_length == right_length &&
            cli_zip_bytes_equal(left, right, left_length);
        memory.free(right);
    }
    memory.free(left);
    return equal;
}
