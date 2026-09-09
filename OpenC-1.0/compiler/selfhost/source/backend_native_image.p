import system.file;
import system.io;
import system.memory;

unsafe usize native_read_u32(ref DBuffer bytes, usize offset) {
    if offset > bytes.length || bytes.length - offset < 4 { bytes.ok = false; return 0; }
    usize result = 0;
    usize index = 0;
    while index < 4 {
        result = result | (cast(usize, cast(u8, *(bytes.data + offset + index))) << (index * 8));
        index = index + 1;
    }
    return result;
}

unsafe void native_copy_range(ref DBuffer output, ref DBuffer input, usize start, usize length) {
    if start > input.length || length > input.length - start {
        output.ok = false; return;
    }
    usize index = 0;
    while index < length {
        d_put_byte(output, cast(u8, *(input.data + start + index)));
        index = index + 1;
    }
}

Pe32Section native_section(text name, usize size, usize rva, usize raw, usize flags) {
    return Pe32Section{ name = name, virtual_size = size, virtual_address = rva,
        raw_size = x64_align_up(size, 512), raw_pointer = raw, characteristics = flags };
}

unsafe status native_write_image(ref IrContext context, ref DBuffer objects, text path) {
    if objects.length > 536870912 {
        io.error("error[OPENC-NATIVE-BUDGET]: native object stream exceeds 512 MiB\n");
        return status{ code = 1 };
    }
    ptr byte addresses = memory.alloc((context.symbols.length + 1) * size_of(usize));
    scope memory.free(addresses);
    usize index = 0;
    while index <= context.symbols.length {
        write_usize(addresses, index * size_of(usize), 0); index = index + 1;
    }
    usize cursor = 0;
    usize code_size = 64;
    usize unwind_size = 16;
    usize constant_size = 0;
    usize function_count = 0;
    usize entry = context.symbols.length;
    while cursor < objects.length && objects.ok {
        usize symbol = native_read_u32(objects, cursor);
        usize entry_flag = native_read_u32(objects, cursor + 4);
        usize size = native_read_u32(objects, cursor + 8);
        usize unwind = native_read_u32(objects, cursor + 12);
        usize relocations = native_read_u32(objects, cursor + 16);
        usize constants = native_read_u32(objects, cursor + 20);
        if symbol >= context.symbols.length || (entry_flag != 0 && entry != context.symbols.length) {
            objects.ok = false; break;
        }
        if entry_flag != 0 { entry = symbol; }
        code_size = x64_align_up(code_size, 16);
        write_usize(addresses, symbol * size_of(usize), code_size);
        code_size = code_size + size;
        unwind_size = unwind_size + x64_align_up(unwind, 4);
        constant_size = constant_size + constants;
        if code_size > 268435456 || unwind_size > 134217728 ||
            constant_size > 268435456 || function_count > 1048576 {
            io.error("error[OPENC-NATIVE-BUDGET]: linked native image exceeds section budget\n");
            objects.ok = false;
            break;
        }
        cursor = cursor + 24 + size + unwind + relocations * 8 + constants;
        function_count = function_count + 1;
    }
    if !objects.ok || cursor != objects.length || entry >= context.symbols.length {
        return status{ code = 1 };
    }
    Pe32RuntimeLayout layout = pe32_runtime_layout();
    layout.rdata_rva = x64_align_up(layout.text_rva + code_size, 4096);
    layout.data_rva = x64_align_up(layout.rdata_rva + 1536 + constant_size, 4096);
    layout.pdata_rva = layout.data_rva + 4096;
    layout.xdata_rva = x64_align_up(layout.pdata_rva + (function_count + 2) * 12, 4096);
    layout.tls_rva = x64_align_up(layout.xdata_rva + unwind_size, 4096);
    layout.reloc_rva = layout.tls_rva + 4096;
    layout.image_size = layout.reloc_rva + 4096;
    X64Code code = x64_code_create(code_size + 64, 1);
    x64_sub_rsp(code, 40);
    x64_call_symbol(code, entry, 0);
    x64_mov_r64_r64(code, 1, 0);
    pe32_runtime_call_import(code, layout, 2);
    usize entry_end = code.bytes.length;
    while code.bytes.length < 32 && code.ok { x64_nop(code); }
    x64_sub_rsp(code, 40);
    x64_mov_r64_imm64(code, 1, cast(u64, 70));
    pe32_runtime_call_import(code, layout, 2);
    usize fault_end = code.bytes.length;
    while code.bytes.length < 64 && code.ok { x64_nop(code); }
    DBuffer pdata = d_buffer_create((function_count + 2) * 12 + 512);
    DBuffer xdata = d_buffer_create(unwind_size + 512);
    usize stub = 0;
    while stub < 2 {
        usize start = 0; usize end = entry_end;
        if stub == 1 { start = 32; end = fault_end; }
        pe32_put_u32(pdata, layout.text_rva + start);
        pe32_put_u32(pdata, layout.text_rva + end);
        pe32_put_u32(pdata, layout.xdata_rva + xdata.length);
        d_put_byte(xdata, 1); d_put_byte(xdata, 4);
        d_put_byte(xdata, 1); d_put_byte(xdata, 0);
        d_put_byte(xdata, 4); d_put_byte(xdata, 66);
        pe32_put_u16(xdata, 0);
        stub = stub + 1;
    }
    bool linked = x64_apply_relative32(code, 0, read_usize(addresses, entry * size_of(usize)));
    DBuffer constant_data = d_buffer_create(constant_size + 512);
    cursor = 0;
    while cursor < objects.length && linked {
        usize symbol = native_read_u32(objects, cursor);
        usize size = native_read_u32(objects, cursor + 8);
        usize unwind = native_read_u32(objects, cursor + 12);
        usize relocations = native_read_u32(objects, cursor + 16);
        usize constants = native_read_u32(objects, cursor + 20);
        usize start = read_usize(addresses, symbol * size_of(usize));
        while code.bytes.length < start && code.ok { x64_nop(code); }
        native_copy_range(code.bytes, objects, cursor + 24, size);
        pe32_put_u32(pdata, layout.text_rva + start);
        pe32_put_u32(pdata, layout.text_rva + start + size);
        pe32_put_u32(pdata, layout.xdata_rva + xdata.length);
        native_copy_range(xdata, objects, cursor + 24 + size, unwind);
        pe32_pad_to(xdata, x64_align_up(xdata.length, 4));
        usize relocation = cursor + 24 + size + unwind;
        index = 0;
        while index < relocations {
            usize offset = native_read_u32(objects, relocation + index * 8);
            usize target = native_read_u32(objects, relocation + index * 8 + 4);
            usize destination = 0;
            if target == cast(usize, 4294967295) { destination = 32; }
            else if target >= cast(usize, 3221225472) {
                destination = layout.data_rva - layout.text_rva +
                    target - cast(usize, 3221225472);
            }
            else if target >= cast(usize, 2147483648) {
                usize constant_offset = target - cast(usize, 2147483648);
                if constant_offset >= constants { linked = false; break; }
                destination = layout.rdata_rva - layout.text_rva + 1536 +
                    constant_data.length + constant_offset;
            }
            else if target >= cast(usize, 1073741824) {
                usize imported = target - cast(usize, 1073741824);
                if imported >= pe32_import_count() { linked = false; break; }
                destination = pe32_import_iat_rva(layout, imported) - layout.text_rva;
            }
            else if target < context.symbols.length {
                destination = read_usize(addresses, target * size_of(usize));
            }
            if destination == 0 || offset + 4 > size { linked = false; break; }
            i64 delta = cast(i64, destination) - cast(i64, start + offset + 4);
            u32 encoded = 0;
            if delta < 0 { encoded = cast(u32, cast(u64, 4294967296) - cast(u64, 0 - delta)); }
            else { encoded = cast(u32, delta); }
            x64_patch_u32(code, start + offset, encoded);
            index = index + 1;
        }
        native_copy_range(constant_data, objects, relocation + relocations * 8, constants);
        cursor = relocation + relocations * 8 + constants;
    }
    Pe32Section text_section = native_section(".text", code.bytes.length, layout.text_rva, 1024, pe32_section_code());
    Pe32Section rdata_section = native_section(".rdata", 1536 + constant_size, layout.rdata_rva, text_section.raw_pointer + text_section.raw_size, pe32_section_read_only_data());
    Pe32Section data_section = native_section(".data", 96, layout.data_rva, rdata_section.raw_pointer + rdata_section.raw_size, pe32_section_read_write_data());
    Pe32Section pdata_section = native_section(".pdata", pdata.length, layout.pdata_rva, data_section.raw_pointer + data_section.raw_size, pe32_section_read_only_data());
    Pe32Section xdata_section = native_section(".xdata", xdata.length, layout.xdata_rva, pdata_section.raw_pointer + pdata_section.raw_size, pe32_section_read_only_data());
    Pe32Section tls_section = native_section(".tls", 8, layout.tls_rva, xdata_section.raw_pointer + xdata_section.raw_size, pe32_section_read_write_data());
    Pe32Section reloc_section = native_section(".reloc", 28, layout.reloc_rva, tls_section.raw_pointer + tls_section.raw_size, 1107296320);
    DBuffer headers = pe32_build_headers(layout, 3, text_section, rdata_section,
        data_section, pdata_section, xdata_section, tls_section, reloc_section);
    pe32_patch_u32(headers, 292, pdata.length);
    DBuffer rdata = pe32_build_rdata(layout);
    DBuffer data = pe32_build_data(layout);
    DBuffer tls = pe32_build_tls();
    DBuffer reloc = pe32_build_relocations(layout);
    DBuffer image = d_buffer_create(reloc_section.raw_pointer + reloc_section.raw_size);
    x64_copy_bytes(image, headers); x64_copy_bytes(image, code.bytes);
    pe32_pad_to(image, rdata_section.raw_pointer); x64_copy_bytes(image, rdata);
    x64_copy_bytes(image, constant_data);
    pe32_pad_to(image, data_section.raw_pointer);
    x64_copy_bytes(image, data);
    pe32_pad_to(image, pdata_section.raw_pointer); x64_copy_bytes(image, pdata);
    pe32_pad_to(image, xdata_section.raw_pointer); x64_copy_bytes(image, xdata);
    pe32_pad_to(image, tls_section.raw_pointer); x64_copy_bytes(image, tls);
    x64_copy_bytes(image, reloc);
    status written = status{ code = 1 };
    if linked && code.ok && image.ok && headers.ok && pdata.ok && xdata.ok {
        written = file.write_bytes(path, image.data, image.length);
    } else { io.error("error[OPENC-NATIVE-LINK]: unresolved or invalid native relocation\n"); }
    d_buffer_destroy(image); d_buffer_destroy(reloc); d_buffer_destroy(tls);
    d_buffer_destroy(data); d_buffer_destroy(rdata); d_buffer_destroy(headers);
    d_buffer_destroy(xdata); d_buffer_destroy(pdata); x64_code_destroy(code);
    d_buffer_destroy(constant_data);
    return written;
}
