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

unsafe bool winmd_emit_module(
    ref WinmdReader reader,
    usize module,
    text output_directory,
    ref DBuffer hashes,
    ptr byte stats_data
) {
    DBuffer output = d_buffer_create(67108864);
    d_put(output, "// Generated by openc-winmd-projector-sh17.1; DO NOT EDIT.\n");
    d_put(output, "// schema=openc.windows_raw_projection.v1\n");
    d_put(output, "// metadata-version="); d_put(output, winmd_pinned_package_version());
    d_put(output, "\n// metadata-sha256="); d_put(output, winmd_pinned_sha256());
    d_put(output, "\n// architecture=x86_64\n");
    d_put(output, "// strings and blobs are exact lowercase hexadecimal UTF-8/bytes.\n");
    d_put(output, "// records: R=typeref D=dll T=type F=field M=method P=param X=interface I=import C=constant L=class-layout O=field-offset A=attribute\n\n");
    WinmdProjectionStats stats = winmd_projection_stats();
    if module == winmd_module_foundation() {
        winmd_emit_type_refs(reader, output, stats);
    }
    winmd_emit_types_and_members(reader, module, output, stats);
    winmd_emit_interfaces(reader, module, output, stats);
    winmd_emit_imports(reader, module, output, stats);
    winmd_emit_constants(reader, module, output, stats);
    winmd_emit_layouts(reader, module, output, stats);
    winmd_emit_custom_attributes(reader, module, output, stats);
    winmd_emit_module_footer(module, output, stats);
    if !reader.ok || !output.ok {
        d_buffer_destroy(output); return false;
    }
    text destination = path.join(
        output_directory, winmd_module_file_name(module)
    );
    status written = file.write_text(destination, d_buffer_text(output));
    if !written.ok { d_buffer_destroy(output); return false; }
    winmd_sha256_hex(output.data, output.length, hashes);
    d_put(hashes, "\n");
    usize base = module * 10 * size_of(usize);
    memory.store_usize(stats_data + base + 0 * size_of(usize), stats.records);
    memory.store_usize(stats_data + base + 1 * size_of(usize), stats.types);
    memory.store_usize(stats_data + base + 2 * size_of(usize), stats.fields);
    memory.store_usize(stats_data + base + 3 * size_of(usize), stats.methods);
    memory.store_usize(stats_data + base + 4 * size_of(usize), stats.parameters);
    memory.store_usize(stats_data + base + 5 * size_of(usize), stats.imports);
    memory.store_usize(stats_data + base + 6 * size_of(usize), stats.constants);
    memory.store_usize(stats_data + base + 7 * size_of(usize), stats.custom_attributes);
    memory.store_usize(stats_data + base + 8 * size_of(usize), stats.class_layouts);
    memory.store_usize(stats_data + base + 9 * size_of(usize), stats.field_layouts);
    d_buffer_destroy(output);
    return true;
}

unsafe usize winmd_saved_stat(
    ptr byte stats_data,
    usize module,
    usize field
) {
    return memory.load_usize(
        stats_data + (module * 10 + field) * size_of(usize)
    );
}

unsafe void winmd_put_json_stat(
    ref DBuffer manifest,
    text name,
    usize value,
    bool comma
) {
    d_put(manifest, "      \""); d_put(manifest, name); d_put(manifest, "\": ");
    d_put_usize(manifest, value);
    if comma { d_put(manifest, ","); }
    d_put(manifest, "\n");
}

unsafe void winmd_emit_manifest(
    ref WinmdReader reader,
    text input_sha,
    text output_path,
    ref DBuffer hashes,
    ptr byte stats_data,
    ref WinmdAttributeStats attributes
) {
    DBuffer manifest = d_buffer_create(65536);
    d_put(manifest, "{\n  \"schema\": \"openc.windows_raw_projection_manifest.v1\",\n");
    d_put(manifest, "  \"status\": \"PASS\",\n  \"metadata\": {\n");
    d_put(manifest, "    \"package\": \"Microsoft.Windows.SDK.Win32Metadata\",\n");
    d_put(manifest, "    \"version\": \""); d_put(manifest, winmd_pinned_package_version());
    d_put(manifest, "\",\n    \"sha256\": \""); d_put(manifest, input_sha);
    d_put(manifest, "\",\n    \"bytes\": "); d_put_usize(manifest, reader.length);
    d_put(manifest, "\n  },\n  \"generator\": {\n    \"version\": \"");
    d_put(manifest, winmd_generator_version());
    d_put(manifest, "\",\n    \"contract_sha256\": \"");
    d_put(manifest, winmd_generator_contract_sha256());
    d_put(manifest, "\",\n    \"implementation_language\": \"OpenC\"\n  },\n");
    d_put(manifest, "  \"architecture\": \"x86_64\",\n  \"input_format\": {\n");
    d_put(manifest, "    \"pe_magic\": "); d_put_usize(manifest, reader.pe_magic);
    d_put(manifest, ",\n    \"metadata_bytes\": "); d_put_usize(manifest, reader.metadata_size);
    d_put(manifest, ",\n    \"tables_stream_bytes\": "); d_put_usize(manifest, reader.tables_size);
    d_put(manifest, ",\n    \"strings_heap_bytes\": "); d_put_usize(manifest, reader.strings_size);
    d_put(manifest, ",\n    \"blob_heap_bytes\": "); d_put_usize(manifest, reader.blob_size);
    d_put(manifest, ",\n    \"guid_heap_bytes\": "); d_put_usize(manifest, reader.guid_size);
    d_put(manifest, ",\n    \"heap_sizes_flags\": "); d_put_usize(manifest, reader.heap_sizes);
    d_put(manifest, "\n  },\n  \"table_rows\": {\n");
    winmd_put_json_stat(manifest, "TypeRef", winmd_table_count(reader, 1), true);
    winmd_put_json_stat(manifest, "TypeDef", winmd_table_count(reader, 2), true);
    winmd_put_json_stat(manifest, "Field", winmd_table_count(reader, 4), true);
    winmd_put_json_stat(manifest, "MethodDef", winmd_table_count(reader, 6), true);
    winmd_put_json_stat(manifest, "Param", winmd_table_count(reader, 8), true);
    winmd_put_json_stat(manifest, "InterfaceImpl", winmd_table_count(reader, 9), true);
    winmd_put_json_stat(manifest, "Constant", winmd_table_count(reader, 11), true);
    winmd_put_json_stat(manifest, "CustomAttribute", winmd_table_count(reader, 12), true);
    winmd_put_json_stat(manifest, "ClassLayout", winmd_table_count(reader, 15), true);
    winmd_put_json_stat(manifest, "FieldLayout", winmd_table_count(reader, 16), true);
    winmd_put_json_stat(manifest, "ModuleRef", winmd_table_count(reader, 26), true);
    winmd_put_json_stat(manifest, "ImplMap", winmd_table_count(reader, 28), true);
    winmd_put_json_stat(manifest, "NestedClass", winmd_table_count(reader, 41), false);
    d_put(manifest, "  },\n  \"recognized_attributes\": {\n");
    winmd_put_json_stat(manifest, "Documentation", attributes.documentation, true);
    winmd_put_json_stat(manifest, "SupportedArchitecture", attributes.supported_architecture, true);
    winmd_put_json_stat(manifest, "SupportedOSPlatform", attributes.supported_os, true);
    winmd_put_json_stat(manifest, "Ansi", attributes.ansi, true);
    winmd_put_json_stat(manifest, "Unicode", attributes.unicode, true);
    winmd_put_json_stat(manifest, "NativeArrayInfo", attributes.native_array, true);
    winmd_put_json_stat(manifest, "Retained", attributes.retained, true);
    winmd_put_json_stat(manifest, "RAIIFree", attributes.raii_free, true);
    winmd_put_json_stat(manifest, "FreeWith", attributes.free_with, true);
    winmd_put_json_stat(manifest, "InvalidHandleValue", attributes.invalid_handle, true);
    winmd_put_json_stat(manifest, "NativeTypedef", attributes.native_typedef, true);
    winmd_put_json_stat(manifest, "NativeBitfield", attributes.native_bitfield, true);
    winmd_put_json_stat(manifest, "Constant", attributes.constant, true);
    winmd_put_json_stat(manifest, "FlexibleArray", attributes.flexible_array, true);
    winmd_put_json_stat(manifest, "MemorySize", attributes.memory_size, true);
    winmd_put_json_stat(manifest, "StructSizeField", attributes.struct_size_field, false);
    d_put(manifest, "  },\n  \"modules\": [\n");
    usize module = 0;
    text hash_text = d_buffer_text(hashes);
    while module < winmd_module_count() {
        d_put(manifest, "    {\n      \"name\": \""); d_put(manifest, winmd_module_name(module));
        d_put(manifest, "\",\n      \"file\": \""); d_put(manifest, winmd_module_file_name(module));
        d_put(manifest, "\",\n      \"sha256\": \"");
        d_put_slice(manifest, hash_text, module * 65, 64);
        d_put(manifest, "\",\n");
        winmd_put_json_stat(manifest, "records", winmd_saved_stat(stats_data, module, 0), true);
        winmd_put_json_stat(manifest, "types", winmd_saved_stat(stats_data, module, 1), true);
        winmd_put_json_stat(manifest, "fields", winmd_saved_stat(stats_data, module, 2), true);
        winmd_put_json_stat(manifest, "methods", winmd_saved_stat(stats_data, module, 3), true);
        winmd_put_json_stat(manifest, "parameters", winmd_saved_stat(stats_data, module, 4), true);
        winmd_put_json_stat(manifest, "imports", winmd_saved_stat(stats_data, module, 5), true);
        winmd_put_json_stat(manifest, "constants", winmd_saved_stat(stats_data, module, 6), true);
        winmd_put_json_stat(manifest, "custom_attributes", winmd_saved_stat(stats_data, module, 7), true);
        winmd_put_json_stat(manifest, "class_layouts", winmd_saved_stat(stats_data, module, 8), true);
        winmd_put_json_stat(manifest, "field_layouts", winmd_saved_stat(stats_data, module, 9), false);
        d_put(manifest, "    }");
        if module + 1 < winmd_module_count() { d_put(manifest, ","); }
        d_put(manifest, "\n");
        module = module + 1;
    }
    d_put(manifest, "  ],\n  \"ordinary_build_parses_winmd\": false,\n");
    d_put(manifest, "  \"c_headers_parsed\": false,\n  \"third_party_metadata_library_used\": false\n}\n");
    file.write_text(output_path, d_buffer_text(manifest));
    d_buffer_destroy(manifest);
}

unsafe i32 emit_windows_winmd_projection(
    text input_path,
    text output_directory,
    text manifest_path
) {
    ptr byte input_data;
    usize input_length = 0;
    status read = file.read_bytes_raw(
        input_path, out input_data, out input_length
    );
    if !read.ok { io.error("unable to read pinned Windows.Win32.winmd\n"); return 1; }
    scope memory.free(input_data);
    DBuffer input_hash = d_buffer_create(65);
    winmd_sha256_hex(input_data, input_length, input_hash);
    if d_buffer_text(input_hash) != winmd_pinned_sha256() {
        io.error("Windows.Win32.winmd hash does not match the SH-17 pin\n");
        d_buffer_destroy(input_hash);
        return 1;
    }
    WinmdReader reader;
    status parsed = winmd_parse(input_data, input_length, out reader);
    if !parsed.ok { io.error(parsed.message); io.error("\n"); d_buffer_destroy(input_hash); return 1; }
    scope winmd_reader_destroy(reader);
    WinmdAttributeStats attributes = winmd_attribute_stats();
    usize attribute_row = 1;
    while attribute_row <= winmd_table_count(reader, 12) {
        winmd_count_attribute(reader, attribute_row, attributes);
        attribute_row = attribute_row + 1;
    }
    DBuffer hashes = d_buffer_create(winmd_module_count() * 65);
    ptr byte stats_data = memory.alloc(
        winmd_module_count() * 10 * size_of(usize)
    );
    scope memory.free(stats_data);
    usize module = 0;
    bool ok = true;
    while module < winmd_module_count() && ok {
        ok = winmd_emit_module(
            reader, module, output_directory, hashes, stats_data
        );
        module = module + 1;
    }
    if ok && reader.ok && hashes.ok {
        winmd_emit_manifest(
            reader, d_buffer_text(input_hash), manifest_path,
            hashes, stats_data, attributes
        );
    } else {
        io.error("SH-17 raw projection failed\n");
    }
    d_buffer_destroy(hashes);
    d_buffer_destroy(input_hash);
    if !ok || !reader.ok { return 1; }
    return 0;
}
