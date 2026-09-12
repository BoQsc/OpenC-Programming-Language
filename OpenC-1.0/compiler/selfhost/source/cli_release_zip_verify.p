import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

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
