import system.text;

unsafe usize winmd_heap_index(
    ref WinmdReader reader,
    usize offset,
    bool blob
) {
    usize size = winmd_string_index_size(reader);
    if blob { size = winmd_blob_index_size(reader); }
    return winmd_read_index(reader, offset, size);
}

unsafe bool winmd_heap_string_equals(
    ref WinmdReader reader,
    usize index,
    text expected
) {
    if index >= reader.strings_size { reader.ok = false; return false; }
    usize length = text.byte_length(expected);
    usize cursor = 0;
    while cursor < length {
        if index + cursor >= reader.strings_size ||
            winmd_u8(reader, reader.strings_offset + index + cursor) !=
                cast(usize, byte_at_or_zero(expected, cursor)) {
            return false;
        }
        cursor = cursor + 1;
    }
    return index + length < reader.strings_size &&
        winmd_u8(reader, reader.strings_offset + index + length) == 0;
}

unsafe bool winmd_heap_string_contains(
    ref WinmdReader reader,
    usize index,
    text expected
) {
    if index >= reader.strings_size { reader.ok = false; return false; }
    usize expected_length = text.byte_length(expected);
    usize string_length = 0;
    while index + string_length < reader.strings_size &&
        winmd_u8(reader, reader.strings_offset + index + string_length) != 0 {
        string_length = string_length + 1;
    }
    usize cursor = 0;
    while cursor + expected_length <= string_length {
        usize match = 0;
        while match < expected_length && winmd_u8(
            reader, reader.strings_offset + index + cursor + match
        ) == cast(usize, byte_at_or_zero(expected, match)) {
            match = match + 1;
        }
        if match == expected_length { return true; }
        cursor = cursor + 1;
    }
    return false;
}

unsafe void winmd_put_hex_byte(ref DBuffer output, usize value) {
    usize high = (value >> 4) & 15;
    usize low = value & 15;
    if high < 10 { d_put_byte(output, cast(u8, 48 + high)); }
    else { d_put_byte(output, cast(u8, 87 + high)); }
    if low < 10 { d_put_byte(output, cast(u8, 48 + low)); }
    else { d_put_byte(output, cast(u8, 87 + low)); }
}

unsafe void winmd_put_heap_string_hex(
    ref WinmdReader reader,
    usize index,
    ref DBuffer output
) {
    if index >= reader.strings_size { reader.ok = false; return; }
    usize cursor = 0;
    while index + cursor < reader.strings_size {
        usize value = winmd_u8(
            reader, reader.strings_offset + index + cursor
        );
        if value == 0 { return; }
        winmd_put_hex_byte(output, value);
        cursor = cursor + 1;
    }
    reader.ok = false;
}

unsafe WinmdBlobSpan winmd_blob_span(
    ref WinmdReader reader,
    usize index
) {
    usize start = 0; usize length = 0;
    if index >= reader.blob_size {
        reader.ok = false;
        return WinmdBlobSpan{ start = 0, length = 0 };
    }
    usize at = reader.blob_offset + index;
    usize first = winmd_u8(reader, at);
    if first < 128 {
        start = at + 1; length = first;
    } else if (first & 192) == 128 {
        start = at + 2;
        length = ((first & 63) << 8) | winmd_u8(reader, at + 1);
    } else if (first & 224) == 192 {
        start = at + 4;
        length = ((first & 31) << 24) |
            (winmd_u8(reader, at + 1) << 16) |
            (winmd_u8(reader, at + 2) << 8) |
            winmd_u8(reader, at + 3);
    } else {
        reader.ok = false;
        return WinmdBlobSpan{ start = 0, length = 0 };
    }
    if start > reader.length || length > reader.length - start {
        reader.ok = false; start = 0; length = 0;
    }
    return WinmdBlobSpan{ start = start, length = length };
}

unsafe void winmd_put_blob_hex(
    ref WinmdReader reader,
    usize index,
    ref DBuffer output
) {
    WinmdBlobSpan span = winmd_blob_span(reader, index);
    usize cursor = 0;
    while cursor < span.length {
        winmd_put_hex_byte(output, winmd_u8(reader, span.start + cursor));
        cursor = cursor + 1;
    }
}

unsafe usize winmd_type_flags(ref WinmdReader reader, usize row) {
    return winmd_u32(reader, winmd_row_offset(reader, 2, row));
}

unsafe usize winmd_type_name(ref WinmdReader reader, usize row) {
    return winmd_heap_index(reader, winmd_row_offset(reader, 2, row) + 4, false);
}

unsafe usize winmd_type_namespace(ref WinmdReader reader, usize row) {
    return winmd_heap_index(
        reader, winmd_row_offset(reader, 2, row) + 4 +
            winmd_string_index_size(reader), false
    );
}

unsafe usize winmd_type_extends(ref WinmdReader reader, usize row) {
    return winmd_read_index(
        reader,
        winmd_row_offset(reader, 2, row) + 4 +
            winmd_string_index_size(reader) * 2,
        winmd_coded_index_size(reader, 1)
    );
}

unsafe usize winmd_type_field_first(ref WinmdReader reader, usize row) {
    return winmd_read_index(
        reader,
        winmd_row_offset(reader, 2, row) + 4 +
            winmd_string_index_size(reader) * 2 +
            winmd_coded_index_size(reader, 1),
        winmd_simple_index_size(reader, 4)
    );
}

unsafe usize winmd_type_method_first(ref WinmdReader reader, usize row) {
    return winmd_read_index(
        reader,
        winmd_row_offset(reader, 2, row) + 4 +
            winmd_string_index_size(reader) * 2 +
            winmd_coded_index_size(reader, 1) +
            winmd_simple_index_size(reader, 4),
        winmd_simple_index_size(reader, 6)
    );
}

unsafe usize winmd_field_flags(ref WinmdReader reader, usize row) {
    return winmd_u16(reader, winmd_row_offset(reader, 4, row));
}

unsafe usize winmd_field_name(ref WinmdReader reader, usize row) {
    return winmd_heap_index(reader, winmd_row_offset(reader, 4, row) + 2, false);
}

unsafe usize winmd_field_signature(ref WinmdReader reader, usize row) {
    return winmd_heap_index(
        reader, winmd_row_offset(reader, 4, row) + 2 +
            winmd_string_index_size(reader), true
    );
}

unsafe usize winmd_method_rva(ref WinmdReader reader, usize row) {
    return winmd_u32(reader, winmd_row_offset(reader, 6, row));
}

unsafe usize winmd_method_impl_flags(ref WinmdReader reader, usize row) {
    return winmd_u16(reader, winmd_row_offset(reader, 6, row) + 4);
}

unsafe usize winmd_method_flags(ref WinmdReader reader, usize row) {
    return winmd_u16(reader, winmd_row_offset(reader, 6, row) + 6);
}

unsafe usize winmd_method_name(ref WinmdReader reader, usize row) {
    return winmd_heap_index(reader, winmd_row_offset(reader, 6, row) + 8, false);
}

unsafe usize winmd_method_signature(ref WinmdReader reader, usize row) {
    return winmd_heap_index(
        reader, winmd_row_offset(reader, 6, row) + 8 +
            winmd_string_index_size(reader), true
    );
}

unsafe usize winmd_method_param_first(ref WinmdReader reader, usize row) {
    return winmd_read_index(
        reader,
        winmd_row_offset(reader, 6, row) + 8 +
            winmd_string_index_size(reader) +
            winmd_blob_index_size(reader),
        winmd_simple_index_size(reader, 8)
    );
}

unsafe usize winmd_param_flags(ref WinmdReader reader, usize row) {
    return winmd_u16(reader, winmd_row_offset(reader, 8, row));
}

unsafe usize winmd_param_sequence(ref WinmdReader reader, usize row) {
    return winmd_u16(reader, winmd_row_offset(reader, 8, row) + 2);
}

unsafe usize winmd_param_name(ref WinmdReader reader, usize row) {
    return winmd_heap_index(reader, winmd_row_offset(reader, 8, row) + 4, false);
}

unsafe usize winmd_owner_type_for_list(
    ref WinmdReader reader,
    usize row,
    bool methods
) {
    usize low = 1;
    usize high = winmd_table_count(reader, 2);
    usize result = 0;
    while low <= high {
        usize middle = low + (high - low) / 2;
        usize first = winmd_type_field_first(reader, middle);
        if methods { first = winmd_type_method_first(reader, middle); }
        if first <= row {
            result = middle; low = middle + 1;
        } else {
            if middle == 0 { return result; }
            high = middle - 1;
        }
    }
    return result;
}

unsafe usize winmd_owner_type_for_field(
    ref WinmdReader reader,
    usize row
) { return winmd_owner_type_for_list(reader, row, false); }

unsafe usize winmd_owner_type_for_method(
    ref WinmdReader reader,
    usize row
) { return winmd_owner_type_for_list(reader, row, true); }

unsafe usize winmd_owner_method_for_param(
    ref WinmdReader reader,
    usize row
) {
    usize low = 1;
    usize high = winmd_table_count(reader, 6);
    usize result = 0;
    while low <= high {
        usize middle = low + (high - low) / 2;
        usize first = winmd_method_param_first(reader, middle);
        if first <= row { result = middle; low = middle + 1; }
        else { if middle == 0 { return result; } high = middle - 1; }
    }
    return result;
}

unsafe usize winmd_nested_parent(ref WinmdReader reader, usize type_row) {
    usize low = 1;
    usize high = winmd_table_count(reader, 41);
    usize index_size = winmd_simple_index_size(reader, 2);
    while low <= high {
        usize middle = low + (high - low) / 2;
        usize offset = winmd_row_offset(reader, 41, middle);
        usize child = winmd_read_index(reader, offset, index_size);
        if child == type_row {
            return winmd_read_index(reader, offset + index_size, index_size);
        }
        if child < type_row { low = middle + 1; }
        else { if middle == 0 { return 0; } high = middle - 1; }
    }
    return 0;
}

unsafe usize winmd_effective_namespace(
    ref WinmdReader reader,
    usize type_row
) {
    usize namespace_index = winmd_type_namespace(reader, type_row);
    usize depth = 0;
    while namespace_index == 0 && depth < 16 {
        usize parent = winmd_nested_parent(reader, type_row);
        if parent == 0 { return 0; }
        type_row = parent;
        namespace_index = winmd_type_namespace(reader, type_row);
        depth = depth + 1;
    }
    return namespace_index;
}

unsafe usize winmd_module_for_namespace_and_name(
    ref WinmdReader reader,
    usize namespace_index,
    usize name_index
) {
    if winmd_heap_string_equals(reader, namespace_index, "Windows.Win32.Foundation") {
        return winmd_module_foundation();
    }
    if winmd_heap_string_equals(reader, namespace_index, "Windows.Win32.Storage.FileSystem") {
        return winmd_module_file();
    }
    if winmd_heap_string_equals(reader, namespace_index, "Windows.Win32.System.Memory") {
        return winmd_module_memory();
    }
    if winmd_heap_string_equals(reader, namespace_index, "Windows.Win32.System.Threading") {
        if winmd_heap_string_contains(reader, name_index, "Process") ||
            winmd_heap_string_contains(reader, name_index, "PROCESS") ||
            winmd_heap_string_contains(reader, name_index, "Job") ||
            winmd_heap_string_contains(reader, name_index, "JOB") ||
            winmd_heap_string_contains(reader, name_index, "Startup") ||
            winmd_heap_string_contains(reader, name_index, "STARTUP") ||
            winmd_heap_string_contains(reader, name_index, "Environment") {
            return winmd_module_process();
        }
        return winmd_module_thread();
    }
    if winmd_heap_string_equals(reader, namespace_index, "Windows.Win32.UI.WindowsAndMessaging") {
        return winmd_module_window();
    }
    if winmd_heap_string_equals(reader, namespace_index, "Windows.Win32.Graphics.Gdi") {
        return winmd_module_graphics();
    }
    return winmd_module_none();
}

unsafe usize winmd_module_for_type(
    ref WinmdReader reader,
    usize type_row
) {
    return winmd_module_for_namespace_and_name(
        reader, winmd_effective_namespace(reader, type_row),
        winmd_type_name(reader, type_row)
    );
}

unsafe usize winmd_module_for_method(
    ref WinmdReader reader,
    usize method_row
) {
    usize owner = winmd_owner_type_for_method(reader, method_row);
    if owner == 0 { return winmd_module_none(); }
    return winmd_module_for_namespace_and_name(
        reader, winmd_effective_namespace(reader, owner),
        winmd_method_name(reader, method_row)
    );
}

unsafe usize winmd_module_for_field(
    ref WinmdReader reader,
    usize field_row
) {
    usize owner = winmd_owner_type_for_field(reader, field_row);
    if owner == 0 { return winmd_module_none(); }
    return winmd_module_for_namespace_and_name(
        reader, winmd_effective_namespace(reader, owner),
        winmd_field_name(reader, field_row)
    );
}

unsafe usize winmd_module_for_param(
    ref WinmdReader reader,
    usize param_row
) {
    usize owner = winmd_owner_method_for_param(reader, param_row);
    if owner == 0 { return winmd_module_none(); }
    return winmd_module_for_method(reader, owner);
}

unsafe usize winmd_interface_type(ref WinmdReader reader, usize row) {
    return winmd_read_index(
        reader, winmd_row_offset(reader, 9, row),
        winmd_simple_index_size(reader, 2)
    );
}

unsafe usize winmd_custom_parent(ref WinmdReader reader, usize row) {
    return winmd_read_index(
        reader, winmd_row_offset(reader, 12, row),
        winmd_coded_index_size(reader, 3)
    );
}

unsafe usize winmd_custom_constructor(ref WinmdReader reader, usize row) {
    return winmd_read_index(
        reader, winmd_row_offset(reader, 12, row) +
            winmd_coded_index_size(reader, 3),
        winmd_coded_index_size(reader, 11)
    );
}

unsafe usize winmd_custom_value(ref WinmdReader reader, usize row) {
    return winmd_heap_index(
        reader, winmd_row_offset(reader, 12, row) +
            winmd_coded_index_size(reader, 3) +
            winmd_coded_index_size(reader, 11), true
    );
}

unsafe usize winmd_module_for_custom_parent(
    ref WinmdReader reader,
    usize coded
) {
    usize tag = coded & 31;
    usize row = coded >> 5;
    if tag == 0 { return winmd_module_for_method(reader, row); }
    if tag == 1 { return winmd_module_for_field(reader, row); }
    if tag == 3 { return winmd_module_for_type(reader, row); }
    if tag == 4 { return winmd_module_for_param(reader, row); }
    if tag == 5 {
        return winmd_module_for_type(reader, winmd_interface_type(reader, row));
    }
    return winmd_module_none();
}

unsafe usize winmd_type_ref_name(ref WinmdReader reader, usize row) {
    return winmd_heap_index(
        reader, winmd_row_offset(reader, 1, row) +
            winmd_coded_index_size(reader, 0), false
    );
}

unsafe usize winmd_type_ref_namespace(ref WinmdReader reader, usize row) {
    return winmd_heap_index(
        reader, winmd_row_offset(reader, 1, row) +
            winmd_coded_index_size(reader, 0) +
            winmd_string_index_size(reader), false
    );
}

unsafe usize winmd_member_ref_parent(ref WinmdReader reader, usize row) {
    return winmd_read_index(
        reader, winmd_row_offset(reader, 10, row),
        winmd_coded_index_size(reader, 6)
    );
}

unsafe usize winmd_custom_attribute_type_ref(
    ref WinmdReader reader,
    usize custom_row
) {
    usize constructor = winmd_custom_constructor(reader, custom_row);
    usize tag = constructor & 7;
    usize member_row = constructor >> 3;
    if tag != 3 || member_row == 0 { return 0; }
    usize parent = winmd_member_ref_parent(reader, member_row);
    if (parent & 7) != 1 { return 0; }
    return parent >> 3;
}

unsafe bool winmd_custom_attribute_is(
    ref WinmdReader reader,
    usize custom_row,
    text name
) {
    usize type_ref = winmd_custom_attribute_type_ref(reader, custom_row);
    return type_ref != 0 && winmd_heap_string_equals(
        reader, winmd_type_ref_name(reader, type_ref), name
    );
}

unsafe void winmd_count_attribute(
    ref WinmdReader reader,
    usize row,
    ref WinmdAttributeStats stats
) {
    if winmd_custom_attribute_is(reader, row, "DocumentationAttribute") { stats.documentation = stats.documentation + 1; }
    else if winmd_custom_attribute_is(reader, row, "SupportedArchitectureAttribute") { stats.supported_architecture = stats.supported_architecture + 1; }
    else if winmd_custom_attribute_is(reader, row, "SupportedOSPlatformAttribute") { stats.supported_os = stats.supported_os + 1; }
    else if winmd_custom_attribute_is(reader, row, "AnsiAttribute") { stats.ansi = stats.ansi + 1; }
    else if winmd_custom_attribute_is(reader, row, "UnicodeAttribute") { stats.unicode = stats.unicode + 1; }
    else if winmd_custom_attribute_is(reader, row, "NativeArrayInfoAttribute") { stats.native_array = stats.native_array + 1; }
    else if winmd_custom_attribute_is(reader, row, "RetainedAttribute") { stats.retained = stats.retained + 1; }
    else if winmd_custom_attribute_is(reader, row, "RAIIFreeAttribute") { stats.raii_free = stats.raii_free + 1; }
    else if winmd_custom_attribute_is(reader, row, "FreeWithAttribute") { stats.free_with = stats.free_with + 1; }
    else if winmd_custom_attribute_is(reader, row, "InvalidHandleValueAttribute") { stats.invalid_handle = stats.invalid_handle + 1; }
    else if winmd_custom_attribute_is(reader, row, "NativeTypedefAttribute") { stats.native_typedef = stats.native_typedef + 1; }
    else if winmd_custom_attribute_is(reader, row, "NativeBitfieldAttribute") { stats.native_bitfield = stats.native_bitfield + 1; }
    else if winmd_custom_attribute_is(reader, row, "ConstantAttribute") { stats.constant = stats.constant + 1; }
    else if winmd_custom_attribute_is(reader, row, "FlexibleArrayAttribute") { stats.flexible_array = stats.flexible_array + 1; }
    else if winmd_custom_attribute_is(reader, row, "MemorySizeAttribute") { stats.memory_size = stats.memory_size + 1; }
    else if winmd_custom_attribute_is(reader, row, "StructSizeFieldAttribute") { stats.struct_size_field = stats.struct_size_field + 1; }
}

struct WinmdBlobSpan {
    usize start;
    usize length;
}
