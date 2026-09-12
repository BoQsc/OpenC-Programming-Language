import system.text;

unsafe DBuffer pe32_build_artifact_headers(
    ref Pe32RuntimeLayout layout,
    usize subsystem,
    bool dll,
    ref Pe32Section text_section,
    ref Pe32Section rdata_section,
    ref Pe32Section data_section,
    ref Pe32Section pdata_section,
    ref Pe32Section xdata_section,
    ref Pe32Section tls_section,
    ref Pe32Section reloc_section,
    bool has_edata,
    ref Pe32Section edata_section,
    usize export_size,
    bool has_rsrc,
    ref Pe32Section rsrc_section,
    usize resource_size,
    usize exception_size
) {
    usize section_count = 7;
    if has_edata { section_count = section_count + 1; }
    if has_rsrc { section_count = section_count + 1; }
    DBuffer output = d_buffer_create(layout.headers_size);
    d_put_byte(output, 77);
    d_put_byte(output, 90);
    pe32_pad_to(output, 60);
    pe32_put_u32(output, 128);
    pe32_pad_to(output, 128);
    d_put(output, "PE");
    d_put_byte(output, 0);
    d_put_byte(output, 0);
    pe32_put_u16(output, 34404);
    pe32_put_u16(output, section_count);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 0);
    pe32_put_u16(output, 240);
    usize characteristics = 34;
    if dll { characteristics = 8226; }
    pe32_put_u16(output, characteristics);
    pe32_put_u16(output, 523);
    d_put_byte(output, 1);
    d_put_byte(output, 0);
    pe32_put_u32(output, text_section.raw_size);
    pe32_put_u32(
        output,
        rdata_section.raw_size + data_section.raw_size +
            pdata_section.raw_size + xdata_section.raw_size +
            tls_section.raw_size + reloc_section.raw_size +
            edata_section.raw_size + rsrc_section.raw_size
    );
    pe32_put_u32(output, 0);
    pe32_put_u32(output, layout.text_rva);
    pe32_put_u32(output, layout.text_rva);
    pe32_put_u64(output, layout.image_base);
    pe32_put_u32(output, layout.section_alignment);
    pe32_put_u32(output, layout.file_alignment);
    pe32_put_u16(output, 6);
    pe32_put_u16(output, 0);
    pe32_put_u16(output, 0);
    pe32_put_u16(output, 0);
    pe32_put_u16(output, 6);
    pe32_put_u16(output, 0);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, layout.image_size);
    pe32_put_u32(output, layout.headers_size);
    pe32_put_u32(output, 0);
    pe32_put_u16(output, subsystem);
    pe32_put_u16(output, 33120);
    pe32_put_u64(output, cast(u64, 67108864));
    pe32_put_u64(output, cast(u64, 1048576));
    pe32_put_u64(output, cast(u64, 1048576));
    pe32_put_u64(output, cast(u64, 4096));
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 16);
    if has_edata {
        pe32_put_data_directory(
            output, edata_section.virtual_address, export_size
        );
    } else {
        pe32_put_data_directory(output, 0, 0);
    }
    pe32_put_data_directory(output, layout.rdata_rva, 40);
    if has_rsrc {
        pe32_put_data_directory(
            output, rsrc_section.virtual_address, resource_size
        );
    } else {
        pe32_put_data_directory(output, 0, 0);
    }
    pe32_put_data_directory(output, layout.pdata_rva, exception_size);
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
        output,
        layout.rdata_rva + layout.import_address_offset,
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
    if has_edata { pe32_put_section_header(output, edata_section); }
    if has_rsrc { pe32_put_section_header(output, rsrc_section); }
    pe32_pad_to(output, layout.headers_size);
    return output;
}
