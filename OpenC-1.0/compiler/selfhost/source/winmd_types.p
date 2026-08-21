struct WinmdReader {
    ptr byte data;
    usize length;
    usize pe_magic;
    usize metadata_offset;
    usize metadata_size;
    usize tables_offset;
    usize tables_size;
    usize strings_offset;
    usize strings_size;
    usize blob_offset;
    usize blob_size;
    usize guid_offset;
    usize guid_size;
    usize heap_sizes;
    u64 valid_tables;
    PackedBuffer tables;
    ptr byte table_data;
    bool ok;
}

struct WinmdProjectionStats {
    usize records;
    usize types;
    usize fields;
    usize methods;
    usize parameters;
    usize imports;
    usize constants;
    usize custom_attributes;
    usize class_layouts;
    usize field_layouts;
}

struct WinmdAttributeStats {
    usize documentation;
    usize supported_architecture;
    usize supported_os;
    usize ansi;
    usize unicode;
    usize native_array;
    usize retained;
    usize raii_free;
    usize free_with;
    usize invalid_handle;
    usize native_typedef;
    usize native_bitfield;
    usize constant;
    usize flexible_array;
    usize memory_size;
    usize struct_size_field;
}

struct WinmdSha256 {
    u32 a;
    u32 b;
    u32 c;
    u32 d;
    u32 e;
    u32 f;
    u32 g;
    u32 h;
}

usize winmd_table_module() { return 0; }
usize winmd_table_type_ref() { return 1; }
usize winmd_table_type_def() { return 2; }
usize winmd_table_field() { return 4; }
usize winmd_table_method_def() { return 6; }
usize winmd_table_param() { return 8; }
usize winmd_table_interface_impl() { return 9; }
usize winmd_table_member_ref() { return 10; }
usize winmd_table_constant() { return 11; }
usize winmd_table_custom_attribute() { return 12; }
usize winmd_table_class_layout() { return 15; }
usize winmd_table_field_layout() { return 16; }
usize winmd_table_module_ref() { return 26; }
usize winmd_table_impl_map() { return 28; }
usize winmd_table_assembly() { return 32; }
usize winmd_table_assembly_ref() { return 35; }
usize winmd_table_nested_class() { return 41; }

usize winmd_module_foundation() { return 0; }
usize winmd_module_file() { return 1; }
usize winmd_module_memory() { return 2; }
usize winmd_module_process() { return 3; }
usize winmd_module_thread() { return 4; }
usize winmd_module_window() { return 5; }
usize winmd_module_graphics() { return 6; }
usize winmd_module_count() { return 7; }
usize winmd_module_none() { return 7; }

text winmd_module_name(usize module) {
    if module == winmd_module_foundation() { return "foundation"; }
    if module == winmd_module_file() { return "file"; }
    if module == winmd_module_memory() { return "memory"; }
    if module == winmd_module_process() { return "process"; }
    if module == winmd_module_thread() { return "thread"; }
    if module == winmd_module_window() { return "window"; }
    return "graphics";
}

text winmd_module_file_name(usize module) {
    if module == winmd_module_foundation() { return "windows.raw.foundation.p"; }
    if module == winmd_module_file() { return "windows.raw.file.p"; }
    if module == winmd_module_memory() { return "windows.raw.memory.p"; }
    if module == winmd_module_process() { return "windows.raw.process.p"; }
    if module == winmd_module_thread() { return "windows.raw.thread.p"; }
    if module == winmd_module_window() { return "windows.raw.window.p"; }
    return "windows.raw.graphics.p";
}

text winmd_pinned_package_version() { return "71.0.14-preview"; }

text winmd_pinned_sha256() {
    return "b64ee4818a7ed9f9d135038d58c51bd08369184d4d5ed428f20e9de55df8121d";
}

text winmd_generator_version() { return "openc-winmd-projector-sh17.1"; }

text winmd_generator_contract_sha256() {
    return "ddeac4fc218497a63e2f30edb6ae1e6056c2a6463cc3eee93360fe9d56673bb7";
}
