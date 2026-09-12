import system.file;
import system.io;
import system.memory;
import system.path;

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
    usize input_length;
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
