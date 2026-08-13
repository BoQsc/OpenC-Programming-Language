struct Pe32Section {
    text name;
    usize virtual_size;
    usize virtual_address;
    usize raw_size;
    usize raw_pointer;
    usize characteristics;
}

struct Pe32RuntimeLayout {
    u64 image_base;
    usize file_alignment;
    usize section_alignment;
    usize headers_size;
    usize text_rva;
    usize rdata_rva;
    usize data_rva;
    usize pdata_rva;
    usize xdata_rva;
    usize tls_rva;
    usize reloc_rva;
    usize image_size;
    usize import_directory_offset;
    usize import_lookup_offset;
    usize import_address_offset;
    usize import_dll_name_offset;
    usize import_names_offset;
    usize message_offset;
    usize file_name_offset;
    usize file_payload_offset;
    usize panic_message_offset;
    usize tls_directory_offset;
}

struct Pe32RuntimeImage {
    DBuffer image;
    usize entry_size;
    usize panic_offset;
    usize panic_size;
    usize subsystem;
    bool ok;
}

Pe32RuntimeLayout pe32_runtime_layout() {
    return Pe32RuntimeLayout{
        image_base = cast(u64, 5368709120),
        file_alignment = 512,
        section_alignment = 4096,
        headers_size = 1024,
        text_rva = 4096,
        rdata_rva = 8192,
        data_rva = 12288,
        pdata_rva = 16384,
        xdata_rva = 20480,
        tls_rva = 24576,
        reloc_rva = 28672,
        image_size = 32768,
        import_directory_offset = 0,
        import_lookup_offset = 64,
        import_address_offset = 192,
        import_dll_name_offset = 336,
        import_names_offset = 368,
        message_offset = 1024,
        file_name_offset = 1152,
        file_payload_offset = 1216,
        panic_message_offset = 1280,
        tls_directory_offset = 1408
    };
}

usize pe32_subsystem_windows_gui() { return 2; }
usize pe32_subsystem_windows_console() { return 3; }

usize pe32_section_code() { return 1610612768; }
usize pe32_section_read_only_data() { return 1073741888; }
usize pe32_section_read_write_data() { return 3221225536; }

usize pe32_import_count() { return 15; }

text pe32_import_name(usize index) {
    if index == 0 { return "CloseHandle"; }
    if index == 1 { return "CreateFileW"; }
    if index == 2 { return "ExitProcess"; }
    if index == 3 { return "FreeEnvironmentStringsW"; }
    if index == 4 { return "GetCommandLineW"; }
    if index == 5 { return "GetEnvironmentStringsW"; }
    if index == 6 { return "GetLastError"; }
    if index == 7 { return "GetProcessHeap"; }
    if index == 8 { return "GetStdHandle"; }
    if index == 9 { return "HeapAlloc"; }
    if index == 10 { return "HeapFree"; }
    if index == 11 { return "HeapReAlloc"; }
    if index == 12 { return "ReadFile"; }
    if index == 13 { return "WideCharToMultiByte"; }
    return "WriteFile";
}

usize pe32_import_hint_offset(ref Pe32RuntimeLayout layout, usize index) {
    usize offset = layout.import_names_offset;
    usize current = 0;
    while current < index {
        offset = x64_align_up(
            offset + 2 + text.byte_length(pe32_import_name(current)) + 1,
            2
        );
        current = current + 1;
    }
    return offset;
}

usize pe32_import_iat_rva(
    ref Pe32RuntimeLayout layout,
    usize index
) {
    return layout.rdata_rva + layout.import_address_offset + index * 8;
}
