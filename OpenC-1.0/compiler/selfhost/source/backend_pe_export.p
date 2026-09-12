import system.file;
import system.memory;
import system.text;

unsafe bool pe_export_symbol_name(
    ref IrContext context,
    usize symbol,
    ref DBuffer output
) {
    text source;
    status loaded = project_read_source_record(
        context.project_source, context.project_root, context.source_data,
        read_record_field(context.symbol_data, symbol, 1), out source
    );
    if !loaded.ok { return false; }
    d_put(
        output,
        project_slice(
            source,
            read_record_field(context.symbol_data, symbol, 2),
            read_record_field(context.symbol_data, symbol, 3)
        )
    );
    return output.ok;
}

unsafe i32 pe_export_compare(
    ref IrContext context,
    usize left,
    usize right
) {
    DBuffer left_name = d_buffer_create(512);
    DBuffer right_name = d_buffer_create(512);
    bool ok = pe_export_symbol_name(context, left, left_name) &&
        pe_export_symbol_name(context, right, right_name);
    usize common = left_name.length;
    if right_name.length < common { common = right_name.length; }
    usize index = 0;
    i32 result = 0;
    while ok && result == 0 && index < common {
        u8 a = cast(u8, *(left_name.data + index));
        u8 b = cast(u8, *(right_name.data + index));
        if a < b { result = -1; }
        if a > b { result = 1; }
        index = index + 1;
    }
    if result == 0 && left_name.length < right_name.length { result = -1; }
    if result == 0 && left_name.length > right_name.length { result = 1; }
    if !ok { result = 0; }
    d_buffer_destroy(right_name);
    d_buffer_destroy(left_name);
    return result;
}

unsafe usize pe_collect_exports(
    ref IrContext context,
    ptr byte addresses,
    ptr byte exports
) {
    usize count = 0;
    usize symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_function() &&
            read_usize(addresses, symbol * size_of(usize)) != 0 &&
            resolution_is_exported(
                context.project_source, context.project_root,
                context.source_data, context.symbol_data, symbol
            ) {
            write_usize(exports, count * size_of(usize), symbol);
            count = count + 1;
        }
        symbol = symbol + 1;
    }
    usize index = 1;
    while index < count {
        usize selected = read_usize(exports, index * size_of(usize));
        usize place = index;
        while place != 0 && pe_export_compare(
            context,
            selected,
            read_usize(exports, (place - 1) * size_of(usize))
        ) < 0 {
            write_usize(
                exports, place * size_of(usize),
                read_usize(exports, (place - 1) * size_of(usize))
            );
            place = place - 1;
        }
        write_usize(exports, place * size_of(usize), selected);
        index = index + 1;
    }
    return count;
}

unsafe DBuffer pe32_build_exports(
    ref IrContext context,
    ptr byte addresses,
    usize section_rva,
    text dll_name,
    ref usize export_count
) {
    ptr byte exports = memory.alloc(
        (context.symbols.length + 1) * size_of(usize)
    );
    usize count = pe_collect_exports(context, addresses, exports);
    export_count = count;
    DBuffer output = d_buffer_create(
        256 + count * 544
    );
    if count == 0 || text.byte_length(dll_name) == 0 {
        output.ok = false;
        memory.free(exports);
        return output;
    }
    usize functions_at = 40;
    usize names_at = functions_at + count * 4;
    usize ordinals_at = names_at + count * 4;
    usize strings_at = ordinals_at + count * 2;
    usize dll_name_at = strings_at;
    usize first_name_at = dll_name_at + text.byte_length(dll_name) + 1;
    pe32_put_u32(output, 0);
    pe32_put_u32(output, 0);
    pe32_put_u16(output, 0);
    pe32_put_u16(output, 0);
    pe32_put_u32(output, section_rva + dll_name_at);
    pe32_put_u32(output, 1);
    pe32_put_u32(output, count);
    pe32_put_u32(output, count);
    pe32_put_u32(output, section_rva + functions_at);
    pe32_put_u32(output, section_rva + names_at);
    pe32_put_u32(output, section_rva + ordinals_at);
    usize index = 0;
    while index < count {
        usize symbol = read_usize(exports, index * size_of(usize));
        pe32_put_u32(
            output,
            pe32_runtime_layout().text_rva +
                read_usize(addresses, symbol * size_of(usize))
        );
        index = index + 1;
    }
    usize name_offset = first_name_at;
    index = 0;
    while index < count {
        usize symbol = read_usize(exports, index * size_of(usize));
        DBuffer name = d_buffer_create(512);
        pe_export_symbol_name(context, symbol, name);
        pe32_put_u32(output, section_rva + name_offset);
        name_offset = name_offset + name.length + 1;
        d_buffer_destroy(name);
        index = index + 1;
    }
    index = 0;
    while index < count {
        pe32_put_u16(output, index);
        index = index + 1;
    }
    pe32_put_ascii_z(output, dll_name);
    index = 0;
    while index < count {
        DBuffer name = d_buffer_create(512);
        pe_export_symbol_name(
            context,
            read_usize(exports, index * size_of(usize)),
            name
        );
        pe32_put_ascii_z(output, d_buffer_text(name));
        d_buffer_destroy(name);
        index = index + 1;
    }
    memory.free(exports);
    return output;
}
