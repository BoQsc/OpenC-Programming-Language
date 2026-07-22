import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

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
