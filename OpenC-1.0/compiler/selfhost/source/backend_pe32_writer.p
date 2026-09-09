import system.file;

unsafe void pe32_put_u16(ref DBuffer output, usize value) {
    d_put_byte(output, cast(u8, value & 255));
    d_put_byte(output, cast(u8, (value >> 8) & 255));
}

unsafe void pe32_put_u32(ref DBuffer output, usize value) {
    usize shift = 0;
    while shift < 32 {
        d_put_byte(output, cast(u8, (value >> shift) & 255));
        shift = shift + 8;
    }
}

unsafe void pe32_put_u64(ref DBuffer output, u64 value) {
    usize shift = 0;
    while shift < 64 {
        d_put_byte(output, cast(u8, (value >> shift) & 255));
        shift = shift + 8;
    }
}

unsafe void pe32_patch_u32(
    ref DBuffer output,
    usize offset,
    usize value
) {
    if offset > output.length || output.length - offset < 4 {
        output.ok = false;
        return;
    }
    usize shift = 0;
    while shift < 32 {
        *(output.data + offset + shift / 8) = cast_unchecked(
            byte, cast(u8, (value >> shift) & 255)
        );
        shift = shift + 8;
    }
}

unsafe void pe32_pad_to(ref DBuffer output, usize offset) {
    if offset < output.length { output.ok = false; return; }
    while output.length < offset && output.ok { d_put_byte(output, 0); }
}

unsafe void pe32_put_fixed_name(ref DBuffer output, text name) {
    usize index = 0;
    while index < 8 {
        u8 value = 0;
        if index < text.byte_length(name) {
            value = byte_at_or_zero(name, index);
        }
        d_put_byte(output, value);
        index = index + 1;
    }
}

unsafe void pe32_put_ascii_z(ref DBuffer output, text value) {
    d_put(output, value);
    d_put_byte(output, 0);
}

unsafe void pe32_put_utf16_ascii_z(ref DBuffer output, text value) {
    usize index = 0;
    while index < text.byte_length(value) {
        pe32_put_u16(output, cast(usize, byte_at_or_zero(value, index)));
        index = index + 1;
    }
    pe32_put_u16(output, 0);
}

unsafe void pe32_put_data_directory(
    ref DBuffer output,
    usize rva,
    usize size
) {
    pe32_put_u32(output, rva);
    pe32_put_u32(output, size);
}

unsafe void pe32_put_section_header(
    ref DBuffer output,
    ref Pe32Section section
) {
    pe32_put_fixed_name(output, section.name);
    pe32_put_u32(output, section.virtual_size);
    pe32_put_u32(output, section.virtual_address);
    pe32_put_u32(output, section.raw_size);
    pe32_put_u32(output, section.raw_pointer);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 0);
    pe32_put_u16(output, 0);
    pe32_put_u16(output, 0);
    pe32_put_u32(output, section.characteristics);
}

unsafe DBuffer pe32_build_rdata(ref Pe32RuntimeLayout layout) {
    DBuffer output = d_buffer_create(1536);
    pe32_put_u32(output, layout.rdata_rva + layout.import_lookup_offset);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, layout.rdata_rva + layout.import_dll_name_offset);
    pe32_put_u32(output, layout.rdata_rva + layout.import_address_offset);
    usize null_descriptor = 0;
    while null_descriptor < 20 {
        d_put_byte(output, 0);
        null_descriptor = null_descriptor + 1;
    }
    pe32_pad_to(output, layout.import_lookup_offset);
    usize import_index = 0;
    while import_index < pe32_import_count() {
        pe32_put_u64(
            output,
            cast(u64, layout.rdata_rva + pe32_import_hint_offset(
                layout, import_index
            ))
        );
        import_index = import_index + 1;
    }
    pe32_put_u64(output, cast(u64, 0));
    pe32_pad_to(output, layout.import_address_offset);
    import_index = 0;
    while import_index < pe32_import_count() {
        pe32_put_u64(
            output,
            cast(u64, layout.rdata_rva + pe32_import_hint_offset(
                layout, import_index
            ))
        );
        import_index = import_index + 1;
    }
    pe32_put_u64(output, cast(u64, 0));
    pe32_pad_to(output, layout.import_dll_name_offset);
    pe32_put_ascii_z(output, "KERNEL32.dll");
    pe32_pad_to(output, layout.import_names_offset);
    import_index = 0;
    while import_index < pe32_import_count() {
        pe32_put_u16(output, 0);
        pe32_put_ascii_z(output, pe32_import_name(import_index));
        pe32_pad_to(output, x64_align_up(output.length, 2));
        import_index = import_index + 1;
    }
    pe32_pad_to(output, layout.message_offset);
    d_put(output, "OpenC SH-16 CRT-free runtime PASS\n");
    pe32_pad_to(output, layout.file_name_offset);
    pe32_put_utf16_ascii_z(output, "openc-sh16-proof.txt");
    pe32_pad_to(output, layout.file_payload_offset);
    d_put(output, "OpenC native file PASS\n");
    pe32_pad_to(output, layout.panic_message_offset);
    d_put(output, "OpenC SH-16 runtime panic\n");
    pe32_pad_to(output, layout.tls_directory_offset);
    pe32_put_u64(output, layout.image_base + cast(u64, layout.tls_rva));
    pe32_put_u64(output, layout.image_base + cast(u64, layout.tls_rva + 8));
    pe32_put_u64(output, layout.image_base + cast(u64, layout.data_rva + 8));
    pe32_put_u64(output, cast(u64, 0));
    pe32_put_u32(output, 8);
    pe32_put_u32(output, 0);
    pe32_pad_to(output, 1536);
    return output;
}

unsafe DBuffer pe32_build_data(ref Pe32RuntimeLayout layout) {
    DBuffer output = d_buffer_create(512);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 0);
    pe32_pad_to(output, 24);
    pe32_put_u64(output, layout.image_base + cast(u64, layout.text_rva));
    pe32_pad_to(output, 512);
    return output;
}

unsafe DBuffer pe32_build_tls() {
    DBuffer output = d_buffer_create(512);
    pe32_put_u64(output, cast(u64, 0));
    pe32_pad_to(output, 512);
    return output;
}

unsafe DBuffer pe32_build_relocations(ref Pe32RuntimeLayout layout) {
    DBuffer output = d_buffer_create(512);
    pe32_put_u32(output, layout.rdata_rva);
    pe32_put_u32(output, 16);
    pe32_put_u16(output, 40960 + layout.tls_directory_offset);
    pe32_put_u16(output, 40960 + layout.tls_directory_offset + 8);
    pe32_put_u16(output, 40960 + layout.tls_directory_offset + 16);
    pe32_put_u16(output, 0);
    pe32_put_u32(output, layout.data_rva);
    pe32_put_u32(output, 12);
    pe32_put_u16(output, 40960 + 24);
    pe32_put_u16(output, 0);
    pe32_pad_to(output, 512);
    return output;
}

unsafe DBuffer pe32_build_pdata(
    ref Pe32RuntimeLayout layout,
    usize entry_size,
    usize panic_offset,
    usize panic_size
) {
    DBuffer output = d_buffer_create(512);
    pe32_put_u32(output, layout.text_rva);
    pe32_put_u32(output, layout.text_rva + entry_size);
    pe32_put_u32(output, layout.xdata_rva);
    pe32_put_u32(output, layout.text_rva + panic_offset);
    pe32_put_u32(output, layout.text_rva + panic_offset + panic_size);
    pe32_put_u32(output, layout.xdata_rva + 8);
    pe32_pad_to(output, 512);
    return output;
}

unsafe DBuffer pe32_build_xdata() {
    DBuffer output = d_buffer_create(512);
    d_put_byte(output, 1); d_put_byte(output, 4);
    d_put_byte(output, 1); d_put_byte(output, 0);
    d_put_byte(output, 4); d_put_byte(output, 194);
    d_put_byte(output, 0); d_put_byte(output, 0);
    d_put_byte(output, 1); d_put_byte(output, 4);
    d_put_byte(output, 1); d_put_byte(output, 0);
    d_put_byte(output, 4); d_put_byte(output, 66);
    d_put_byte(output, 0); d_put_byte(output, 0);
    pe32_pad_to(output, 512);
    return output;
}

unsafe DBuffer pe32_build_headers(
    ref Pe32RuntimeLayout layout,
    usize subsystem,
    ref Pe32Section text_section,
    ref Pe32Section rdata_section,
    ref Pe32Section data_section,
    ref Pe32Section pdata_section,
    ref Pe32Section xdata_section,
    ref Pe32Section tls_section,
    ref Pe32Section reloc_section
) {
    DBuffer output = d_buffer_create(layout.headers_size);
    d_put_byte(output, 77); d_put_byte(output, 90);
    pe32_pad_to(output, 60);
    pe32_put_u32(output, 128);
    pe32_pad_to(output, 128);
    d_put(output, "PE"); d_put_byte(output, 0); d_put_byte(output, 0);
    pe32_put_u16(output, 34404);
    pe32_put_u16(output, 7);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 0);
    pe32_put_u16(output, 240);
    pe32_put_u16(output, 34);
    pe32_put_u16(output, 523);
    d_put_byte(output, 1); d_put_byte(output, 0);
    pe32_put_u32(output, text_section.raw_size);
    pe32_put_u32(
        output,
        rdata_section.raw_size + data_section.raw_size +
            pdata_section.raw_size + xdata_section.raw_size +
            tls_section.raw_size + reloc_section.raw_size
    );
    pe32_put_u32(output, 0);
    pe32_put_u32(output, layout.text_rva);
    pe32_put_u32(output, layout.text_rva);
    pe32_put_u64(output, layout.image_base);
    pe32_put_u32(output, layout.section_alignment);
    pe32_put_u32(output, layout.file_alignment);
    pe32_put_u16(output, 6); pe32_put_u16(output, 0);
    pe32_put_u16(output, 0); pe32_put_u16(output, 0);
    pe32_put_u16(output, 6); pe32_put_u16(output, 0);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, layout.image_size);
    pe32_put_u32(output, layout.headers_size);
    pe32_put_u32(output, 0);
    pe32_put_u16(output, subsystem);
    pe32_put_u16(output, 33120);
    // The bootstrap compiler currently uses SSA spill frames for every value.
    // Reserve enough virtual stack for its deepest parser/resolution paths;
    // Windows commits this on demand rather than allocating 64 MiB eagerly.
    pe32_put_u64(output, cast(u64, 67108864));
    pe32_put_u64(output, cast(u64, 1048576));
    pe32_put_u64(output, cast(u64, 1048576));
    pe32_put_u64(output, cast(u64, 4096));
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 16);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, layout.rdata_rva, 40);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, layout.pdata_rva, 24);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, layout.reloc_rva, 28);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(
        output, layout.rdata_rva + layout.tls_directory_offset, 40
    );
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(
        output, layout.rdata_rva + layout.import_address_offset,
        (pe32_import_count() + 1) * 8
    );
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_section_header(output, text_section);
    pe32_put_section_header(output, rdata_section);
    pe32_put_section_header(output, data_section);
    pe32_put_section_header(output, pdata_section);
    pe32_put_section_header(output, xdata_section);
    pe32_put_section_header(output, tls_section);
    pe32_put_section_header(output, reloc_section);
    pe32_pad_to(output, layout.headers_size);
    return output;
}
