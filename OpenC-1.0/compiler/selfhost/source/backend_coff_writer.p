import system.file;
import system.memory;
import system.text;

unsafe void coff_patch_i32(ref DBuffer bytes, usize offset, usize value) {
    pe32_patch_u32(bytes, offset, value);
}

unsafe void coff_put_section_header(
    ref DBuffer output,
    text name,
    usize size,
    usize raw_pointer,
    usize relocation_pointer,
    usize relocations,
    usize characteristics
) {
    pe32_put_fixed_name(output, name);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, size);
    pe32_put_u32(output, raw_pointer);
    pe32_put_u32(output, relocation_pointer);
    pe32_put_u32(output, 0);
    pe32_put_u16(output, relocations);
    pe32_put_u16(output, 0);
    pe32_put_u32(output, characteristics);
}

unsafe void coff_put_relocation(
    ref DBuffer output,
    usize address,
    usize symbol,
    usize kind
) {
    pe32_put_u32(output, address);
    pe32_put_u32(output, symbol);
    pe32_put_u16(output, kind);
}

unsafe void coff_put_symbol(
    ref DBuffer output,
    text name,
    usize value,
    i64 section,
    usize type_value,
    usize storage_class,
    ref DBuffer strings
) {
    if text.byte_length(name) <= 8 {
        pe32_put_fixed_name(output, name);
    } else {
        pe32_put_u32(output, 0);
        pe32_put_u32(output, strings.length);
        pe32_put_ascii_z(strings, name);
    }
    pe32_put_u32(output, value);
    pe_coff_put_i16(output, section);
    pe32_put_u16(output, type_value);
    d_put_byte(output, cast(u8, storage_class));
    d_put_byte(output, 0);
}

unsafe bool coff_symbol_exported(ref IrContext context, usize symbol) {
    return resolution_is_exported(
        context.project_source, context.project_root,
        context.source_data, context.symbol_data, symbol
    );
}

unsafe void coff_internal_name(ref DBuffer output, usize symbol) {
    d_put(output, "$openc$");
    d_put_usize(output, symbol);
}

unsafe DBuffer native_build_coff_object(
    ref IrContext context,
    ref DBuffer objects,
    ref usize exported_count,
    ref usize relocation_count
) {
    ptr byte addresses = memory.alloc(
        (context.symbols.length + 1) * size_of(usize)
    );
    ptr byte constant_offsets = memory.alloc(
        (context.symbols.length + 1) * size_of(usize)
    );
    ptr byte unwind_offsets = memory.alloc(
        (context.symbols.length + 1) * size_of(usize)
    );
    ptr byte symbol_indices = memory.alloc(
        (context.symbols.length + 1) * size_of(usize)
    );
    usize symbol = 0;
    while symbol <= context.symbols.length {
        write_usize(addresses, symbol * size_of(usize), 0);
        write_usize(constant_offsets, symbol * size_of(usize), 0);
        write_usize(unwind_offsets, symbol * size_of(usize), 0);
        write_usize(symbol_indices, symbol * size_of(usize), 0);
        symbol = symbol + 1;
    }
    usize cursor = 0;
    usize code_size = 32;
    usize constant_size = 0;
    usize unwind_size = 0;
    usize function_count = 0;
    usize text_relocations = 0;
    while cursor < objects.length && objects.ok {
        symbol = native_read_u32(objects, cursor);
        usize size = native_read_u32(objects, cursor + 8);
        usize unwind = native_read_u32(objects, cursor + 12);
        usize relocations = native_read_u32(objects, cursor + 16);
        usize constants = native_read_u32(objects, cursor + 20);
        if symbol >= context.symbols.length || relocations > 65535 {
            objects.ok = false;
            break;
        }
        code_size = x64_align_up(code_size, 16);
        unwind_size = x64_align_up(unwind_size, 4);
        write_usize(addresses, symbol * size_of(usize), code_size);
        write_usize(constant_offsets, symbol * size_of(usize), constant_size);
        write_usize(unwind_offsets, symbol * size_of(usize), unwind_size);
        write_usize(
            symbol_indices,
            symbol * size_of(usize),
            7 + function_count
        );
        code_size = code_size + size;
        constant_size = constant_size + constants;
        unwind_size = unwind_size + unwind;
        text_relocations = text_relocations + relocations;
        cursor = cursor + 24 + size + unwind + relocations * 8 + constants;
        function_count = function_count + 1;
    }
    relocation_count = text_relocations + function_count * 3;
    DBuffer text_data = d_buffer_create(code_size + 16);
    DBuffer rdata = d_buffer_create(constant_size + 4);
    DBuffer data = d_buffer_create(96);
    DBuffer pdata = d_buffer_create(function_count * 12 + 4);
    DBuffer xdata = d_buffer_create(unwind_size + 4);
    DBuffer text_reloc = d_buffer_create(text_relocations * 10 + 4);
    DBuffer pdata_reloc = d_buffer_create(function_count * 30 + 4);
    d_put_byte(text_data, 204);
    d_put_byte(text_data, 195);
    pe32_pad_to(text_data, 16);
    d_put_byte(text_data, 204);
    d_put_byte(text_data, 195);
    pe32_pad_to(text_data, 32);
    cursor = 0;
    while cursor < objects.length && objects.ok {
        symbol = native_read_u32(objects, cursor);
        usize size = native_read_u32(objects, cursor + 8);
        usize unwind = native_read_u32(objects, cursor + 12);
        usize relocations = native_read_u32(objects, cursor + 16);
        usize constants = native_read_u32(objects, cursor + 20);
        usize start = read_usize(addresses, symbol * size_of(usize));
        pe32_pad_to(text_data, start);
        native_copy_range(text_data, objects, cursor + 24, size);
        usize unwind_at = read_usize(
            unwind_offsets, symbol * size_of(usize)
        );
        pe32_pad_to(xdata, unwind_at);
        native_copy_range(xdata, objects, cursor + 24 + size, unwind);
        usize pdata_at = pdata.length;
        pe32_put_u32(pdata, start);
        pe32_put_u32(pdata, start + size);
        pe32_put_u32(pdata, unwind_at);
        coff_put_relocation(pdata_reloc, pdata_at, 0, 3);
        coff_put_relocation(pdata_reloc, pdata_at + 4, 0, 3);
        coff_put_relocation(pdata_reloc, pdata_at + 8, 4, 3);
        usize relocation_at = cursor + 24 + size + unwind;
        usize index = 0;
        while index < relocations {
            usize offset = native_read_u32(
                objects, relocation_at + index * 8
            );
            usize target = native_read_u32(
                objects, relocation_at + index * 8 + 4
            );
            usize target_symbol = 0;
            usize addend = 0;
            if target == cast(usize, 4294967295) {
                target_symbol = 5;
            } else if target == cast(usize, 4294967294) {
                target_symbol = 6;
            } else if target >= cast(usize, 3221225472) {
                target_symbol = 2;
                addend = target - cast(usize, 3221225472);
            } else if target >= cast(usize, 2147483648) {
                target_symbol = 1;
                addend = read_usize(
                    constant_offsets, symbol * size_of(usize)
                ) + target - cast(usize, 2147483648);
            } else if target >= cast(usize, 1073741824) {
                usize imported = target - cast(usize, 1073741824);
                if imported >= pe32_import_count() {
                    objects.ok = false;
                } else {
                    target_symbol = 7 + function_count + imported;
                }
            } else if target < context.symbols.length {
                target_symbol = read_usize(
                    symbol_indices, target * size_of(usize)
                );
            } else {
                objects.ok = false;
            }
            if offset + 4 > size || target_symbol == 0 {
                objects.ok = false;
            }
            if addend != 0 {
                coff_patch_i32(text_data, start + offset, addend);
            }
            coff_put_relocation(
                text_reloc, start + offset, target_symbol, 4
            );
            index = index + 1;
        }
        native_copy_range(
            rdata, objects,
            relocation_at + relocations * 8,
            constants
        );
        cursor = relocation_at + relocations * 8 + constants;
    }
    pe32_pad_to(text_data, code_size);
    pe32_pad_to(rdata, constant_size);
    pe32_pad_to(data, 96);
    pe32_pad_to(xdata, unwind_size);
    usize headers_size = 220;
    usize text_raw = headers_size;
    usize rdata_raw = text_raw + text_data.length;
    usize data_raw = rdata_raw + rdata.length;
    usize pdata_raw = data_raw + data.length;
    usize xdata_raw = pdata_raw + pdata.length;
    usize text_reloc_at = xdata_raw + xdata.length;
    usize pdata_reloc_at = text_reloc_at + text_reloc.length;
    usize symbol_table_at = pdata_reloc_at + pdata_reloc.length;
    usize symbol_count = 7 + function_count + pe32_import_count();
    DBuffer output = d_buffer_create(
        symbol_table_at + symbol_count * 18 +
            function_count * 544 + 2048
    );
    pe32_put_u16(output, 34404);
    pe32_put_u16(output, 5);
    pe32_put_u32(output, 0);
    pe32_put_u32(output, symbol_table_at);
    pe32_put_u32(output, symbol_count);
    pe32_put_u16(output, 0);
    pe32_put_u16(output, 0);
    coff_put_section_header(
        output, ".text", text_data.length, text_raw,
        text_reloc_at, text_relocations, 1615855648
    );
    coff_put_section_header(
        output, ".rdata", rdata.length, rdata_raw, 0, 0, 1076887616
    );
    coff_put_section_header(
        output, ".data", data.length, data_raw, 0, 0, 3224371264
    );
    coff_put_section_header(
        output, ".pdata", pdata.length, pdata_raw,
        pdata_reloc_at, function_count * 3, 1076887616
    );
    coff_put_section_header(
        output, ".xdata", xdata.length, xdata_raw, 0, 0, 1076887616
    );
    native_copy_range(output, text_data, 0, text_data.length);
    native_copy_range(output, rdata, 0, rdata.length);
    native_copy_range(output, data, 0, data.length);
    native_copy_range(output, pdata, 0, pdata.length);
    native_copy_range(output, xdata, 0, xdata.length);
    native_copy_range(output, text_reloc, 0, text_reloc.length);
    native_copy_range(output, pdata_reloc, 0, pdata_reloc.length);
    DBuffer strings = d_buffer_create(function_count * 544 + 2048);
    pe32_put_u32(strings, 0);
    coff_put_symbol(output, ".text", 0, 1, 0, 3, strings);
    coff_put_symbol(output, ".rdata", 0, 2, 0, 3, strings);
    coff_put_symbol(output, ".data", 0, 3, 0, 3, strings);
    coff_put_symbol(output, ".pdata", 0, 4, 0, 3, strings);
    coff_put_symbol(output, ".xdata", 0, 5, 0, 3, strings);
    coff_put_symbol(output, "$openc_checked_fault", 0, 1, 32, 3, strings);
    coff_put_symbol(output, "$openc_target_fault", 16, 1, 32, 3, strings);
    usize local_exported_count = 0;
    cursor = 0;
    while cursor < objects.length {
        symbol = native_read_u32(objects, cursor);
        usize size = native_read_u32(objects, cursor + 8);
        usize unwind = native_read_u32(objects, cursor + 12);
        usize relocations = native_read_u32(objects, cursor + 16);
        usize constants = native_read_u32(objects, cursor + 20);
        DBuffer name = d_buffer_create(544);
        usize storage_class = 3;
        if coff_symbol_exported(context, symbol) {
            pe_export_symbol_name(context, symbol, name);
            storage_class = 2;
            local_exported_count = local_exported_count + 1;
        } else {
            coff_internal_name(name, symbol);
        }
        coff_put_symbol(
            output, d_buffer_text(name),
            read_usize(addresses, symbol * size_of(usize)),
            1, 32, storage_class, strings
        );
        d_buffer_destroy(name);
        cursor = cursor + 24 + size + unwind + relocations * 8 + constants;
    }
    cursor = 0;
    while cursor < pe32_import_count() {
        DBuffer name = d_buffer_create(128);
        d_put(name, "__imp_");
        d_put(name, pe32_import_name(cursor));
        coff_put_symbol(
            output, d_buffer_text(name), 0, 0, 0, 2, strings
        );
        d_buffer_destroy(name);
        cursor = cursor + 1;
    }
    exported_count = local_exported_count;
    pe32_patch_u32(strings, 0, strings.length);
    native_copy_range(output, strings, 0, strings.length);
    if !objects.ok || !text_data.ok || !rdata.ok || !data.ok ||
        !pdata.ok || !xdata.ok || !text_reloc.ok || !pdata_reloc.ok ||
        !strings.ok {
        output.ok = false;
    }
    d_buffer_destroy(strings);
    d_buffer_destroy(pdata_reloc);
    d_buffer_destroy(text_reloc);
    d_buffer_destroy(xdata);
    d_buffer_destroy(pdata);
    d_buffer_destroy(data);
    d_buffer_destroy(rdata);
    d_buffer_destroy(text_data);
    memory.free(symbol_indices);
    memory.free(unwind_offsets);
    memory.free(constant_offsets);
    memory.free(addresses);
    return output;
}

unsafe status native_write_coff_object(
    ref IrContext context,
    ref DBuffer objects,
    text path
) {
    usize exports = 0;
    usize relocations = 0;
    DBuffer object = native_build_coff_object(
        context, objects, exports, relocations
    );
    status written = status{ code = 1 };
    if object.ok && exports != 0 && relocations != 0 {
        written = file.write_bytes(path, object.data, object.length);
    }
    d_buffer_destroy(object);
    return written;
}

unsafe void coff_archive_field(
    ref DBuffer output,
    text value,
    usize width
) {
    usize index = 0;
    while index < width {
        u8 octet = 32;
        if index < text.byte_length(value) {
            octet = byte_at_or_zero(value, index);
        }
        d_put_byte(output, octet);
        index = index + 1;
    }
    if text.byte_length(value) > width { output.ok = false; }
}

unsafe void coff_archive_member_header(
    ref DBuffer output,
    text name,
    usize size
) {
    coff_archive_field(output, name, 16);
    pe_coff_put_decimal_field(output, 0, 12);
    pe_coff_put_decimal_field(output, 0, 6);
    pe_coff_put_decimal_field(output, 0, 6);
    coff_archive_field(output, "100644", 8);
    pe_coff_put_decimal_field(output, size, 10);
    d_put(output, "`\n");
}

unsafe void coff_archive_pad(ref DBuffer output, usize member_size) {
    if (member_size & 1) != 0 { d_put_byte(output, 10); }
}

unsafe DBuffer coff_export_names(
    ref IrContext context,
    ref usize count
) {
    DBuffer names = d_buffer_create(context.symbols.length * 544 + 4);
    usize local_count = 0;
    usize symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_function() &&
            coff_symbol_exported(context, symbol) {
            pe_export_symbol_name(context, symbol, names);
            d_put_byte(names, 0);
            local_count = local_count + 1;
        }
        symbol = symbol + 1;
    }
    count = local_count;
    return names;
}

unsafe status native_write_static_library(
    ref IrContext context,
    ref DBuffer objects,
    text path
) {
    usize object_exports = 0;
    usize object_relocations = 0;
    DBuffer object = native_build_coff_object(
        context, objects, object_exports, object_relocations
    );
    usize name_count = 0;
    DBuffer names = coff_export_names(context, name_count);
    usize linker_size = 4 + name_count * 4 + names.length;
    usize linker_padding = 0;
    if (linker_size & 1) != 0 { linker_padding = 1; }
    usize object_header = 68 + linker_size + linker_padding;
    DBuffer library = d_buffer_create(
        object_header + 60 + object.length + 2
    );
    d_put(library, "!<arch>\n");
    coff_archive_member_header(library, "/", linker_size);
    pe_coff_put_big_u32(library, name_count);
    usize index = 0;
    while index < name_count {
        pe_coff_put_big_u32(library, object_header);
        index = index + 1;
    }
    native_copy_range(library, names, 0, names.length);
    coff_archive_pad(library, linker_size);
    coff_archive_member_header(library, "openc.obj/", object.length);
    native_copy_range(library, object, 0, object.length);
    coff_archive_pad(library, object.length);
    status written = status{ code = 1 };
    if object.ok && library.ok && name_count != 0 && object_relocations != 0 {
        written = file.write_bytes(path, library.data, library.length);
    }
    d_buffer_destroy(library);
    d_buffer_destroy(names);
    d_buffer_destroy(object);
    return written;
}

unsafe DBuffer coff_short_import_object(text symbol, text dll_name) {
    usize payload = text.byte_length(symbol) + text.byte_length(dll_name) + 2;
    DBuffer object = d_buffer_create(20 + payload);
    pe32_put_u16(object, 0);
    pe32_put_u16(object, 65535);
    pe32_put_u16(object, 0);
    pe32_put_u16(object, 34404);
    pe32_put_u32(object, 0);
    pe32_put_u32(object, payload);
    pe32_put_u16(object, 0);
    pe32_put_u16(object, 4);
    pe32_put_ascii_z(object, symbol);
    pe32_put_ascii_z(object, dll_name);
    return object;
}

unsafe status native_write_import_library(
    ref IrContext context,
    text dll_name,
    text path
) {
    usize count = 0;
    DBuffer names = coff_export_names(context, count);
    if count == 0 || text.byte_length(dll_name) == 0 {
        d_buffer_destroy(names);
        return status{ code = 1 };
    }
    usize definitions = count * 2;
    usize linker_names_size = 0;
    usize cursor = 0;
    while cursor < names.length {
        usize start = cursor;
        while cursor < names.length &&
            cast(u8, *(names.data + cursor)) != 0 {
            cursor = cursor + 1;
        }
        usize length = cursor - start;
        linker_names_size = linker_names_size + length + 1;
        linker_names_size = linker_names_size + 6 + length + 1;
        cursor = cursor + 1;
    }
    usize linker_size = 4 + definitions * 4 + linker_names_size;
    usize linker_padding = 0;
    if (linker_size & 1) != 0 { linker_padding = 1; }
    usize first_member = 68 + linker_size + linker_padding;
    ptr byte member_offsets = memory.alloc(count * size_of(usize));
    usize member_at = first_member;
    cursor = 0;
    usize item = 0;
    while cursor < names.length {
        usize start = cursor;
        while cursor < names.length &&
            cast(u8, *(names.data + cursor)) != 0 {
            cursor = cursor + 1;
        }
        usize short_size = 20 + (cursor - start) + 1 +
            text.byte_length(dll_name) + 1;
        write_usize(member_offsets, item * size_of(usize), member_at);
        usize short_padding = 0;
        if (short_size & 1) != 0 { short_padding = 1; }
        member_at = member_at + 60 + short_size + short_padding;
        item = item + 1;
        cursor = cursor + 1;
    }
    DBuffer library = d_buffer_create(member_at + 2);
    d_put(library, "!<arch>\n");
    coff_archive_member_header(library, "/", linker_size);
    pe_coff_put_big_u32(library, definitions);
    item = 0;
    while item < count {
        pe_coff_put_big_u32(
            library, read_usize(member_offsets, item * size_of(usize))
        );
        pe_coff_put_big_u32(
            library, read_usize(member_offsets, item * size_of(usize))
        );
        item = item + 1;
    }
    cursor = 0;
    while cursor < names.length {
        usize start = cursor;
        while cursor < names.length &&
            cast(u8, *(names.data + cursor)) != 0 {
            cursor = cursor + 1;
        }
        text name = project_slice(
            d_buffer_text(names), start, cursor - start
        );
        d_put(library, name);
        d_put_byte(library, 0);
        d_put(library, "__imp_");
        d_put(library, name);
        d_put_byte(library, 0);
        cursor = cursor + 1;
    }
    coff_archive_pad(library, linker_size);
    cursor = 0;
    while cursor < names.length {
        usize start = cursor;
        while cursor < names.length &&
            cast(u8, *(names.data + cursor)) != 0 {
            cursor = cursor + 1;
        }
        text name = project_slice(
            d_buffer_text(names), start, cursor - start
        );
        DBuffer object = coff_short_import_object(name, dll_name);
        coff_archive_member_header(library, "import.obj/", object.length);
        native_copy_range(library, object, 0, object.length);
        coff_archive_pad(library, object.length);
        d_buffer_destroy(object);
        cursor = cursor + 1;
    }
    status written = status{ code = 1 };
    if library.ok {
        written = file.write_bytes(path, library.data, library.length);
    }
    d_buffer_destroy(library);
    memory.free(member_offsets);
    d_buffer_destroy(names);
    return written;
}
