import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

struct SemanticCounts {
    usize declarations;
    usize parameters;
    usize fields;
    usize items;
}

usize semantic_type_error() { return 0; }
usize semantic_type_void() { return 1; }
usize semantic_type_bool() { return 2; }
usize semantic_type_byte() { return 3; }
usize semantic_type_text() { return 4; }
usize semantic_type_status() { return 5; }

unsafe usize semantic_add_type(
    ptr byte type_data,
    ref PackedBuffer types,
    usize kind,
    usize field_one,
    usize field_two,
    usize field_three,
    usize flags
) {
    usize record = types.length;
    write_record_field(type_data, record, 0, kind);
    write_record_field(type_data, record, 1, field_one);
    write_record_field(type_data, record, 2, field_two);
    write_record_field(type_data, record, 3, field_three);
    write_record_field(type_data, record, 4, flags);
    types.length = types.length + 1;
    return record;
}

unsafe void semantic_initialize_types(
    ptr byte type_data,
    ref PackedBuffer types
) {
    semantic_add_type(type_data, types, 0, 0, 0, 0, 0);
    semantic_add_type(type_data, types, 1, 0, 0, 0, 0);
    semantic_add_type(type_data, types, 5, 0, 0, 0, 0);
    semantic_add_type(type_data, types, 6, 0, 0, 8, 0);
    semantic_add_type(type_data, types, 7, 0, 0, 0, 0);
    semantic_add_type(type_data, types, 8, 0, 0, 0, 0);
    semantic_add_type(type_data, types, 2, 0, 0, 8, 0);
    semantic_add_type(type_data, types, 3, 0, 0, 8, 0);
    semantic_add_type(type_data, types, 2, 0, 0, 16, 0);
    semantic_add_type(type_data, types, 3, 0, 0, 16, 0);
    semantic_add_type(type_data, types, 2, 0, 0, 32, 0);
    semantic_add_type(type_data, types, 3, 0, 0, 32, 0);
    semantic_add_type(type_data, types, 2, 0, 0, 64, 0);
    semantic_add_type(type_data, types, 3, 0, 0, 64, 0);
    semantic_add_type(type_data, types, 2, 0, 0, 0, 0);
    semantic_add_type(type_data, types, 3, 0, 0, 0, 0);
    semantic_add_type(type_data, types, 4, 0, 0, 32, 0);
    semantic_add_type(type_data, types, 4, 0, 0, 64, 0);
    semantic_add_type(type_data, types, 13, semantic_type_byte(), 0, 0, 0);
}

text semantic_builtin_name(usize type_id) {
    if type_id == 0 { return "<error>"; }
    if type_id == 1 { return "void"; }
    if type_id == 2 { return "bool"; }
    if type_id == 3 { return "byte"; }
    if type_id == 4 { return "text"; }
    if type_id == 5 { return "status"; }
    if type_id == 6 { return "i8"; }
    if type_id == 7 { return "u8"; }
    if type_id == 8 { return "i16"; }
    if type_id == 9 { return "u16"; }
    if type_id == 10 { return "i32"; }
    if type_id == 11 { return "u32"; }
    if type_id == 12 { return "i64"; }
    if type_id == 13 { return "u64"; }
    if type_id == 14 { return "isize"; }
    if type_id == 15 { return "usize"; }
    if type_id == 16 { return "f32"; }
    if type_id == 17 { return "f64"; }
    return "";
}

text semantic_type_kind_name(usize kind) {
    if kind == 0 { return "error"; }
    if kind == 1 { return "void"; }
    if kind == 2 { return "signed_integer"; }
    if kind == 3 { return "unsigned_integer"; }
    if kind == 4 { return "floating"; }
    if kind == 5 { return "bool"; }
    if kind == 6 { return "byte"; }
    if kind == 7 { return "text"; }
    if kind == 8 { return "status"; }
    if kind == 9 { return "named"; }
    if kind == 10 { return "fixed_array"; }
    if kind == 11 { return "slice"; }
    if kind == 12 { return "ref"; }
    if kind == 13 { return "ptr"; }
    if kind == 14 { return "optional"; }
    return "storage";
}

unsafe usize semantic_source_module(
    ptr byte module_data,
    ref PackedBuffer modules,
    usize source_record
) {
    usize module_index = 0;
    while module_index < modules.length {
        usize first = read_record_field(module_data, module_index, 2);
        usize count = read_record_field(module_data, module_index, 3);
        if source_record >= first && source_record < first + count {
            return module_index;
        }
        module_index = module_index + 1;
    }
    return 0;
}

bool semantic_spans_equal(
    text left,
    usize left_start,
    usize left_length,
    text right,
    usize right_start,
    usize right_length
) {
    if left_length != right_length { return false; }
    usize index = 0;
    while index < left_length {
        if byte_at_or_zero(left, left_start + index) !=
            byte_at_or_zero(right, right_start + index) {
            return false;
        }
        index = index + 1;
    }
    return true;
}

unsafe bool semantic_named_equals_span(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte type_data,
    usize type_id,
    text requested_source,
    usize requested_start,
    usize requested_length
) {
    if read_record_field(type_data, type_id, 0) != 9 { return false; }
    usize flags = read_record_field(type_data, type_id, 4);
    if (flags / 8) % 2 == 1 { return false; }
    usize source_record = read_record_field(type_data, type_id, 1);
    text declared_source;
    status declared_status = project_read_source_record(
        project_source, project_root, source_data, source_record,
        out declared_source
    );
    if !declared_status.ok { return false; }
    usize name_start = read_record_field(type_data, type_id, 2);
    usize name_length = read_record_field(type_data, type_id, 3);
    if (flags / 4) % 2 == 0 {
        return semantic_spans_equal(
            requested_source, requested_start, requested_length,
            declared_source, name_start, name_length
        );
    }
    usize module_index = semantic_source_module(
        module_data, modules, source_record
    );
    usize module_start = read_record_field(module_data, module_index, 0);
    usize module_length = read_record_field(module_data, module_index, 1);
    if requested_length != module_length + 1 + name_length { return false; }
    if !semantic_spans_equal(
        requested_source, requested_start, module_length,
        project_source, module_start, module_length
    ) { return false; }
    if byte_at_or_zero(requested_source, requested_start + module_length) != 46 {
        return false;
    }
    return semantic_spans_equal(
        requested_source, requested_start + module_length + 1, name_length,
        declared_source, name_start, name_length
    );
}

unsafe usize semantic_find_named(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte type_data,
    ref PackedBuffer types,
    text source,
    usize start,
    usize length
) {
    usize type_id = 19;
    while type_id < types.length {
        if semantic_named_equals_span(
            project_source, project_root,
            module_data, modules, source_data,
            type_data, type_id, source, start, length
        ) { return type_id; }
        type_id = type_id + 1;
    }
    return semantic_type_error();
}

unsafe bool semantic_declared_name_exists(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte type_data,
    ref PackedBuffer types,
    usize module_index,
    usize source_record,
    text source,
    usize start,
    usize length,
    bool qualified
) {
    usize type_id = 19;
    while type_id < types.length {
        if read_record_field(type_data, type_id, 0) == 9 &&
            (read_record_field(type_data, type_id, 4) / 8) % 2 == 0 {
            usize flags = read_record_field(type_data, type_id, 4);
            bool candidate_qualified = (flags / 4) % 2 == 1;
            if candidate_qualified == qualified {
                usize candidate_record = read_record_field(type_data, type_id, 1);
                if !qualified || semantic_source_module(
                    module_data, modules, candidate_record
                ) == module_index {
                    text candidate_source;
                    status candidate_status = project_read_source_record(
                        project_source, project_root, source_data, candidate_record,
                        out candidate_source
                    );
                    if candidate_status.ok {
                        if semantic_spans_equal(
                            source, start, length,
                            candidate_source,
                            read_record_field(type_data, type_id, 2),
                            read_record_field(type_data, type_id, 3)
                        ) { return true; }
                    }
                }
            }
        }
        type_id = type_id + 1;
    }
    return false;
}

unsafe usize semantic_declare_named(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte type_data,
    ref PackedBuffer types,
    usize module_index,
    usize source_record,
    text source,
    usize start,
    usize length,
    bool qualified,
    bool resource_type
) {
    if semantic_declared_name_exists(
        project_source, project_root,
        module_data, modules, source_data,
        type_data, types,
        module_index, source_record, source, start, length, qualified
    ) {
        if qualified {
            usize type_id = 19;
            while type_id < types.length {
                usize candidate_flags = read_record_field(type_data, type_id, 4);
                if read_record_field(type_data, type_id, 0) == 9 &&
                    (candidate_flags / 4) % 2 == 1 &&
                    (candidate_flags / 8) % 2 == 0 &&
                    semantic_source_module(
                        module_data, modules,
                        read_record_field(type_data, type_id, 1)
                    ) == module_index {
                    text candidate_source;
                    status candidate_status = project_read_source_record(
                        project_source, project_root, source_data,
                        read_record_field(type_data, type_id, 1),
                        out candidate_source
                    );
                    if candidate_status.ok {
                        if semantic_spans_equal(
                            source, start, length,
                            candidate_source,
                            read_record_field(type_data, type_id, 2),
                            read_record_field(type_data, type_id, 3)
                        ) { return type_id; }
                    }
                }
                type_id = type_id + 1;
            }
        } else {
            return semantic_find_named(
                project_source, project_root,
                module_data, modules, source_data,
                type_data, types, source, start, length
            );
        }
    }
    usize flags = 0;
    if resource_type { flags = flags + 2; }
    if qualified { flags = flags + 4; }
    return semantic_add_type(
        type_data, types, 9, source_record, start, length, flags
    );
}

unsafe usize semantic_builtin_type(
    text source,
    usize start,
    usize length
) {
    usize type_id = 1;
    while type_id < 18 {
        if span_equals_ascii(
            source, start, length, semantic_builtin_name(type_id)
        ) { return type_id; }
        type_id = type_id + 1;
    }
    return semantic_type_error();
}

unsafe usize semantic_derived_type(
    ptr byte type_data,
    ref PackedBuffer types,
    usize kind,
    usize element,
    usize length,
    bool const_qualified,
    bool preserve_name
) {
    usize flags = 0;
    if const_qualified { flags = flags + 1; }
    if preserve_name { flags = flags + 8; }
    usize type_id = 0;
    while type_id < types.length {
        if read_record_field(type_data, type_id, 0) == kind &&
            read_record_field(type_data, type_id, 1) == element &&
            read_record_field(type_data, type_id, 2) == length &&
            read_record_field(type_data, type_id, 4) == flags {
            if kind >= 10 || preserve_name { return type_id; }
        }
        type_id = type_id + 1;
    }
    return semantic_add_type(
        type_data, types, kind, element, length, 0, flags
    );
}

unsafe usize semantic_token_at_or_after(
    ptr byte token_data,
    ref PackedBuffer tokens,
    usize start
) {
    usize token = 0;
    while token < tokens.length &&
        read_record_field(token_data, token, 1) < start {
        token = token + 1;
    }
    return token;
}

unsafe usize semantic_array_length(
    text source,
    ptr byte token_data,
    ref PackedBuffer tokens,
    usize token,
    usize end
) {
    if token >= tokens.length { return 0; }
    usize start = read_record_field(token_data, token, 1);
    usize length = read_record_field(token_data, token, 2);
    if start + length > end { return 0; }
    usize value = 0;
    usize index = 0;
    while index < length {
        u8 octet = byte_at_or_zero(source, start + index);
        if octet < 48 || octet > 57 { return 0; }
        value = value * 10 + cast(usize, octet - 48);
        index = index + 1;
    }
    return value;
}

unsafe usize semantic_resolve_type(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    usize source_record,
    text source,
    ptr byte token_data,
    ref PackedBuffer tokens,
    ptr byte type_data,
    ref PackedBuffer types,
    usize start,
    usize length
) {
    usize end = start + length;
    usize token = semantic_token_at_or_after(token_data, tokens, start);
    bool leading_const = false;
    if token < tokens.length && span_equals_ascii(
        source,
        read_record_field(token_data, token, 1),
        read_record_field(token_data, token, 2),
        "const"
    ) {
        leading_const = true;
        token = token + 1;
    }
    usize constructor = 0;
    if token < tokens.length {
        usize token_start_value = read_record_field(token_data, token, 1);
        usize token_length_value = read_record_field(token_data, token, 2);
        if span_equals_ascii(source, token_start_value, token_length_value, "ref") {
            constructor = 12; token = token + 1;
        } else if span_equals_ascii(source, token_start_value, token_length_value, "ptr") {
            constructor = 13; token = token + 1;
        } else if span_equals_ascii(source, token_start_value, token_length_value, "optional") {
            constructor = 14; token = token + 1;
        } else if span_equals_ascii(source, token_start_value, token_length_value, "storage") {
            constructor = 15; token = token + 1;
        }
    }
    bool constructor_const = false;
    if (constructor == 12 || constructor == 13) && token < tokens.length &&
        span_equals_ascii(
            source,
            read_record_field(token_data, token, 1),
            read_record_field(token_data, token, 2),
            "const"
        ) {
        constructor_const = true;
        token = token + 1;
    }
    if token >= tokens.length { return semantic_type_error(); }
    usize base_start = read_record_field(token_data, token, 1);
    usize base_end = base_start + read_record_field(token_data, token, 2);
    token = token + 1;
    while token < tokens.length &&
        read_record_field(token_data, token, 1) < end &&
        !span_equals_ascii(
            source,
            read_record_field(token_data, token, 1),
            read_record_field(token_data, token, 2),
            "["
        ) {
        base_end = read_record_field(token_data, token, 1) +
            read_record_field(token_data, token, 2);
        token = token + 1;
    }
    usize base_length = base_end - base_start;
    usize result = semantic_builtin_type(source, base_start, base_length);
    if result == semantic_type_error() {
        result = semantic_find_named(
            project_source, project_root,
            module_data, modules, source_data,
            type_data, types,
            source, base_start, base_length
        );
        if result == semantic_type_error() {
            usize module_index = semantic_source_module(
                module_data, modules, source_record
            );
            result = semantic_declare_named(
                project_source, project_root,
                module_data, modules, source_data,
                type_data, types,
                module_index, source_record, source,
                base_start, base_length, false, false
            );
        }
    }
    bool const_qualified = leading_const || constructor_const;
    if constructor == 12 || constructor == 13 || constructor == 14 || constructor == 15 {
        result = semantic_derived_type(
            type_data, types, constructor, result, 0,
            const_qualified, false
        );
    } else if const_qualified {
        result = semantic_derived_type(
            type_data, types,
            read_record_field(type_data, result, 0), result, 0,
            true, true
        );
    }
    if token < tokens.length &&
        span_equals_ascii(
            source,
            read_record_field(token_data, token, 1),
            read_record_field(token_data, token, 2),
            "["
        ) {
        token = token + 1;
        bool slice = token < tokens.length && span_equals_ascii(
            source,
            read_record_field(token_data, token, 1),
            read_record_field(token_data, token, 2),
            "]"
        );
        if slice {
            result = semantic_derived_type(
                type_data, types, 11, result, 0, false, false
            );
        } else {
            usize array_length = semantic_array_length(
                source, token_data, tokens, token, end
            );
            result = semantic_derived_type(
                type_data, types, 10, result, array_length, false, false
            );
        }
    }
    return result;
}

unsafe bool semantic_node_contains(
    ptr byte syntax_data,
    usize parent,
    usize child
) {
    usize parent_start = read_record_field(syntax_data, parent, 1);
    usize parent_end = parent_start + read_record_field(syntax_data, parent, 2);
    usize child_start = read_record_field(syntax_data, child, 1);
    usize child_end = child_start + read_record_field(syntax_data, child, 2);
    return child_start >= parent_start && child_end <= parent_end;
}

unsafe bool semantic_inside_when(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize node
) {
    usize record = 0;
    while record < syntax.length {
        if record != node && read_record_field(syntax_data, record, 0) == 8 &&
            semantic_node_contains(syntax_data, record, node) {
            return true;
        }
        record = record + 1;
    }
    return false;
}

unsafe usize semantic_find_prefix_type(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize declaration
) {
    usize start = read_record_field(syntax_data, declaration, 1);
    usize name_start = read_record_field(syntax_data, declaration, 3);
    usize record = 0;
    while record < syntax.length {
        usize node_start = read_record_field(syntax_data, record, 1);
        usize node_end = node_start + read_record_field(syntax_data, record, 2);
        if read_record_field(syntax_data, record, 0) == 26 &&
            node_start >= start && node_end <= name_start {
            return record;
        }
        record = record + 1;
    }
    return syntax.length;
}

unsafe bool semantic_prefix_has(
    text source,
    ptr byte token_data,
    ref PackedBuffer tokens,
    usize start,
    usize end,
    text expected
) {
    usize token = semantic_token_at_or_after(token_data, tokens, start);
    while token < tokens.length &&
        read_record_field(token_data, token, 1) < end {
        if span_equals_ascii(
            source,
            read_record_field(token_data, token, 1),
            read_record_field(token_data, token, 2),
            expected
        ) { return true; }
        token = token + 1;
    }
    return false;
}

unsafe bool semantic_same_name_record(
    text project_source,
    text project_root,
    ptr byte source_data,
    ptr byte symbol_data,
    usize symbol,
    text source,
    usize name_start,
    usize name_length
) {
    text prior_source;
    status prior_status = project_read_source_record(
        project_source, project_root, source_data,
        read_record_field(symbol_data, symbol, 1),
        out prior_source
    );
    if !prior_status.ok { return false; }
    return semantic_spans_equal(
        source, name_start, name_length,
        prior_source,
        read_record_field(symbol_data, symbol, 2),
        read_record_field(symbol_data, symbol, 3)
    );
}

unsafe void semantic_record_error(
    ptr byte error_data,
    ref PackedBuffer errors,
    usize source_record,
    usize start,
    usize length,
    usize rule
) {
    usize record = errors.length;
    write_record_field(error_data, record, 0, source_record);
    write_record_field(error_data, record, 1, start);
    write_record_field(error_data, record, 2, length);
    write_record_field(error_data, record, 3, rule);
    write_record_field(error_data, record, 4, 0);
    errors.length = errors.length + 1;
}

unsafe bool semantic_type_resource(ptr byte type_data, usize type_id) {
    return (read_record_field(type_data, type_id, 4) / 2) % 2 == 1;
}

unsafe void semantic_emit_named_type(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte type_data,
    usize type_id
) {
    usize source_record = read_record_field(type_data, type_id, 1);
    text source;
    status source_status = project_read_source_record(
        project_source, project_root, source_data, source_record,
        out source
    );
    if !source_status.ok { return; }
    usize flags = read_record_field(type_data, type_id, 4);
    if (flags / 4) % 2 == 1 {
        usize module_index = semantic_source_module(
            module_data, modules, source_record
        );
        project_emit_hex(project_slice(
            project_source,
            read_record_field(module_data, module_index, 0),
            read_record_field(module_data, module_index, 1)
        ));
        io.print("2e");
    }
    project_emit_hex(project_slice(
        source,
        read_record_field(type_data, type_id, 2),
        read_record_field(type_data, type_id, 3)
    ));
}

void semantic_emit_decimal_hex(usize value) {
    if value >= 10 { semantic_emit_decimal_hex(value / 10); }
    usize octet = 48 + value % 10;
    io.print(project_hex_digit(octet / 16));
    io.print(project_hex_digit(octet % 16));
}

unsafe void semantic_emit_type_display(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte type_data,
    usize type_id
) {
    if type_id < 18 {
        project_emit_hex(semantic_builtin_name(type_id));
        return;
    }
    usize kind = read_record_field(type_data, type_id, 0);
    usize flags = read_record_field(type_data, type_id, 4);
    if (flags / 8) % 2 == 1 {
        project_emit_hex("const ");
        semantic_emit_type_display(
            project_source, project_root,
            module_data, modules, source_data,
            type_data, read_record_field(type_data, type_id, 1)
        );
        return;
    }
    if kind == 9 {
        semantic_emit_named_type(
            project_source, project_root,
            module_data, modules, source_data,
            type_data, type_id
        );
        return;
    }
    if kind == 12 { project_emit_hex("ref "); }
    if kind == 13 { project_emit_hex("ptr "); }
    if kind == 14 { project_emit_hex("optional "); }
    if kind == 15 { project_emit_hex("storage "); }
    if (kind == 12 || kind == 13 || kind == 14) && flags % 2 == 1 {
        project_emit_hex("const ");
    }
    semantic_emit_type_display(
        project_source, project_root,
        module_data, modules, source_data,
        type_data, read_record_field(type_data, type_id, 1)
    );
    if kind == 10 {
        io.print("5b");
        semantic_emit_decimal_hex(read_record_field(type_data, type_id, 2));
        io.print("5d");
    }
    if kind == 11 { io.print("5b5d"); }
}

unsafe void semantic_emit_type_table(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte type_data,
    ref PackedBuffer types
) {
    usize type_id = 0;
    while type_id < types.length {
        usize kind = read_record_field(type_data, type_id, 0);
        usize flags = read_record_field(type_data, type_id, 4);
        io.print("TYPE ");
        io.print(type_id);
        io.print(" ");
        io.print(semantic_type_kind_name(kind));
        io.print(" ");
        semantic_emit_type_display(
            project_source, project_root,
            module_data, modules, source_data,
            type_data, type_id
        );
        io.print(" ");
        if kind >= 10 || (flags / 8) % 2 == 1 {
            io.print(read_record_field(type_data, type_id, 1));
        } else {
            io.print("0");
        }
        io.print(" ");
        if kind == 10 { io.print(read_record_field(type_data, type_id, 2)); }
        else { io.print("0"); }
        io.print(" ");
        if type_id < 18 { io.print(read_record_field(type_data, type_id, 3)); }
        else { io.print("0"); }
        io.print(" ");
        io.print(flags % 2);
        io.print(" ");
        io.println((flags / 2) % 2);
        type_id = type_id + 1;
    }
}

unsafe void semantic_predeclare_source(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    usize module_index,
    usize source_record,
    ptr byte type_data,
    ref PackedBuffer types
) {
    text source;
    status source_status = project_read_source_record(
        project_source, project_root, source_data, source_record,
        out source
    );
    if !source_status.ok { return; }
    usize source_length = text.byte_length(source);
    PackedBuffer tokens = PackedBuffer{ length = 0, capacity = source_length + 2 };
    PackedBuffer diagnostics = PackedBuffer{ length = 0, capacity = source_length * 4 + 8 };
    ptr byte token_data = memory.alloc(tokens.capacity * record_stride());
    scope memory.free(token_data);
    ptr byte diagnostic_data = memory.alloc(diagnostics.capacity * record_stride());
    scope memory.free(diagnostic_data);
    lex_source(source, token_data, tokens, diagnostic_data, diagnostics);
    PackedBuffer syntax = PackedBuffer{ length = 0, capacity = tokens.length * 6 + 8 };
    ptr byte syntax_data = memory.alloc(syntax.capacity * record_stride());
    scope memory.free(syntax_data);
    parse_source_syntax(
        source, token_data, tokens,
        syntax_data, syntax,
        diagnostic_data, diagnostics
    );
    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        if (kind == 3 || kind == 4 || kind == 5) &&
            !semantic_inside_when(syntax_data, syntax, record) {
            usize name_start = read_record_field(syntax_data, record, 3);
            usize name_length = read_record_field(syntax_data, record, 4);
            semantic_declare_named(
                project_source, project_root,
                module_data, modules, source_data,
                type_data, types,
                module_index, source_record, source,
                name_start, name_length, true, kind == 4
            );
            semantic_declare_named(
                project_source, project_root,
                module_data, modules, source_data,
                type_data, types,
                module_index, source_record, source,
                name_start, name_length, false, kind == 4
            );
        }
        record = record + 1;
    }
}

unsafe void semantic_emit_source_declarations(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    usize module_index,
    usize source_index,
    usize source_record,
    ptr byte type_data,
    ref PackedBuffer types,
    ptr byte symbol_data,
    ref PackedBuffer symbols,
    ptr byte error_data,
    ref PackedBuffer errors,
    ref SemanticCounts counts
) {
    text source;
    status source_status = project_read_source_record(
        project_source, project_root, source_data, source_record,
        out source
    );
    if !source_status.ok { return; }
    usize source_length = text.byte_length(source);
    PackedBuffer tokens = PackedBuffer{ length = 0, capacity = source_length + 2 };
    PackedBuffer diagnostics = PackedBuffer{ length = 0, capacity = source_length * 4 + 8 };
    ptr byte token_data = memory.alloc(tokens.capacity * record_stride());
    scope memory.free(token_data);
    ptr byte diagnostic_data = memory.alloc(diagnostics.capacity * record_stride());
    scope memory.free(diagnostic_data);
    lex_source(source, token_data, tokens, diagnostic_data, diagnostics);
    PackedBuffer syntax = PackedBuffer{ length = 0, capacity = tokens.length * 6 + 8 };
    ptr byte syntax_data = memory.alloc(syntax.capacity * record_stride());
    scope memory.free(syntax_data);
    parse_source_syntax(
        source, token_data, tokens,
        syntax_data, syntax,
        diagnostic_data, diagnostics
    );

    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        if kind == 2 || kind == 3 || kind == 4 || kind == 5 || kind == 7 {
            usize name_start = read_record_field(syntax_data, record, 3);
            usize name_length = read_record_field(syntax_data, record, 4);
            usize type_id = semantic_type_error();
            usize type_node = semantic_find_prefix_type(syntax_data, syntax, record);
            if kind == 2 || kind == 7 {
                type_id = semantic_resolve_type(
                    project_source, project_root,
                    module_data, modules, source_data, source_record,
                    source, token_data, tokens,
                    type_data, types,
                    read_record_field(syntax_data, type_node, 1),
                    read_record_field(syntax_data, type_node, 2)
                );
            } else {
                type_id = semantic_find_named(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, types,
                    source, name_start, name_length
                );
            }
            if kind != 2 {
                usize prior = 0;
                while prior < symbols.length {
                    if read_record_field(symbol_data, prior, 0) == module_index &&
                        semantic_same_name_record(
                            project_source, project_root, source_data,
                            symbol_data, prior,
                            source, name_start, name_length
                        ) {
                        semantic_record_error(
                            error_data, errors, source_record,
                            read_record_field(syntax_data, record, 1),
                            read_record_field(syntax_data, record, 2), 1
                        );
                        break;
                    }
                    prior = prior + 1;
                }
            }
            usize symbol_record = symbols.length;
            write_record_field(symbol_data, symbol_record, 0, module_index);
            write_record_field(symbol_data, symbol_record, 1, source_record);
            write_record_field(symbol_data, symbol_record, 2, name_start);
            write_record_field(symbol_data, symbol_record, 3, name_length);
            write_record_field(symbol_data, symbol_record, 4, kind);
            symbols.length = symbols.length + 1;

            io.print("DECL ");
            io.print(counts.declarations);
            io.print(" ");
            io.print(module_index);
            io.print(" ");
            io.print(source_index);
            io.print(" ");
            if kind == 2 { io.print("function"); }
            if kind == 3 { io.print("struct"); }
            if kind == 4 { io.print("resource"); }
            if kind == 5 { io.print("enum"); }
            if kind == 7 { io.print("constant"); }
            io.print(" ");
            usize node_start = read_record_field(syntax_data, record, 1);
            bool exported = semantic_prefix_has(
                source, token_data, tokens, node_start, name_start, "export"
            );
            if exported { io.print("exported"); }
            else { io.print("private"); }
            io.print(" ");
            project_emit_hex(project_slice(source, name_start, name_length));
            io.print(" ");
            io.print(node_start);
            io.print(" ");
            io.print(read_record_field(syntax_data, record, 2));
            io.print(" ");
            semantic_emit_type_display(
                project_source, project_root,
                module_data, modules, source_data,
                type_data, type_id
            );
            io.print(" ");
            if kind == 2 && semantic_prefix_has(
                source, token_data, tokens,
                node_start,
                read_record_field(syntax_data, type_node, 1),
                "unsafe"
            ) { io.print("1"); } else { io.print("0"); }
            io.print(" ");
            if kind == 2 && semantic_prefix_has(
                source, token_data, tokens,
                node_start,
                read_record_field(syntax_data, type_node, 1),
                "own"
            ) { io.print("1"); } else { io.print("0"); }
            io.print(" ");
            if kind == 4 { io.println("1"); }
            else { io.println("0"); }

            if kind == 2 {
                usize detail = 0;
                usize parameter_index = 0;
                while detail < syntax.length {
                    if read_record_field(syntax_data, detail, 0) == 10 &&
                        semantic_node_contains(syntax_data, record, detail) {
                        usize detail_type = semantic_find_prefix_type(
                            syntax_data, syntax, detail
                        );
                        usize detail_type_id = semantic_resolve_type(
                            project_source, project_root,
                            module_data, modules, source_data, source_record,
                            source, token_data, tokens,
                            type_data, types,
                            read_record_field(syntax_data, detail_type, 1),
                            read_record_field(syntax_data, detail_type, 2)
                        );
                        usize detail_start = read_record_field(syntax_data, detail, 1);
                        usize detail_name_start = read_record_field(syntax_data, detail, 3);
                        io.print("PARAM ");
                        io.print(counts.declarations);
                        io.print(" ");
                        io.print(parameter_index);
                        io.print(" ");
                        bool out_mode = semantic_prefix_has(
                            source, token_data, tokens,
                            detail_start,
                            read_record_field(syntax_data, detail_type, 1),
                            "out"
                        );
                        bool own_mode = semantic_prefix_has(
                            source, token_data, tokens,
                            detail_start,
                            read_record_field(syntax_data, detail_type, 1),
                            "own"
                        );
                        if out_mode && own_mode { io.print("out_own"); }
                        else if out_mode { io.print("out"); }
                        else if own_mode { io.print("own"); }
                        else { io.print("value"); }
                        io.print(" ");
                        project_emit_hex(project_slice(
                            source, detail_name_start,
                            read_record_field(syntax_data, detail, 4)
                        ));
                        io.print(" ");
                        io.print(detail_start);
                        io.print(" ");
                        io.print(read_record_field(syntax_data, detail, 2));
                        io.print(" ");
                        semantic_emit_type_display(
                            project_source, project_root,
                            module_data, modules, source_data,
                            type_data, detail_type_id
                        );
                        io.println("");
                        parameter_index = parameter_index + 1;
                        counts.parameters = counts.parameters + 1;
                    }
                    detail = detail + 1;
                }
            }
            if kind == 3 || kind == 4 {
                usize detail = 0;
                usize member_index = 0;
                while detail < syntax.length {
                    if read_record_field(syntax_data, detail, 0) == 9 &&
                        semantic_node_contains(syntax_data, record, detail) {
                        usize detail_type = semantic_find_prefix_type(
                            syntax_data, syntax, detail
                        );
                        usize detail_type_id = semantic_resolve_type(
                            project_source, project_root,
                            module_data, modules, source_data, source_record,
                            source, token_data, tokens,
                            type_data, types,
                            read_record_field(syntax_data, detail_type, 1),
                            read_record_field(syntax_data, detail_type, 2)
                        );
                        usize detail_name_start = read_record_field(syntax_data, detail, 3);
                        usize earlier = 0;
                        while earlier < detail {
                            if read_record_field(syntax_data, earlier, 0) == 9 &&
                                semantic_node_contains(syntax_data, record, earlier) &&
                                semantic_spans_equal(
                                    source, detail_name_start,
                                    read_record_field(syntax_data, detail, 4),
                                    source,
                                    read_record_field(syntax_data, earlier, 3),
                                    read_record_field(syntax_data, earlier, 4)
                                ) {
                                semantic_record_error(
                                    error_data, errors, source_record,
                                    read_record_field(syntax_data, detail, 1),
                                    read_record_field(syntax_data, detail, 2), 2
                                );
                                break;
                            }
                            earlier = earlier + 1;
                        }
                        io.print("FIELD ");
                        io.print(counts.declarations);
                        io.print(" ");
                        io.print(member_index);
                        io.print(" ");
                        project_emit_hex(project_slice(
                            source, detail_name_start,
                            read_record_field(syntax_data, detail, 4)
                        ));
                        io.print(" ");
                        io.print(read_record_field(syntax_data, detail, 1));
                        io.print(" ");
                        io.print(read_record_field(syntax_data, detail, 2));
                        io.print(" ");
                        semantic_emit_type_display(
                            project_source, project_root,
                            module_data, modules, source_data,
                            type_data, detail_type_id
                        );
                        io.print(" ");
                        bool owning_field = kind == 4 && semantic_prefix_has(
                            source, token_data, tokens,
                            read_record_field(syntax_data, detail, 1),
                            read_record_field(syntax_data, detail_type, 1),
                            "own"
                        );
                        if owning_field || semantic_type_resource(type_data, detail_type_id) {
                            io.println("1");
                        } else { io.println("0"); }
                        member_index = member_index + 1;
                        counts.fields = counts.fields + 1;
                    }
                    detail = detail + 1;
                }
            }
            if kind == 5 {
                usize detail = 0;
                usize member_index = 0;
                while detail < syntax.length {
                    if read_record_field(syntax_data, detail, 0) == 6 &&
                        semantic_node_contains(syntax_data, record, detail) {
                        io.print("ITEM ");
                        io.print(counts.declarations);
                        io.print(" ");
                        io.print(member_index);
                        io.print(" ");
                        project_emit_hex(project_slice(
                            source,
                            read_record_field(syntax_data, detail, 3),
                            read_record_field(syntax_data, detail, 4)
                        ));
                        io.print(" ");
                        io.print(read_record_field(syntax_data, detail, 1));
                        io.print(" ");
                        io.print(read_record_field(syntax_data, detail, 2));
                        io.print(" ");
                        semantic_emit_type_display(
                            project_source, project_root,
                            module_data, modules, source_data,
                            type_data, type_id
                        );
                        io.println("");
                        member_index = member_index + 1;
                        counts.items = counts.items + 1;
                    }
                    detail = detail + 1;
                }
            }
            counts.declarations = counts.declarations + 1;
        }
        record = record + 1;
    }
}

unsafe i32 observe_semantic_declarations(text project_path) {
    io.println("OPENC-SEMANTIC-DECL-OBSERVATION 1");
    text project_source;
    status loaded_project = file.read_text(project_path, out project_source);
    if !loaded_project.ok {
        io.println("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
        io.println("SUMMARY 0 0 0 0 0 0 1");
        return 1;
    }
    usize project_length = text.byte_length(project_source);
    PackedBuffer modules = PackedBuffer{ length = 0, capacity = project_length + 1 };
    PackedBuffer sources = PackedBuffer{ length = 0, capacity = project_length + 1 };
    ptr byte module_data = memory.alloc(modules.capacity * record_stride());
    scope memory.free(module_data);
    ptr byte source_data = memory.alloc(sources.capacity * record_stride());
    scope memory.free(source_data);
    if !project_parse_json(
        project_source, module_data, modules, source_data, sources
    ) {
        io.println("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
        io.println("SUMMARY 0 0 0 0 0 0 1");
        return 1;
    }
    project_sort_modules(project_source, module_data, modules);
    text project_root = path.directory(project_path);
    usize total_source_length = 0;
    usize module_index = 0;
    while module_index < modules.length {
        io.print("MODULE ");
        io.print(module_index);
        io.print(" ");
        project_emit_hex(project_slice(
            project_source,
            read_record_field(module_data, module_index, 0),
            read_record_field(module_data, module_index, 1)
        ));
        io.print(" ");
        io.println(read_record_field(module_data, module_index, 3));
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            text source;
            status source_status = project_read_source_record(
                project_source, project_root, source_data,
                source_first + source_index, out source
            );
            if !source_status.ok {
                io.print("PROJECT_ERROR OPENC-PROJECT-SOURCE-READ-001 ");
                io.print(module_index);
                io.print(" ");
                io.println(source_index);
                io.print("SUMMARY ");
                io.print(modules.length);
                io.println(" 0 0 0 0 0 1");
                return 1;
            }
            total_source_length = total_source_length + text.byte_length(source);
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    usize capacity = total_source_length + project_length + 64;
    PackedBuffer types = PackedBuffer{ length = 0, capacity = capacity };
    PackedBuffer symbols = PackedBuffer{ length = 0, capacity = capacity };
    PackedBuffer errors = PackedBuffer{ length = 0, capacity = capacity };
    ptr byte type_data = memory.alloc(types.capacity * record_stride());
    scope memory.free(type_data);
    ptr byte symbol_data = memory.alloc(symbols.capacity * record_stride());
    scope memory.free(symbol_data);
    ptr byte error_data = memory.alloc(errors.capacity * record_stride());
    scope memory.free(error_data);
    semantic_initialize_types(type_data, types);

    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            semantic_predeclare_source(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_first + source_index,
                type_data, types
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }

    SemanticCounts counts = SemanticCounts{
        declarations = 0,
        parameters = 0,
        fields = 0,
        items = 0
    };
    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            semantic_emit_source_declarations(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_index, source_first + source_index,
                type_data, types,
                symbol_data, symbols,
                error_data, errors, counts
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    semantic_emit_type_table(
        project_source, project_root,
        module_data, modules, source_data,
        type_data, types
    );
    usize error = 0;
    while error < errors.length {
        usize source_record = read_record_field(error_data, error, 0);
        usize error_module = semantic_source_module(
            module_data, modules, source_record
        );
        usize source_first = read_record_field(module_data, error_module, 2);
        io.print("ERROR OPENC-NAME-DUPLICATE-001 ");
        io.print(error_module);
        io.print(" ");
        io.print(source_record - source_first);
        io.print(" ");
        io.print(read_record_field(error_data, error, 1));
        io.print(" ");
        io.println(read_record_field(error_data, error, 2));
        error = error + 1;
    }
    io.print("SUMMARY ");
    io.print(modules.length);
    io.print(" ");
    io.print(sources.length);
    io.print(" ");
    io.print(counts.declarations);
    io.print(" ");
    io.print(counts.parameters);
    io.print(" ");
    io.print(counts.fields);
    io.print(" ");
    io.print(counts.items);
    io.print(" ");
    io.println(errors.length);
    if errors.length != 0 { return 1; }
    return 0;
}
