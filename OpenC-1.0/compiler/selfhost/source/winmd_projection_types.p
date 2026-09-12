import system.file;
import system.io;
import system.memory;
import system.path;

unsafe void winmd_emit_types_and_members(
    ref WinmdReader reader,
    usize module,
    ref DBuffer output,
    ref WinmdProjectionStats stats
) {
    usize type_row = 1;
    usize type_count = winmd_table_count(reader, 2);
    usize field_count = winmd_table_count(reader, 4);
    usize method_count = winmd_table_count(reader, 6);
    usize param_count = winmd_table_count(reader, 8);
    while type_row <= type_count {
        usize namespace_index = winmd_effective_namespace(reader, type_row);
        usize type_name = winmd_type_name(reader, type_row);
        usize type_module = winmd_module_for_namespace_and_name(
            reader, namespace_index, type_name
        );
        usize field_first = winmd_type_field_first(reader, type_row);
        usize field_end = field_count + 1;
        usize method_first = winmd_type_method_first(reader, type_row);
        usize method_end = method_count + 1;
        if type_row < type_count {
            field_end = winmd_type_field_first(reader, type_row + 1);
            method_end = winmd_type_method_first(reader, type_row + 1);
        }
        if type_module == module {
            winmd_put_record_prefix(output, "T", type_row);
            winmd_put_number_field(output, winmd_type_flags(reader, type_row));
            winmd_put_string_field(reader, output, winmd_type_namespace(reader, type_row));
            winmd_put_string_field(reader, output, type_name);
            winmd_put_number_field(output, winmd_type_extends(reader, type_row));
            winmd_put_number_field(output, winmd_nested_parent(reader, type_row));
            winmd_put_number_field(output, field_first);
            winmd_put_number_field(output, method_first);
            winmd_put_record_end(output);
            stats.records = stats.records + 1;
            stats.types = stats.types + 1;
        }
        usize field_row = field_first;
        while field_row < field_end {
            usize field_module = winmd_module_for_namespace_and_name(
                reader, namespace_index, winmd_field_name(reader, field_row)
            );
            if field_module == module {
                winmd_put_record_prefix(output, "F", field_row);
                winmd_put_number_field(output, type_row);
                winmd_put_number_field(output, winmd_field_flags(reader, field_row));
                winmd_put_string_field(reader, output, winmd_field_name(reader, field_row));
                winmd_put_blob_field(reader, output, winmd_field_signature(reader, field_row));
                winmd_put_record_end(output);
                stats.records = stats.records + 1;
                stats.fields = stats.fields + 1;
            }
            field_row = field_row + 1;
        }
        usize method_row = method_first;
        while method_row < method_end {
            usize method_module = winmd_module_for_namespace_and_name(
                reader, namespace_index, winmd_method_name(reader, method_row)
            );
            usize param_first = winmd_method_param_first(reader, method_row);
            usize param_end = param_count + 1;
            if method_row < method_count {
                param_end = winmd_method_param_first(reader, method_row + 1);
            }
            if method_module == module {
                winmd_put_record_prefix(output, "M", method_row);
                winmd_put_number_field(output, type_row);
                winmd_put_number_field(output, winmd_method_rva(reader, method_row));
                winmd_put_number_field(output, winmd_method_impl_flags(reader, method_row));
                winmd_put_number_field(output, winmd_method_flags(reader, method_row));
                winmd_put_string_field(reader, output, winmd_method_name(reader, method_row));
                winmd_put_blob_field(reader, output, winmd_method_signature(reader, method_row));
                winmd_put_number_field(output, param_first);
                winmd_put_record_end(output);
                stats.records = stats.records + 1;
                stats.methods = stats.methods + 1;
                usize param_row = param_first;
                while param_row < param_end {
                    winmd_put_record_prefix(output, "P", param_row);
                    winmd_put_number_field(output, method_row);
                    winmd_put_number_field(output, winmd_param_flags(reader, param_row));
                    winmd_put_number_field(output, winmd_param_sequence(reader, param_row));
                    winmd_put_string_field(reader, output, winmd_param_name(reader, param_row));
                    winmd_put_record_end(output);
                    stats.records = stats.records + 1;
                    stats.parameters = stats.parameters + 1;
                    param_row = param_row + 1;
                }
            }
            method_row = method_row + 1;
        }
        type_row = type_row + 1;
    }
}

unsafe void winmd_emit_interfaces(
    ref WinmdReader reader,
    usize module,
    ref DBuffer output,
    ref WinmdProjectionStats stats
) {
    usize row = 1;
    usize type_index_size = winmd_simple_index_size(reader, 2);
    while row <= winmd_table_count(reader, 9) {
        usize offset = winmd_row_offset(reader, 9, row);
        usize owner = winmd_read_index(reader, offset, type_index_size);
        if winmd_module_for_type(reader, owner) == module {
            winmd_put_record_prefix(output, "X", row);
            winmd_put_number_field(output, owner);
            winmd_put_number_field(output, winmd_read_index(
                reader, offset + type_index_size,
                winmd_coded_index_size(reader, 1)
            ));
            winmd_put_record_end(output);
            stats.records = stats.records + 1;
        }
        row = row + 1;
    }
}

unsafe void winmd_emit_imports(
    ref WinmdReader reader,
    usize module,
    ref DBuffer output,
    ref WinmdProjectionStats stats
) {
    usize row = 1;
    while row <= winmd_table_count(reader, 28) {
        if winmd_module_for_impl(reader, row) == module {
            usize import_scope = winmd_impl_scope(reader, row);
            winmd_put_record_prefix(output, "I", row);
            winmd_put_number_field(output, winmd_impl_flags(reader, row));
            winmd_put_number_field(output, winmd_impl_member(reader, row));
            winmd_put_string_field(reader, output, winmd_impl_import_name(reader, row));
            winmd_put_number_field(output, import_scope);
            if import_scope != 0 && import_scope <= winmd_table_count(reader, 26) {
                winmd_put_string_field(reader, output, winmd_module_ref_name(reader, import_scope));
            } else { d_put(output, "|"); }
            winmd_put_record_end(output);
            stats.records = stats.records + 1;
            stats.imports = stats.imports + 1;
        }
        row = row + 1;
    }
}
