unsafe usize winmd_u8(ref WinmdReader reader, usize offset) {
    if offset >= reader.length { reader.ok = false; return 0; }
    return cast(usize, cast_unchecked(u8, *(reader.data + offset)));
}

unsafe usize winmd_u16(ref WinmdReader reader, usize offset) {
    return winmd_u8(reader, offset) |
        (winmd_u8(reader, offset + 1) << 8);
}

unsafe usize winmd_u32(ref WinmdReader reader, usize offset) {
    return winmd_u16(reader, offset) |
        (winmd_u16(reader, offset + 2) << 16);
}

unsafe u64 winmd_u64(ref WinmdReader reader, usize offset) {
    return cast(u64, winmd_u32(reader, offset)) |
        (cast(u64, winmd_u32(reader, offset + 4)) << cast(usize, 32));
}

unsafe bool winmd_bytes_equal_ascii(
    ref WinmdReader reader,
    usize offset,
    usize length,
    text expected
) {
    if length != text.byte_length(expected) ||
        offset > reader.length || length > reader.length - offset {
        return false;
    }
    usize cursor = 0;
    while cursor < length {
        if winmd_u8(reader, offset + cursor) != cast(
            usize, byte_at_or_zero(expected, cursor)
        ) { return false; }
        cursor = cursor + 1;
    }
    return true;
}

unsafe usize winmd_rva_to_offset(
    ref WinmdReader reader,
    usize section_headers,
    usize section_count,
    usize rva
) {
    usize section = 0;
    while section < section_count {
        usize at = section_headers + section * 40;
        usize virtual_size = winmd_u32(reader, at + 8);
        usize virtual_address = winmd_u32(reader, at + 12);
        usize raw_size = winmd_u32(reader, at + 16);
        usize raw_pointer = winmd_u32(reader, at + 20);
        usize span = virtual_size;
        if raw_size > span { span = raw_size; }
        if rva >= virtual_address && rva - virtual_address < span {
            usize result = raw_pointer + rva - virtual_address;
            if result < reader.length { return result; }
            reader.ok = false;
            return 0;
        }
        section = section + 1;
    }
    reader.ok = false;
    return 0;
}

unsafe usize winmd_table_count(ref WinmdReader reader, usize table) {
    if table >= 64 { reader.ok = false; return 0; }
    return read_record_field(reader.table_data, table, 0);
}

unsafe usize winmd_table_start(ref WinmdReader reader, usize table) {
    if table >= 64 { reader.ok = false; return 0; }
    return read_record_field(reader.table_data, table, 1);
}

unsafe usize winmd_table_row_size(ref WinmdReader reader, usize table) {
    if table >= 64 { reader.ok = false; return 0; }
    return read_record_field(reader.table_data, table, 2);
}

unsafe usize winmd_simple_index_size(
    ref WinmdReader reader,
    usize table
) {
    if winmd_table_count(reader, table) >= 65536 { return 4; }
    return 2;
}

unsafe usize winmd_coded_limit(usize tag_bits) {
    if tag_bits == 1 { return 32768; }
    if tag_bits == 2 { return 16384; }
    if tag_bits == 3 { return 8192; }
    return 2048;
}

unsafe usize winmd_coded_index_size(
    ref WinmdReader reader,
    usize kind
) {
    usize limit = 0;
    usize maximum = 0;
    if kind == 0 {
        limit = winmd_coded_limit(2);
        maximum = winmd_table_count(reader, 0);
        if winmd_table_count(reader, 26) > maximum { maximum = winmd_table_count(reader, 26); }
        if winmd_table_count(reader, 35) > maximum { maximum = winmd_table_count(reader, 35); }
        if winmd_table_count(reader, 1) > maximum { maximum = winmd_table_count(reader, 1); }
    } else if kind == 1 {
        limit = winmd_coded_limit(2);
        maximum = winmd_table_count(reader, 2);
        if winmd_table_count(reader, 1) > maximum { maximum = winmd_table_count(reader, 1); }
        if winmd_table_count(reader, 27) > maximum { maximum = winmd_table_count(reader, 27); }
    } else if kind == 2 {
        limit = winmd_coded_limit(2);
        maximum = winmd_table_count(reader, 4);
        if winmd_table_count(reader, 8) > maximum { maximum = winmd_table_count(reader, 8); }
        if winmd_table_count(reader, 23) > maximum { maximum = winmd_table_count(reader, 23); }
    } else if kind == 3 {
        limit = winmd_coded_limit(5);
        usize table = 0;
        while table < 45 {
            bool included = table == 0 || table == 1 || table == 2 ||
                table == 4 || table == 6 || table == 8 || table == 9 ||
                table == 10 || table == 14 || table == 17 || table == 20 ||
                table == 23 || table == 26 || table == 27 || table == 32 ||
                table == 35 || table == 38 || table == 39 || table == 40 ||
                table == 42 || table == 43 || table == 44;
            if included && winmd_table_count(reader, table) > maximum {
                maximum = winmd_table_count(reader, table);
            }
            table = table + 1;
        }
    } else if kind == 4 {
        limit = winmd_coded_limit(1);
        maximum = winmd_table_count(reader, 4);
        if winmd_table_count(reader, 8) > maximum { maximum = winmd_table_count(reader, 8); }
    } else if kind == 5 {
        limit = winmd_coded_limit(2);
        maximum = winmd_table_count(reader, 2);
        if winmd_table_count(reader, 6) > maximum { maximum = winmd_table_count(reader, 6); }
        if winmd_table_count(reader, 32) > maximum { maximum = winmd_table_count(reader, 32); }
    } else if kind == 6 {
        limit = winmd_coded_limit(3);
        maximum = winmd_table_count(reader, 2);
        if winmd_table_count(reader, 1) > maximum { maximum = winmd_table_count(reader, 1); }
        if winmd_table_count(reader, 26) > maximum { maximum = winmd_table_count(reader, 26); }
        if winmd_table_count(reader, 6) > maximum { maximum = winmd_table_count(reader, 6); }
        if winmd_table_count(reader, 27) > maximum { maximum = winmd_table_count(reader, 27); }
    } else if kind == 7 {
        limit = winmd_coded_limit(1);
        maximum = winmd_table_count(reader, 20);
        if winmd_table_count(reader, 23) > maximum { maximum = winmd_table_count(reader, 23); }
    } else if kind == 8 {
        limit = winmd_coded_limit(1);
        maximum = winmd_table_count(reader, 6);
        if winmd_table_count(reader, 10) > maximum { maximum = winmd_table_count(reader, 10); }
    } else if kind == 9 {
        limit = winmd_coded_limit(1);
        maximum = winmd_table_count(reader, 4);
        if winmd_table_count(reader, 6) > maximum { maximum = winmd_table_count(reader, 6); }
    } else if kind == 10 {
        limit = winmd_coded_limit(2);
        maximum = winmd_table_count(reader, 38);
        if winmd_table_count(reader, 35) > maximum { maximum = winmd_table_count(reader, 35); }
        if winmd_table_count(reader, 39) > maximum { maximum = winmd_table_count(reader, 39); }
    } else if kind == 11 {
        limit = winmd_coded_limit(3);
        maximum = winmd_table_count(reader, 6);
        if winmd_table_count(reader, 10) > maximum { maximum = winmd_table_count(reader, 10); }
    } else {
        limit = winmd_coded_limit(1);
        maximum = winmd_table_count(reader, 2);
        if winmd_table_count(reader, 6) > maximum { maximum = winmd_table_count(reader, 6); }
    }
    if maximum >= limit { return 4; }
    return 2;
}

unsafe usize winmd_table_schema_size(
    ref WinmdReader reader,
    usize table
) {
    usize string_index = 2;
    usize guid_index = 2;
    usize blob_index = 2;
    if (reader.heap_sizes & 1) != 0 { string_index = 4; }
    if (reader.heap_sizes & 2) != 0 { guid_index = 4; }
    if (reader.heap_sizes & 4) != 0 { blob_index = 4; }
    if table == 0 { return 2 + string_index + guid_index * 3; }
    if table == 1 { return winmd_coded_index_size(reader, 0) + string_index * 2; }
    if table == 2 { return 4 + string_index * 2 + winmd_coded_index_size(reader, 1) + winmd_simple_index_size(reader, 4) + winmd_simple_index_size(reader, 6); }
    if table == 3 { return winmd_simple_index_size(reader, 4); }
    if table == 4 { return 2 + string_index + blob_index; }
    if table == 5 { return winmd_simple_index_size(reader, 6); }
    if table == 6 { return 8 + string_index + blob_index + winmd_simple_index_size(reader, 8); }
    if table == 7 { return winmd_simple_index_size(reader, 8); }
    if table == 8 { return 4 + string_index; }
    if table == 9 { return winmd_simple_index_size(reader, 2) + winmd_coded_index_size(reader, 1); }
    if table == 10 { return winmd_coded_index_size(reader, 6) + string_index + blob_index; }
    if table == 11 { return 2 + winmd_coded_index_size(reader, 2) + blob_index; }
    if table == 12 { return winmd_coded_index_size(reader, 3) + winmd_coded_index_size(reader, 11) + blob_index; }
    if table == 13 { return winmd_coded_index_size(reader, 4) + blob_index; }
    if table == 14 { return 2 + winmd_coded_index_size(reader, 5) + blob_index; }
    if table == 15 { return 6 + winmd_simple_index_size(reader, 2); }
    if table == 16 { return 4 + winmd_simple_index_size(reader, 4); }
    if table == 17 { return blob_index; }
    if table == 18 { return winmd_simple_index_size(reader, 2) + winmd_simple_index_size(reader, 20); }
    if table == 19 { return winmd_simple_index_size(reader, 20); }
    if table == 20 { return 2 + string_index + winmd_coded_index_size(reader, 1); }
    if table == 21 { return winmd_simple_index_size(reader, 2) + winmd_simple_index_size(reader, 23); }
    if table == 22 { return winmd_simple_index_size(reader, 23); }
    if table == 23 { return 2 + string_index + blob_index; }
    if table == 24 { return 2 + winmd_simple_index_size(reader, 6) + winmd_coded_index_size(reader, 7); }
    if table == 25 { return winmd_simple_index_size(reader, 2) + winmd_coded_index_size(reader, 8) * 2; }
    if table == 26 { return string_index; }
    if table == 27 { return blob_index; }
    if table == 28 { return 2 + winmd_coded_index_size(reader, 9) + string_index + winmd_simple_index_size(reader, 26); }
    if table == 29 { return 4 + winmd_simple_index_size(reader, 4); }
    if table == 30 { return 8; }
    if table == 31 { return 4; }
    if table == 32 { return 16 + blob_index + string_index * 2; }
    if table == 33 { return 4; }
    if table == 34 { return 12; }
    if table == 35 { return 12 + blob_index * 2 + string_index * 2; }
    if table == 36 { return 4 + winmd_simple_index_size(reader, 35); }
    if table == 37 { return 12 + winmd_simple_index_size(reader, 35); }
    if table == 38 { return 4 + string_index + blob_index; }
    if table == 39 { return 8 + string_index * 2 + winmd_coded_index_size(reader, 10); }
    if table == 40 { return 8 + string_index + winmd_coded_index_size(reader, 10); }
    if table == 41 { return winmd_simple_index_size(reader, 2) * 2; }
    if table == 42 { return 4 + winmd_coded_index_size(reader, 12) + string_index; }
    if table == 43 { return winmd_coded_index_size(reader, 8) + blob_index; }
    if table == 44 { return winmd_simple_index_size(reader, 42) + winmd_coded_index_size(reader, 1); }
    return 0;
}

unsafe status winmd_parse(
    ptr byte data,
    usize length,
    out WinmdReader reader
) {
    reader = WinmdReader{
        data = data, length = length, pe_magic = 0,
        metadata_offset = 0, metadata_size = 0,
        tables_offset = 0, tables_size = 0,
        strings_offset = 0, strings_size = 0,
        blob_offset = 0, blob_size = 0,
        guid_offset = 0, guid_size = 0,
        heap_sizes = 0, valid_tables = cast(u64, 0),
        tables = PackedBuffer{ length = 64, capacity = 64 },
        table_data = memory.alloc(64 * record_stride()), ok = true
    };
    if length < 512 || winmd_u16(reader, 0) != 23117 {
        reader.ok = false;
        return status{ code = 1, message = "WinMD DOS header is invalid" };
    }
    usize pe = winmd_u32(reader, 60);
    if winmd_u32(reader, pe) != 17744 {
        reader.ok = false;
        return status{ code = 1, message = "WinMD PE signature is invalid" };
    }
    usize section_count = winmd_u16(reader, pe + 6);
    usize optional_size = winmd_u16(reader, pe + 20);
    usize optional_header = pe + 24;
    reader.pe_magic = winmd_u16(reader, optional_header);
    usize directory_base = optional_header + 96;
    if reader.pe_magic == 523 { directory_base = optional_header + 112; }
    else if reader.pe_magic != 267 {
        reader.ok = false;
        return status{ code = 1, message = "WinMD optional header is unsupported" };
    }
    usize cli_rva = winmd_u32(reader, directory_base + 14 * 8);
    usize cli_size = winmd_u32(reader, directory_base + 14 * 8 + 4);
    usize section_headers = optional_header + optional_size;
    usize cli = winmd_rva_to_offset(
        reader, section_headers, section_count, cli_rva
    );
    if cli_size < 24 || !reader.ok {
        return status{ code = 1, message = "WinMD CLI header is missing" };
    }
    usize metadata_rva = winmd_u32(reader, cli + 8);
    reader.metadata_size = winmd_u32(reader, cli + 12);
    reader.metadata_offset = winmd_rva_to_offset(
        reader, section_headers, section_count, metadata_rva
    );
    usize metadata = reader.metadata_offset;
    if winmd_u32(reader, metadata) != 1112167234 {
        reader.ok = false;
        return status{ code = 1, message = "WinMD BSJB metadata root is invalid" };
    }
    usize version_length = winmd_u32(reader, metadata + 12);
    usize stream_header = x64_align_up(metadata + 16 + version_length, 4);
    usize stream_count = winmd_u16(reader, stream_header + 2);
    usize stream = stream_header + 4;
    usize stream_index = 0;
    while stream_index < stream_count && reader.ok {
        usize relative = winmd_u32(reader, stream);
        usize size = winmd_u32(reader, stream + 4);
        usize name_start = stream + 8;
        usize name_length = 0;
        while name_length < 32 && winmd_u8(reader, name_start + name_length) != 0 {
            name_length = name_length + 1;
        }
        usize absolute = metadata + relative;
        if winmd_bytes_equal_ascii(reader, name_start, name_length, "#~") ||
            winmd_bytes_equal_ascii(reader, name_start, name_length, "#-") {
            reader.tables_offset = absolute; reader.tables_size = size;
        } else if winmd_bytes_equal_ascii(reader, name_start, name_length, "#Strings") {
            reader.strings_offset = absolute; reader.strings_size = size;
        } else if winmd_bytes_equal_ascii(reader, name_start, name_length, "#Blob") {
            reader.blob_offset = absolute; reader.blob_size = size;
        } else if winmd_bytes_equal_ascii(reader, name_start, name_length, "#GUID") {
            reader.guid_offset = absolute; reader.guid_size = size;
        }
        stream = x64_align_up(name_start + name_length + 1, 4);
        stream_index = stream_index + 1;
    }
    if reader.tables_offset == 0 || reader.strings_offset == 0 ||
        reader.blob_offset == 0 {
        reader.ok = false;
        return status{ code = 1, message = "WinMD required metadata streams are missing" };
    }
    reader.heap_sizes = winmd_u8(reader, reader.tables_offset + 6);
    reader.valid_tables = winmd_u64(reader, reader.tables_offset + 8);
    usize rows_at = reader.tables_offset + 24;
    usize table = 0;
    while table < 64 {
        usize count = 0;
        if ((reader.valid_tables >> table) & cast(u64, 1)) != 0 {
            count = winmd_u32(reader, rows_at);
            rows_at = rows_at + 4;
        }
        write_record_field(reader.table_data, table, 0, count);
        table = table + 1;
    }
    usize table_at = rows_at;
    table = 0;
    while table < 64 && reader.ok {
        usize count = winmd_table_count(reader, table);
        usize row_size = winmd_table_schema_size(reader, table);
        if count != 0 && row_size == 0 {
            reader.ok = false;
        }
        write_record_field(reader.table_data, table, 1, table_at);
        write_record_field(reader.table_data, table, 2, row_size);
        if count != 0 && (table_at > reader.length ||
            count > (reader.length - table_at) / row_size) {
            reader.ok = false;
        } else {
            table_at = table_at + count * row_size;
        }
        table = table + 1;
    }
    if !reader.ok || table_at > reader.tables_offset + reader.tables_size {
        reader.ok = false;
        return status{ code = 1, message = "WinMD metadata tables are malformed" };
    }
    return status{ code = 0 };
}

unsafe void winmd_reader_destroy(own WinmdReader reader) {
    memory.free(reader.table_data);
    reader.ok = false;
}

unsafe usize winmd_row_offset(
    ref WinmdReader reader,
    usize table,
    usize row
) {
    usize count = winmd_table_count(reader, table);
    if row == 0 || row > count {
        reader.ok = false;
        return 0;
    }
    return winmd_table_start(reader, table) +
        (row - 1) * winmd_table_row_size(reader, table);
}

unsafe usize winmd_read_index(
    ref WinmdReader reader,
    usize offset,
    usize size
) {
    if size == 2 { return winmd_u16(reader, offset); }
    return winmd_u32(reader, offset);
}

unsafe usize winmd_string_index_size(ref WinmdReader reader) {
    if (reader.heap_sizes & 1) != 0 { return 4; }
    return 2;
}

unsafe usize winmd_blob_index_size(ref WinmdReader reader) {
    if (reader.heap_sizes & 4) != 0 { return 4; }
    return 2;
}
