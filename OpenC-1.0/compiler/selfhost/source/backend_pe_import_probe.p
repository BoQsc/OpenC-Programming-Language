import system.file;
import system.text;

unsafe void pe32_import_probe_call(
    ref X64Code code,
    usize text_rva,
    usize target_iat_rva
) {
    x64_emit_u8(code, 255);
    x64_emit_u8(code, 21);
    usize displacement = code.bytes.length;
    x64_emit_u32(code, 0);
    i64 delta = cast(i64, target_iat_rva) -
        cast(i64, text_rva + displacement + 4);
    u32 encoded = 0;
    if delta < 0 {
        encoded = cast(u32, cast(u64, 4294967296) -
            cast(u64, 0 - delta));
    } else {
        encoded = cast(u32, delta);
    }
    x64_patch_u32(code, displacement, encoded);
}

unsafe DBuffer pe32_build_import_probe_rdata(text dll_name) {
    usize rva = 8192;
    DBuffer output = d_buffer_create(512);
    // KERNEL32.dll: ExitProcess.
    pe32_put_u32(output, rva + 64);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, rva + 128);
    pe32_put_u32(output, rva + 96);
    // The OpenC DLL: openc_add.
    pe32_put_u32(output, rva + 80);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, rva + 144);
    pe32_put_u32(output, rva + 112);
    pe32_pad_to(output, 60);
    pe32_put_u32(output, 0);
    pe32_pad_to(output, 64);
    pe32_put_u64(output, cast(u64, rva + 192));
    pe32_put_u64(output, cast(u64, 0));
    pe32_put_u64(output, cast(u64, rva + 224));
    pe32_put_u64(output, cast(u64, 0));
    pe32_pad_to(output, 96);
    pe32_put_u64(output, cast(u64, rva + 192));
    pe32_put_u64(output, cast(u64, 0));
    pe32_put_u64(output, cast(u64, rva + 224));
    pe32_put_u64(output, cast(u64, 0));
    pe32_pad_to(output, 128);
    pe32_put_ascii_z(output, "KERNEL32.dll");
    pe32_pad_to(output, 144);
    pe32_put_ascii_z(output, dll_name);
    pe32_pad_to(output, 192);
    pe32_put_u16(output, 0);
    pe32_put_ascii_z(output, "ExitProcess");
    pe32_pad_to(output, 224);
    pe32_put_u16(output, 0);
    pe32_put_ascii_z(output, "openc_add");
    pe32_pad_to(output, 512);
    return output;
}

unsafe DBuffer pe32_build_import_probe_headers(
    ref Pe32Section text_section,
    ref Pe32Section rdata_section
) {
    DBuffer output = d_buffer_create(512);
    d_put_byte(output, 77);
    d_put_byte(output, 90);
    pe32_pad_to(output, 60);
    pe32_put_u32(output, 128);
    pe32_pad_to(output, 128);
    d_put(output, "PE");
    d_put_byte(output, 0);
    d_put_byte(output, 0);
    pe32_put_u16(output, 34404);
    pe32_put_u16(output, 2);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 0);
    pe32_put_u16(output, 240);
    pe32_put_u16(output, 34);
    pe32_put_u16(output, 523);
    d_put_byte(output, 1);
    d_put_byte(output, 0);
    pe32_put_u32(output, text_section.raw_size);
    pe32_put_u32(output, rdata_section.raw_size);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, text_section.virtual_address);
    pe32_put_u32(output, text_section.virtual_address);
    pe32_put_u64(output, cast(u64, 5368709120));
    pe32_put_u32(output, 4096);
    pe32_put_u32(output, 512);
    pe32_put_u16(output, 6);
    pe32_put_u16(output, 0);
    pe32_put_u16(output, 0);
    pe32_put_u16(output, 0);
    pe32_put_u16(output, 6);
    pe32_put_u16(output, 0);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 12288);
    pe32_put_u32(output, 512);
    pe32_put_u32(output, 0);
    pe32_put_u16(output, pe32_subsystem_windows_console());
    pe32_put_u16(output, 33120);
    pe32_put_u64(output, cast(u64, 67108864));
    pe32_put_u64(output, cast(u64, 1048576));
    pe32_put_u64(output, cast(u64, 1048576));
    pe32_put_u64(output, cast(u64, 4096));
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 16);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, 8192, 60);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, cast(usize, 8304), 16);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_data_directory(output, 0, 0);
    pe32_put_section_header(output, text_section);
    pe32_put_section_header(output, rdata_section);
    pe32_pad_to(output, 512);
    return output;
}

unsafe status pe32_write_import_probe(text path, text dll_name) {
    if text.byte_length(dll_name) == 0 ||
        text.byte_length(dll_name) > 47 {
        return status{ code = 1 };
    }
    X64Code code = x64_code_create(128, 1);
    x64_sub_rsp(code, 40);
    x64_mov_r64_imm64(code, 1, cast(u64, 20));
    x64_mov_r64_imm64(code, 2, cast(u64, 22));
    pe32_import_probe_call(code, 4096, cast(usize, 8304));
    x64_mov_r64_r64(code, 1, 0);
    pe32_import_probe_call(code, 4096, cast(usize, 8288));
    x64_ret(code);
    Pe32Section text_section = Pe32Section{
        name = ".text", virtual_size = code.bytes.length,
        virtual_address = 4096, raw_size = 512, raw_pointer = 512,
        characteristics = pe32_section_code()
    };
    Pe32Section rdata_section = Pe32Section{
        name = ".rdata", virtual_size = 512,
        virtual_address = 8192, raw_size = 512, raw_pointer = 1024,
        characteristics = pe32_section_read_only_data()
    };
    DBuffer headers = pe32_build_import_probe_headers(
        text_section, rdata_section
    );
    DBuffer rdata = pe32_build_import_probe_rdata(dll_name);
    DBuffer image = d_buffer_create(1536);
    x64_copy_bytes(image, headers);
    x64_copy_bytes(image, code.bytes);
    pe32_pad_to(image, 1024);
    x64_copy_bytes(image, rdata);
    status written = status{ code = 1 };
    if code.ok && headers.ok && rdata.ok && image.ok {
        written = file.write_bytes(path, image.data, image.length);
    }
    d_buffer_destroy(image);
    d_buffer_destroy(rdata);
    d_buffer_destroy(headers);
    x64_code_destroy(code);
    return written;
}
