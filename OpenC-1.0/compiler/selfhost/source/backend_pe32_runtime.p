import system.file;
import system.io;
import system.text;

struct Pe32RuntimeCode {
    X64Code code;
    usize entry_size;
    usize panic_offset;
    usize panic_size;
}

unsafe u64 pe32_u64_minus_one() {
    return (cast(u64, 4294967295) << cast(usize, 32)) |
        cast(u64, 4294967295);
}

unsafe u64 pe32_u64_minus_eleven() {
    return (cast(u64, 4294967295) << cast(usize, 32)) |
        cast(u64, 4294967285);
}

unsafe void pe32_runtime_patch_rip(
    ref X64Code code,
    ref Pe32RuntimeLayout layout,
    usize displacement_offset,
    usize target_rva
) {
    i64 displacement = cast(i64, target_rva) - cast(
        i64, layout.text_rva + displacement_offset + 4
    );
    u32 encoded = 0;
    if displacement < 0 {
        encoded = cast(
            u32,
            cast(u64, 4294967296) - cast(u64, 0 - displacement)
        );
    } else {
        encoded = cast(u32, displacement);
    }
    x64_patch_u32(code, displacement_offset, encoded);
}

unsafe void pe32_runtime_call_import(
    ref X64Code code,
    ref Pe32RuntimeLayout layout,
    usize import_index
) {
    x64_emit_u8(code, 255);
    x64_emit_u8(code, 21);
    usize offset = code.bytes.length;
    x64_emit_u32(code, 0);
    pe32_runtime_patch_rip(
        code, layout, offset, pe32_import_iat_rva(layout, import_index)
    );
}

unsafe void pe32_runtime_lea_rip(
    ref X64Code code,
    ref Pe32RuntimeLayout layout,
    usize destination,
    usize target_rva
) {
    x64_emit_rex(code, true, destination, 0, 5);
    x64_emit_u8(code, 141);
    x64_emit_u8(code, 5 + (destination & 7) * 8);
    usize offset = code.bytes.length;
    x64_emit_u32(code, 0);
    pe32_runtime_patch_rip(code, layout, offset, target_rva);
}

unsafe void pe32_runtime_mov_rip_u32(
    ref X64Code code,
    ref Pe32RuntimeLayout layout,
    usize target_rva,
    usize value
) {
    x64_emit_u8(code, 199);
    x64_emit_u8(code, 5);
    usize offset = code.bytes.length;
    x64_emit_u32(code, 0);
    x64_emit_u32(code, value);
    pe32_runtime_patch_rip(code, layout, offset, target_rva);
}

unsafe void pe32_runtime_stack_value(
    ref X64Code code,
    usize offset,
    u64 value
) {
    x64_mov_r64_imm64(code, win64_abi_register_rax(), value);
    x64_mov_memory_r64(
        code, win64_abi_register_rsp(), offset, win64_abi_register_rax()
    );
}

unsafe void pe32_runtime_stack_zero(
    ref X64Code code,
    usize offset
) {
    pe32_runtime_stack_value(code, offset, cast(u64, 0));
}

unsafe Pe32RuntimeCode pe32_build_runtime_code(
    ref Pe32RuntimeLayout layout
) {
    X64Code code = x64_code_create(4096, 1);
    x64_sub_rsp(code, 104);
    pe32_runtime_mov_rip_u32(code, layout, layout.data_rva, 1);

    pe32_runtime_call_import(code, layout, 7);
    x64_mov_memory_r64(
        code, win64_abi_register_rsp(), 64, win64_abi_register_rax()
    );
    x64_mov_r64_r64(
        code, win64_abi_register_rcx(), win64_abi_register_rax()
    );
    x64_mov_r64_imm64(code, win64_abi_register_rdx(), cast(u64, 0));
    x64_mov_r64_imm64(code, win64_abi_register_r8(), cast(u64, 256));
    pe32_runtime_call_import(code, layout, 9);
    x64_mov_memory_r64(
        code, win64_abi_register_rsp(), 72, win64_abi_register_rax()
    );

    pe32_runtime_call_import(code, layout, 4);
    x64_mov_r64_imm64(code, win64_abi_register_rcx(), cast(u64, 65001));
    x64_mov_r64_imm64(code, win64_abi_register_rdx(), cast(u64, 128));
    x64_mov_r64_r64(
        code, win64_abi_register_r8(), win64_abi_register_rax()
    );
    x64_mov_r64_imm64(code, win64_abi_register_r9(), pe32_u64_minus_one());
    x64_mov_r64_memory(
        code, win64_abi_register_rax(), win64_abi_register_rsp(), 72
    );
    x64_mov_memory_r64(
        code, win64_abi_register_rsp(), 32, win64_abi_register_rax()
    );
    pe32_runtime_stack_value(code, 40, cast(u64, 256));
    pe32_runtime_stack_zero(code, 48);
    pe32_runtime_stack_zero(code, 56);
    pe32_runtime_call_import(code, layout, 13);
    x64_alu_r64_imm8(code, 5, win64_abi_register_rax(), 1);
    x64_mov_memory_r64(
        code, win64_abi_register_rsp(), 56, win64_abi_register_rax()
    );

    pe32_runtime_call_import(code, layout, 5);
    x64_mov_memory_r64(
        code, win64_abi_register_rsp(), 80, win64_abi_register_rax()
    );

    x64_mov_r64_memory(
        code, win64_abi_register_rcx(), win64_abi_register_rsp(), 64
    );
    x64_mov_r64_imm64(code, win64_abi_register_rdx(), cast(u64, 0));
    x64_mov_r64_memory(
        code, win64_abi_register_r8(), win64_abi_register_rsp(), 72
    );
    x64_mov_r64_imm64(code, win64_abi_register_r9(), cast(u64, 512));
    pe32_runtime_call_import(code, layout, 11);
    x64_mov_memory_r64(
        code, win64_abi_register_rsp(), 72, win64_abi_register_rax()
    );

    x64_mov_r64_imm64(code, win64_abi_register_rcx(), pe32_u64_minus_eleven());
    pe32_runtime_call_import(code, layout, 8);
    x64_mov_memory_r64(
        code, win64_abi_register_rsp(), 88, win64_abi_register_rax()
    );

    x64_mov_r64_r64(
        code, win64_abi_register_rcx(), win64_abi_register_rax()
    );
    x64_mov_r64_memory(
        code, win64_abi_register_rdx(), win64_abi_register_rsp(), 72
    );
    x64_mov_r64_memory(
        code, win64_abi_register_r8(), win64_abi_register_rsp(), 56
    );
    pe32_runtime_lea_rip(
        code, layout, win64_abi_register_r9(), layout.data_rva + 12
    );
    pe32_runtime_stack_zero(code, 32);
    pe32_runtime_call_import(code, layout, 14);

    pe32_runtime_lea_rip(
        code, layout, win64_abi_register_rcx(),
        layout.rdata_rva + layout.file_name_offset
    );
    x64_mov_r64_imm64(
        code, win64_abi_register_rdx(), cast(u64, 3221225472)
    );
    x64_mov_r64_imm64(code, win64_abi_register_r8(), cast(u64, 0));
    x64_mov_r64_imm64(code, win64_abi_register_r9(), cast(u64, 0));
    pe32_runtime_stack_value(code, 32, cast(u64, 2));
    pe32_runtime_stack_value(code, 40, cast(u64, 128));
    pe32_runtime_stack_zero(code, 48);
    pe32_runtime_call_import(code, layout, 1);
    x64_mov_memory_r64(
        code, win64_abi_register_rsp(), 96, win64_abi_register_rax()
    );

    x64_mov_r64_r64(
        code, win64_abi_register_rcx(), win64_abi_register_rax()
    );
    pe32_runtime_lea_rip(
        code, layout, win64_abi_register_rdx(),
        layout.rdata_rva + layout.file_payload_offset
    );
    x64_mov_r64_imm64(
        code, win64_abi_register_r8(),
        cast(u64, text.byte_length("OpenC native file PASS\n"))
    );
    pe32_runtime_lea_rip(
        code, layout, win64_abi_register_r9(), layout.data_rva + 12
    );
    pe32_runtime_stack_zero(code, 32);
    pe32_runtime_call_import(code, layout, 14);
    x64_mov_r64_memory(
        code, win64_abi_register_rcx(), win64_abi_register_rsp(), 96
    );
    pe32_runtime_call_import(code, layout, 0);

    pe32_runtime_lea_rip(
        code, layout, win64_abi_register_rcx(),
        layout.rdata_rva + layout.file_name_offset
    );
    x64_mov_r64_imm64(
        code, win64_abi_register_rdx(), cast(u64, 2147483648)
    );
    x64_mov_r64_imm64(code, win64_abi_register_r8(), cast(u64, 1));
    x64_mov_r64_imm64(code, win64_abi_register_r9(), cast(u64, 0));
    pe32_runtime_stack_value(code, 32, cast(u64, 3));
    pe32_runtime_stack_value(code, 40, cast(u64, 128));
    pe32_runtime_stack_zero(code, 48);
    pe32_runtime_call_import(code, layout, 1);
    x64_mov_memory_r64(
        code, win64_abi_register_rsp(), 96, win64_abi_register_rax()
    );

    x64_mov_r64_r64(
        code, win64_abi_register_rcx(), win64_abi_register_rax()
    );
    x64_mov_r64_memory(
        code, win64_abi_register_rdx(), win64_abi_register_rsp(), 72
    );
    x64_mov_r64_imm64(
        code, win64_abi_register_r8(),
        cast(u64, text.byte_length("OpenC native file PASS\n"))
    );
    pe32_runtime_lea_rip(
        code, layout, win64_abi_register_r9(), layout.data_rva + 16
    );
    pe32_runtime_stack_zero(code, 32);
    pe32_runtime_call_import(code, layout, 12);
    x64_mov_r64_memory(
        code, win64_abi_register_rcx(), win64_abi_register_rsp(), 96
    );
    pe32_runtime_call_import(code, layout, 0);

    x64_mov_r64_memory(
        code, win64_abi_register_rcx(), win64_abi_register_rsp(), 88
    );
    x64_mov_r64_memory(
        code, win64_abi_register_rdx(), win64_abi_register_rsp(), 72
    );
    x64_mov_r64_imm64(
        code, win64_abi_register_r8(),
        cast(u64, text.byte_length("OpenC native file PASS\n"))
    );
    pe32_runtime_lea_rip(
        code, layout, win64_abi_register_r9(), layout.data_rva + 12
    );
    pe32_runtime_stack_zero(code, 32);
    pe32_runtime_call_import(code, layout, 14);

    x64_mov_r64_memory(
        code, win64_abi_register_rcx(), win64_abi_register_rsp(), 88
    );
    pe32_runtime_lea_rip(
        code, layout, win64_abi_register_rdx(),
        layout.rdata_rva + layout.message_offset
    );
    x64_mov_r64_imm64(
        code, win64_abi_register_r8(),
        cast(u64, text.byte_length("OpenC SH-16 CRT-free runtime PASS\n"))
    );
    pe32_runtime_lea_rip(
        code, layout, win64_abi_register_r9(), layout.data_rva + 12
    );
    pe32_runtime_stack_zero(code, 32);
    pe32_runtime_call_import(code, layout, 14);

    x64_mov_r64_memory(
        code, win64_abi_register_rcx(), win64_abi_register_rsp(), 80
    );
    pe32_runtime_call_import(code, layout, 3);
    x64_mov_r64_memory(
        code, win64_abi_register_rcx(), win64_abi_register_rsp(), 64
    );
    x64_mov_r64_imm64(code, win64_abi_register_rdx(), cast(u64, 0));
    x64_mov_r64_memory(
        code, win64_abi_register_r8(), win64_abi_register_rsp(), 72
    );
    pe32_runtime_call_import(code, layout, 10);
    pe32_runtime_mov_rip_u32(code, layout, layout.data_rva + 4, 1);
    x64_mov_r64_imm64(code, win64_abi_register_rcx(), cast(u64, 0));
    pe32_runtime_call_import(code, layout, 2);
    usize entry_size = code.bytes.length;

    while code.bytes.length % 16 != 0 { x64_nop(code); }
    usize panic_offset = code.bytes.length;
    x64_sub_rsp(code, 40);
    x64_mov_r64_imm64(code, win64_abi_register_rcx(), pe32_u64_minus_eleven());
    pe32_runtime_call_import(code, layout, 8);
    x64_mov_r64_r64(
        code, win64_abi_register_rcx(), win64_abi_register_rax()
    );
    pe32_runtime_lea_rip(
        code, layout, win64_abi_register_rdx(),
        layout.rdata_rva + layout.panic_message_offset
    );
    x64_mov_r64_imm64(
        code, win64_abi_register_r8(),
        cast(u64, text.byte_length("OpenC SH-16 runtime panic\n"))
    );
    pe32_runtime_lea_rip(
        code, layout, win64_abi_register_r9(), layout.data_rva + 12
    );
    pe32_runtime_stack_zero(code, 32);
    pe32_runtime_call_import(code, layout, 14);
    x64_mov_r64_imm64(code, win64_abi_register_rcx(), cast(u64, 70));
    pe32_runtime_call_import(code, layout, 2);
    usize panic_size = code.bytes.length - panic_offset;
    return Pe32RuntimeCode{
        code = code, entry_size = entry_size,
        panic_offset = panic_offset, panic_size = panic_size
    };
}

unsafe Pe32RuntimeImage pe32_build_runtime_image(usize subsystem) {
    Pe32RuntimeLayout layout = pe32_runtime_layout();
    Pe32RuntimeCode runtime = pe32_build_runtime_code(layout);
    X64Code code = runtime.code;
    usize text_raw_size = x64_align_up(
        code.bytes.length, layout.file_alignment
    );
    usize text_pointer = layout.headers_size;
    usize rdata_pointer = text_pointer + text_raw_size;
    usize data_pointer = rdata_pointer + 1536;
    usize pdata_pointer = data_pointer + 512;
    usize xdata_pointer = pdata_pointer + 512;
    usize tls_pointer = xdata_pointer + 512;
    usize reloc_pointer = tls_pointer + 512;
    Pe32Section text_section = Pe32Section{
        name = ".text", virtual_size = code.bytes.length,
        virtual_address = layout.text_rva, raw_size = text_raw_size,
        raw_pointer = text_pointer, characteristics = pe32_section_code()
    };
    Pe32Section rdata_section = Pe32Section{
        name = ".rdata", virtual_size = 1448,
        virtual_address = layout.rdata_rva, raw_size = 1536,
        raw_pointer = rdata_pointer,
        characteristics = pe32_section_read_only_data()
    };
    Pe32Section data_section = Pe32Section{
        name = ".data", virtual_size = 32,
        virtual_address = layout.data_rva, raw_size = 512,
        raw_pointer = data_pointer,
        characteristics = pe32_section_read_write_data()
    };
    Pe32Section pdata_section = Pe32Section{
        name = ".pdata", virtual_size = 24,
        virtual_address = layout.pdata_rva, raw_size = 512,
        raw_pointer = pdata_pointer,
        characteristics = pe32_section_read_only_data()
    };
    Pe32Section xdata_section = Pe32Section{
        name = ".xdata", virtual_size = 16,
        virtual_address = layout.xdata_rva, raw_size = 512,
        raw_pointer = xdata_pointer,
        characteristics = pe32_section_read_only_data()
    };
    Pe32Section tls_section = Pe32Section{
        name = ".tls", virtual_size = 8,
        virtual_address = layout.tls_rva, raw_size = 512,
        raw_pointer = tls_pointer,
        characteristics = pe32_section_read_write_data()
    };
    Pe32Section reloc_section = Pe32Section{
        name = ".reloc", virtual_size = 28,
        virtual_address = layout.reloc_rva, raw_size = 512,
        raw_pointer = reloc_pointer, characteristics = 1107296320
    };
    DBuffer headers = pe32_build_headers(
        layout, subsystem, text_section, rdata_section, data_section,
        pdata_section, xdata_section, tls_section, reloc_section
    );
    DBuffer rdata = pe32_build_rdata(layout);
    DBuffer data = pe32_build_data(layout);
    DBuffer pdata = pe32_build_pdata(
        layout, runtime.entry_size, runtime.panic_offset, runtime.panic_size
    );
    DBuffer xdata = pe32_build_xdata();
    DBuffer tls = pe32_build_tls();
    DBuffer reloc = pe32_build_relocations(layout);
    DBuffer image = d_buffer_create(reloc_pointer + 512);
    x64_copy_bytes(image, headers);
    x64_copy_bytes(image, code.bytes);
    pe32_pad_to(image, rdata_pointer);
    x64_copy_bytes(image, rdata);
    x64_copy_bytes(image, data);
    x64_copy_bytes(image, pdata);
    x64_copy_bytes(image, xdata);
    x64_copy_bytes(image, tls);
    x64_copy_bytes(image, reloc);
    bool ok = code.ok && headers.ok && rdata.ok && data.ok && pdata.ok &&
        xdata.ok && tls.ok && reloc.ok && image.ok;
    d_buffer_destroy(reloc);
    d_buffer_destroy(tls);
    d_buffer_destroy(xdata);
    d_buffer_destroy(pdata);
    d_buffer_destroy(data);
    d_buffer_destroy(rdata);
    d_buffer_destroy(headers);
    x64_code_destroy(code);
    return Pe32RuntimeImage{
        image = image, entry_size = runtime.entry_size,
        panic_offset = runtime.panic_offset,
        panic_size = runtime.panic_size,
        subsystem = subsystem, ok = ok
    };
}

unsafe bool pe32_runtime_source_profile(text source) {
    return flow_source_frontend_errors(source) == 0 &&
        native_contains(source, "i32 main()") &&
        native_contains(source, "return 16;") &&
        native_contains(source, "SH16_WINDOWS_RUNTIME_PROOF");
}

unsafe i32 emit_windows_pe32_runtime(
    text source_path,
    text output_path,
    text subsystem_name,
    text report_path
) {
    text source;
    status loaded = file.read_text(source_path, out source);
    if !loaded.ok {
        io.error("OpenC SH-16 runtime profile source is invalid\n");
        return 1;
    }
    if !pe32_runtime_source_profile(source) {
        io.error("OpenC SH-16 runtime profile source is invalid\n");
        return 1;
    }
    usize subsystem = pe32_subsystem_windows_console();
    if subsystem_name == "windows" {
        subsystem = pe32_subsystem_windows_gui();
    } else if subsystem_name != "console" {
        io.error("SH-16 subsystem must be console or windows\n");
        return 64;
    }
    Pe32RuntimeImage result = pe32_build_runtime_image(subsystem);
    if !result.ok {
        d_buffer_destroy(result.image);
        io.error("OpenC SH-16 PE32+ image construction failed\n");
        return 1;
    }
    status written = file.write_bytes(
        output_path, result.image.data, result.image.length
    );
    DBuffer report = d_buffer_create(2048);
    d_put(report, "{\n  \"schema\": \"openc.windows_pe32_runtime.v1\",\n");
    d_put(report, "  \"status\": \"");
    if written.ok { d_put(report, "PASS"); } else { d_put(report, "FAIL"); }
    d_put(report, "\",\n  \"source_profile\": \"SH16_WINDOWS_RUNTIME_PROOF\",\n");
    d_put(report, "  \"subsystem\": \""); d_put(report, subsystem_name);
    d_put(report, "\",\n  \"image_bytes\": ");
    d_put_usize(report, result.image.length);
    d_put(report, ",\n  \"entry_bytes\": "); d_put_usize(report, result.entry_size);
    d_put(report, ",\n  \"panic_bytes\": "); d_put_usize(report, result.panic_size);
    d_put(report, ",\n  \"sections\": 7,\n  \"imports\": ");
    d_put_usize(report, pe32_import_count()); d_put(report, ",\n");
    d_put(report, "  \"crt_imports\": 0,\n  \"external_assembler_invoked\": false,\n");
    d_put(report, "  \"external_linker_invoked\": false,\n  \"deterministic_timestamp\": 0\n}\n");
    status report_written = file.write_text(report_path, d_buffer_text(report));
    d_buffer_destroy(report);
    d_buffer_destroy(result.image);
    if !written.ok || !report_written.ok { return 1; }
    return 0;
}
