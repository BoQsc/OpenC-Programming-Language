import system.file;
import system.io;
import system.memory;
import system.path;

unsafe WinmdProjectionStats winmd_projection_stats() {
    return WinmdProjectionStats{
        records = 0, types = 0, fields = 0, methods = 0,
        parameters = 0, imports = 0, constants = 0,
        custom_attributes = 0, class_layouts = 0, field_layouts = 0
    };
}

unsafe WinmdAttributeStats winmd_attribute_stats() {
    return WinmdAttributeStats{
        documentation = 0, supported_architecture = 0, supported_os = 0,
        ansi = 0, unicode = 0, native_array = 0, retained = 0,
        raii_free = 0, free_with = 0, invalid_handle = 0,
        native_typedef = 0, native_bitfield = 0, constant = 0,
        flexible_array = 0, memory_size = 0, struct_size_field = 0
    };
}

unsafe void winmd_put_record_prefix(
    ref DBuffer output,
    text kind,
    usize row
) {
    d_put(output, "// "); d_put(output, kind); d_put(output, "|");
    d_put_usize(output, row);
}

unsafe void winmd_put_number_field(ref DBuffer output, usize value) {
    d_put(output, "|"); d_put_usize(output, value);
}

unsafe void winmd_put_string_field(
    ref WinmdReader reader,
    ref DBuffer output,
    usize index
) {
    d_put(output, "|"); winmd_put_heap_string_hex(reader, index, output);
}

unsafe void winmd_put_blob_field(
    ref WinmdReader reader,
    ref DBuffer output,
    usize index
) {
    d_put(output, "|"); winmd_put_blob_hex(reader, index, output);
}

unsafe void winmd_put_record_end(ref DBuffer output) { d_put(output, "\n"); }

unsafe usize winmd_typeref_resolution(ref WinmdReader reader, usize row) {
    return winmd_read_index(
        reader, winmd_row_offset(reader, 1, row),
        winmd_coded_index_size(reader, 0)
    );
}

unsafe usize winmd_module_ref_name(ref WinmdReader reader, usize row) {
    return winmd_heap_index(
        reader, winmd_row_offset(reader, 26, row), false
    );
}

unsafe usize winmd_constant_parent(ref WinmdReader reader, usize row) {
    return winmd_read_index(
        reader, winmd_row_offset(reader, 11, row) + 2,
        winmd_coded_index_size(reader, 2)
    );
}

unsafe usize winmd_constant_value(ref WinmdReader reader, usize row) {
    return winmd_heap_index(
        reader, winmd_row_offset(reader, 11, row) + 2 +
            winmd_coded_index_size(reader, 2), true
    );
}

unsafe usize winmd_module_for_constant(
    ref WinmdReader reader,
    usize row
) {
    usize parent = winmd_constant_parent(reader, row);
    usize tag = parent & 3;
    usize parent_row = parent >> 2;
    if tag == 0 { return winmd_module_for_field(reader, parent_row); }
    if tag == 1 { return winmd_module_for_param(reader, parent_row); }
    return winmd_module_none();
}

unsafe usize winmd_impl_flags(ref WinmdReader reader, usize row) {
    return winmd_u16(reader, winmd_row_offset(reader, 28, row));
}

unsafe usize winmd_impl_member(ref WinmdReader reader, usize row) {
    return winmd_read_index(
        reader, winmd_row_offset(reader, 28, row) + 2,
        winmd_coded_index_size(reader, 9)
    );
}

unsafe usize winmd_impl_import_name(ref WinmdReader reader, usize row) {
    return winmd_heap_index(
        reader, winmd_row_offset(reader, 28, row) + 2 +
            winmd_coded_index_size(reader, 9), false
    );
}

unsafe usize winmd_impl_scope(ref WinmdReader reader, usize row) {
    return winmd_read_index(
        reader, winmd_row_offset(reader, 28, row) + 2 +
            winmd_coded_index_size(reader, 9) +
            winmd_string_index_size(reader),
        winmd_simple_index_size(reader, 26)
    );
}

unsafe usize winmd_module_for_impl(ref WinmdReader reader, usize row) {
    usize member = winmd_impl_member(reader, row);
    if (member & 1) == 0 { return winmd_module_for_field(reader, member >> 1); }
    return winmd_module_for_method(reader, member >> 1);
}

unsafe void winmd_emit_type_refs(
    ref WinmdReader reader,
    ref DBuffer output,
    ref WinmdProjectionStats stats
) {
    usize row = 1;
    while row <= winmd_table_count(reader, 1) {
        winmd_put_record_prefix(output, "R", row);
        winmd_put_number_field(output, winmd_typeref_resolution(reader, row));
        winmd_put_string_field(reader, output, winmd_type_ref_namespace(reader, row));
        winmd_put_string_field(reader, output, winmd_type_ref_name(reader, row));
        winmd_put_record_end(output);
        stats.records = stats.records + 1;
        row = row + 1;
    }
    row = 1;
    while row <= winmd_table_count(reader, 26) {
        winmd_put_record_prefix(output, "D", row);
        winmd_put_string_field(reader, output, winmd_module_ref_name(reader, row));
        winmd_put_record_end(output);
        stats.records = stats.records + 1;
        row = row + 1;
    }
}
