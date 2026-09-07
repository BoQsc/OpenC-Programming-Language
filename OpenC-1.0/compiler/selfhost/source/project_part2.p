import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe bool project_parse_json(
    text source,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ref PackedBuffer sources
) {
    JsonState state = JsonState{ cursor = 0, failed = false };
    if !project_json_take(source, state, 123) { return false; }
    project_json_skip_space(source, state);
    if byte_at_or_zero(source, state.cursor) == 125 {
        state.cursor = state.cursor + 1;
    } else {
        while !state.failed {
            TextSpan key = project_json_string(source, state);
            if !project_json_take(source, state, 58) { return false; }
            if span_equals_ascii(source, key.start, key.length, "modules") {
                project_parse_modules(
                    source, state,
                    module_data, modules,
                    source_data, sources
                );
            } else {
                project_json_skip_value(source, state);
            }
            if state.failed { return false; }
            project_json_skip_space(source, state);
            u8 next = byte_at_or_zero(source, state.cursor);
            if next == 125 {
                state.cursor = state.cursor + 1;
                break;
            }
            if next != 44 { return false; }
            state.cursor = state.cursor + 1;
        }
    }
    project_json_skip_space(source, state);
    return !state.failed && state.cursor == text.byte_length(source);
}

unsafe i32 project_compare_spans(
    text source,
    usize left_start,
    usize left_length,
    usize right_start,
    usize right_length
) {
    usize common = left_length;
    if right_length < common { common = right_length; }
    usize index = 0;
    while index < common {
        u8 left = byte_at_or_zero(source, left_start + index);
        u8 right = byte_at_or_zero(source, right_start + index);
        if left < right { return -1; }
        if left > right { return 1; }
        index = index + 1;
    }
    if left_length < right_length { return -1; }
    if left_length > right_length { return 1; }
    return 0;
}

unsafe void project_swap_records(ptr byte data, usize left, usize right) {
    usize field = 0;
    while field < 5 {
        usize value = read_record_field(data, left, field);
        write_record_field(data, left, field, read_record_field(data, right, field));
        write_record_field(data, right, field, value);
        field = field + 1;
    }
}

unsafe void project_sort_modules(
    text project_source,
    ptr byte module_data,
    ref PackedBuffer modules
) {
    usize index = 1;
    while index < modules.length {
        usize current = index;
        while current > 0 && project_compare_spans(
            project_source,
            read_record_field(module_data, current - 1, 0),
            read_record_field(module_data, current - 1, 1),
            read_record_field(module_data, current, 0),
            read_record_field(module_data, current, 1)
        ) > 0 {
            project_swap_records(module_data, current - 1, current);
            current = current - 1;
        }
        index = index + 1;
    }
}

text project_slice(text source, usize start, usize length) {
    text value;
    status sliced = text.slice(source, start, start + length, out value);
    if !sliced.ok { return ""; }
    return value;
}

unsafe bool project_module_is(
    text project_source,
    ptr byte module_data,
    usize module_record,
    text expected
) {
    return span_equals_ascii(
        project_source,
        read_record_field(module_data, module_record, 0),
        read_record_field(module_data, module_record, 1),
        expected
    );
}

unsafe bool project_has_module(
    text project_source,
    ptr byte module_data,
    ref PackedBuffer modules,
    text name
) {
    usize module_record = 0;
    while module_record < modules.length {
        if project_module_is(project_source, module_data, module_record, name) {
            return true;
        }
        module_record = module_record + 1;
    }
    return false;
}

bool project_builtin_module(text name) {
    if name == "system.io" { return true; }
    if name == "system.memory" { return true; }
    if name == "system.text" { return true; }
    if name == "system.process" { return true; }
    if name == "system.path" { return true; }
    if name == "system.file" { return true; }
    if name == "windows.raw.foundation" { return true; }
    if name == "windows.raw.file" { return true; }
    if name == "windows.raw.memory" { return true; }
    if name == "windows.raw.process" { return true; }
    if name == "windows.raw.thread" { return true; }
    if name == "windows.raw.window" { return true; }
    return name == "windows.raw.graphics";
}
