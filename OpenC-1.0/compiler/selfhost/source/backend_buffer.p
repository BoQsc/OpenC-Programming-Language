import system.file;
import system.memory;
import system.path;
import system.text;

struct DBuffer {
    ptr byte data;
    usize length;
    usize capacity;
    bool ok;
}

struct DScopeState {
    usize next;
}

unsafe DBuffer d_buffer_create(usize capacity) {
    return DBuffer{
        data = memory.alloc(capacity),
        length = 0,
        capacity = capacity,
        ok = true
    };
}

unsafe void d_buffer_destroy(ref DBuffer buffer) {
    memory.free(buffer.data);
    buffer.length = 0;
    buffer.capacity = 0;
    buffer.ok = false;
}

unsafe void d_put_byte(ref DBuffer buffer, u8 value) {
    if !buffer.ok || buffer.length >= buffer.capacity {
        buffer.ok = false;
        return;
    }
    *(buffer.data + buffer.length) = cast(byte, value);
    buffer.length = buffer.length + 1;
}

unsafe void d_put(ref DBuffer buffer, text value) {
    usize length = text.byte_length(value);
    usize index = 0;
    while index < length {
        d_put_byte(buffer, byte_at_or_zero(value, index));
        index = index + 1;
    }
}

unsafe void d_put_slice(
    ref DBuffer buffer,
    text value,
    usize start,
    usize length
) {
    usize index = 0;
    while index < length {
        d_put_byte(buffer, byte_at_or_zero(value, start + index));
        index = index + 1;
    }
}

unsafe void d_put_mangled_slice(
    ref DBuffer buffer,
    text value,
    usize start,
    usize length
) {
    usize index = 0;
    while index < length {
        u8 octet = byte_at_or_zero(value, start + index);
        if octet == 46 { octet = 95; }
        d_put_byte(buffer, octet);
        index = index + 1;
    }
}

unsafe void d_put_usize(ref DBuffer buffer, usize value) {
    if value == 0 {
        d_put_byte(buffer, 48);
        return;
    }
    usize divisor = 1;
    usize remaining = value;
    while remaining >= 10 {
        divisor = divisor * 10;
        remaining = remaining / 10;
    }
    while divisor != 0 {
        d_put_byte(buffer, cast(u8, 48 + (value / divisor) % 10));
        divisor = divisor / 10;
    }
}

unsafe text d_buffer_text(ref DBuffer buffer) {
    return text.from_utf8(buffer.data, buffer.length);
}

unsafe text d_symbol_source(
    ref IrContext context,
    usize symbol
) {
    if read_record_field(context.symbol_data, symbol, 1) ==
            context.source_record && text.byte_length(context.source) != 0 {
        return context.source;
    }
    text loaded_source;
    status loaded = project_read_source_record(
        context.project_source, context.project_root, context.source_data,
        read_record_field(context.symbol_data, symbol, 1), out loaded_source
    );
    if !loaded.ok { return ""; }
    return loaded_source;
}

unsafe void d_put_symbol_name(
    ref IrContext context,
    ref DBuffer buffer,
    usize symbol
) {
    text source = d_symbol_source(context, symbol);
    if text.byte_length(source) != 0 {
        d_put_slice(
            buffer, source,
            read_record_field(context.symbol_data, symbol, 2),
            read_record_field(context.symbol_data, symbol, 3)
        );
    }
}

unsafe bool d_symbol_name_is(
    ref IrContext context,
    usize symbol,
    text expected
) {
    text source = d_symbol_source(context, symbol);
    if text.byte_length(source) == 0 { return false; }
    return span_equals_ascii(
        source,
        read_record_field(context.symbol_data, symbol, 2),
        read_record_field(context.symbol_data, symbol, 3),
        expected
    );
}

unsafe void d_put_module_name(
    ref IrContext context,
    ref DBuffer buffer,
    usize module_index,
    bool mangle
) {
    usize start = read_record_field(context.module_data, module_index, 0);
    usize length = read_record_field(context.module_data, module_index, 1);
    if mangle {
        d_put_mangled_slice(buffer, context.project_source, start, length);
    } else {
        d_put_slice(buffer, context.project_source, start, length);
    }
}

unsafe void d_put_qualified_symbol(
    ref IrContext context,
    ref DBuffer buffer,
    usize symbol,
    bool mangle
) {
    usize kind = read_record_field(context.symbol_data, symbol, 0);
    if read_record_field(context.detail_data, symbol, 2) == 0 &&
        kind != resolution_symbol_field() &&
        kind != resolution_symbol_enum_item() {
        d_put_module_name(
            context, buffer,
            read_record_field(context.detail_data, symbol, 0), mangle
        );
        if mangle { d_put(buffer, "_"); }
        else { d_put(buffer, "."); }
    }
    d_put_symbol_name(context, buffer, symbol);
}

unsafe void d_put_type(
    ref IrContext context,
    ref DBuffer buffer,
    usize type_id
) {
    if type_id >= context.types.length {
        d_put(buffer, "void");
        return;
    }
    usize kind = read_record_field(context.type_data, type_id, 0);
    if kind == 0 || kind == 1 { d_put(buffer, "void"); return; }
    if kind == 2 {
        usize bits = read_record_field(context.type_data, type_id, 3);
        if bits == 8 { d_put(buffer, "byte"); }
        else if bits == 16 { d_put(buffer, "short"); }
        else if bits == 32 { d_put(buffer, "int"); }
        else if bits == 64 { d_put(buffer, "long"); }
        else { d_put(buffer, "ptrdiff_t"); }
        return;
    }
    if kind == 3 {
        usize bits = read_record_field(context.type_data, type_id, 3);
        if bits == 8 { d_put(buffer, "ubyte"); }
        else if bits == 16 { d_put(buffer, "ushort"); }
        else if bits == 32 { d_put(buffer, "uint"); }
        else if bits == 64 { d_put(buffer, "ulong"); }
        else { d_put(buffer, "size_t"); }
        return;
    }
    if kind == 4 {
        if read_record_field(context.type_data, type_id, 3) == 32 {
            d_put(buffer, "float");
        } else { d_put(buffer, "double"); }
        return;
    }
    if kind == 5 { d_put(buffer, "bool"); return; }
    if kind == 6 { d_put(buffer, "ubyte"); return; }
    if kind == 7 { d_put(buffer, "string"); return; }
    if kind == 8 { d_put(buffer, "Status"); return; }
    if kind == 9 {
        text source;
        usize source_record = read_record_field(context.type_data, type_id, 1);
        status loaded = project_read_source_record(
            context.project_source, context.project_root,
            context.source_data, source_record, out source
        );
        if loaded.ok {
            d_put_slice(
                buffer, source,
                read_record_field(context.type_data, type_id, 2),
                read_record_field(context.type_data, type_id, 3)
            );
        } else { d_put(buffer, "void"); }
        return;
    }
    if kind == 10 {
        d_put_type(
            context, buffer,
            read_record_field(context.type_data, type_id, 1)
        );
        d_put(buffer, "[");
        d_put_usize(buffer, read_record_field(context.type_data, type_id, 2));
        d_put(buffer, "]");
        return;
    }
    if kind == 11 {
        d_put_type(
            context, buffer,
            read_record_field(context.type_data, type_id, 1)
        );
        d_put(buffer, "[]");
        return;
    }
    if kind == 12 {
        if read_record_field(context.type_data, type_id, 4) % 2 == 1 {
            d_put(buffer, "const(");
            d_put_type(
                context, buffer,
                read_record_field(context.type_data, type_id, 1)
            );
            d_put(buffer, ")");
        } else {
            d_put_type(
                context, buffer,
                read_record_field(context.type_data, type_id, 1)
            );
        }
        return;
    }
    if kind == 13 {
        d_put_type(
            context, buffer,
            read_record_field(context.type_data, type_id, 1)
        );
        d_put(buffer, "*");
        return;
    }
    if kind == 14 {
        d_put(buffer, "OpenCOptional!(");
        d_put_type(
            context, buffer,
            read_record_field(context.type_data, type_id, 1)
        );
        d_put(buffer, ")");
        return;
    }
    d_put(buffer, "OpenCStorage!(");
    d_put_type(
        context, buffer,
        read_record_field(context.type_data, type_id, 1)
    );
    d_put(buffer, ")");
}
