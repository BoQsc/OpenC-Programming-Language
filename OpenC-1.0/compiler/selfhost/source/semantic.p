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
