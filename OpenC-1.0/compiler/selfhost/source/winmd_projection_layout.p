import system.file;
import system.io;
import system.memory;
import system.path;

unsafe void winmd_emit_constants(
    ref WinmdReader reader,
    usize module,
    ref DBuffer output,
    ref WinmdProjectionStats stats
) {
    usize row = 1;
    while row <= winmd_table_count(reader, 11) {
        if winmd_module_for_constant(reader, row) == module {
            usize offset = winmd_row_offset(reader, 11, row);
            winmd_put_record_prefix(output, "C", row);
            winmd_put_number_field(output, winmd_u16(reader, offset));
            winmd_put_number_field(output, winmd_constant_parent(reader, row));
            winmd_put_blob_field(reader, output, winmd_constant_value(reader, row));
            winmd_put_record_end(output);
            stats.records = stats.records + 1;
            stats.constants = stats.constants + 1;
        }
        row = row + 1;
    }
}

unsafe void winmd_emit_layouts(
    ref WinmdReader reader,
    usize module,
    ref DBuffer output,
    ref WinmdProjectionStats stats
) {
    usize row = 1;
    usize type_size = winmd_simple_index_size(reader, 2);
    while row <= winmd_table_count(reader, 15) {
        usize offset = winmd_row_offset(reader, 15, row);
        usize owner = winmd_read_index(reader, offset + 6, type_size);
        if winmd_module_for_type(reader, owner) == module {
            winmd_put_record_prefix(output, "L", row);
            winmd_put_number_field(output, winmd_u16(reader, offset));
            winmd_put_number_field(output, winmd_u32(reader, offset + 2));
            winmd_put_number_field(output, owner);
            winmd_put_record_end(output);
            stats.records = stats.records + 1;
            stats.class_layouts = stats.class_layouts + 1;
        }
        row = row + 1;
    }
    row = 1;
    usize field_size = winmd_simple_index_size(reader, 4);
    while row <= winmd_table_count(reader, 16) {
        usize offset = winmd_row_offset(reader, 16, row);
        usize field_row = winmd_read_index(reader, offset + 4, field_size);
        if winmd_module_for_field(reader, field_row) == module {
            winmd_put_record_prefix(output, "O", row);
            winmd_put_number_field(output, winmd_u32(reader, offset));
            winmd_put_number_field(output, field_row);
            winmd_put_record_end(output);
            stats.records = stats.records + 1;
            stats.field_layouts = stats.field_layouts + 1;
        }
        row = row + 1;
    }
}

unsafe void winmd_emit_custom_attributes(
    ref WinmdReader reader,
    usize module,
    ref DBuffer output,
    ref WinmdProjectionStats stats
) {
    usize row = 1;
    while row <= winmd_table_count(reader, 12) {
        usize parent = winmd_custom_parent(reader, row);
        if winmd_module_for_custom_parent(reader, parent) == module {
            usize type_ref = winmd_custom_attribute_type_ref(reader, row);
            winmd_put_record_prefix(output, "A", row);
            winmd_put_number_field(output, parent);
            winmd_put_number_field(output, winmd_custom_constructor(reader, row));
            if type_ref != 0 {
                winmd_put_string_field(reader, output, winmd_type_ref_namespace(reader, type_ref));
                winmd_put_string_field(reader, output, winmd_type_ref_name(reader, type_ref));
            } else { d_put(output, "||"); }
            winmd_put_blob_field(reader, output, winmd_custom_value(reader, row));
            winmd_put_record_end(output);
            stats.records = stats.records + 1;
            stats.custom_attributes = stats.custom_attributes + 1;
        }
        row = row + 1;
    }
}

unsafe void winmd_emit_module_footer(
    usize module,
    ref DBuffer output,
    ref WinmdProjectionStats stats
) {
    d_put(output, "\nexport text raw_module_name() { return \"");
    d_put(output, winmd_module_name(module));
    d_put(output, "\"; }\nexport usize raw_record_count() { return ");
    d_put_usize(output, stats.records);
    d_put(output, "; }\nexport usize raw_type_count() { return ");
    d_put_usize(output, stats.types);
    d_put(output, "; }\nexport usize raw_function_count() { return ");
    d_put_usize(output, stats.imports);
    d_put(output, "; }\n");
}
