import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

struct JsonState {
    usize cursor;
    bool failed;
}

struct TextSpan {
    usize start;
    usize length;
}

text project_hex_digit(usize value) {
    if value == 0 { return "0"; }
    if value == 1 { return "1"; }
    if value == 2 { return "2"; }
    if value == 3 { return "3"; }
    if value == 4 { return "4"; }
    if value == 5 { return "5"; }
    if value == 6 { return "6"; }
    if value == 7 { return "7"; }
    if value == 8 { return "8"; }
    if value == 9 { return "9"; }
    if value == 10 { return "a"; }
    if value == 11 { return "b"; }
    if value == 12 { return "c"; }
    if value == 13 { return "d"; }
    if value == 14 { return "e"; }
    return "f";
}

void project_emit_hex(text value) {
    usize index = 0;
    usize length = text.byte_length(value);
    while index < length {
        usize octet = cast(usize, byte_at_or_zero(value, index));
        io.print(project_hex_digit(octet / 16));
        io.print(project_hex_digit(octet % 16));
        index = index + 1;
    }
}

bool project_json_space(u8 value) {
    return value == 32 || value == 9 || value == 10 || value == 13;
}

void project_json_skip_space(text source, ref JsonState state) {
    usize length = text.byte_length(source);
    while state.cursor < length && project_json_space(byte_at_or_zero(source, state.cursor)) {
        state.cursor = state.cursor + 1;
    }
}

bool project_json_take(text source, ref JsonState state, u8 expected) {
    project_json_skip_space(source, state);
    if byte_at_or_zero(source, state.cursor) != expected {
        state.failed = true;
        return false;
    }
    state.cursor = state.cursor + 1;
    return true;
}

bool project_json_escape(u8 value) {
    return value == 34 || value == 47 || value == 92 || value == 98 ||
        value == 102 || value == 110 || value == 114 || value == 116;
}

TextSpan project_json_string(text source, ref JsonState state) {
    TextSpan result = TextSpan{ start = state.cursor, length = 0 };
    if !project_json_take(source, state, 34) { return result; }
    usize length = text.byte_length(source);
    result.start = state.cursor;
    while state.cursor < length {
        u8 value = byte_at_or_zero(source, state.cursor);
        if value == 34 {
            result.length = state.cursor - result.start;
            state.cursor = state.cursor + 1;
            return result;
        }
        if value < 32 {
            state.failed = true;
            return result;
        }
        if value == 92 {
            state.cursor = state.cursor + 1;
            u8 escaped = byte_at_or_zero(source, state.cursor);
            if escaped == 117 {
                usize digit = 0;
                while digit < 4 {
                    state.cursor = state.cursor + 1;
                    if !is_hex_digit(byte_at_or_zero(source, state.cursor)) {
                        state.failed = true;
                        return result;
                    }
                    digit = digit + 1;
                }
            } else if !project_json_escape(escaped) {
                state.failed = true;
                return result;
            }
        }
        state.cursor = state.cursor + 1;
    }
    state.failed = true;
    return result;
}

void project_json_skip_value(text source, ref JsonState state) {
    project_json_skip_space(source, state);
    usize length = text.byte_length(source);
    if state.cursor >= length {
        state.failed = true;
        return;
    }
    if byte_at_or_zero(source, state.cursor) == 34 {
        project_json_string(source, state);
        return;
    }
    u8 first = byte_at_or_zero(source, state.cursor);
    if first == 123 || first == 91 {
        usize depth = 0;
        while state.cursor < length {
            u8 value = byte_at_or_zero(source, state.cursor);
            if value == 34 {
                project_json_string(source, state);
                if state.failed { return; }
                continue;
            }
            if value == 123 || value == 91 { depth = depth + 1; }
            if value == 125 || value == 93 {
                if depth == 0 {
                    state.failed = true;
                    return;
                }
                depth = depth - 1;
                state.cursor = state.cursor + 1;
                if depth == 0 { return; }
                continue;
            }
            state.cursor = state.cursor + 1;
        }
        state.failed = true;
        return;
    }
    usize start = state.cursor;
    while state.cursor < length {
        u8 value = byte_at_or_zero(source, state.cursor);
        if project_json_space(value) || value == 44 || value == 125 || value == 93 {
            break;
        }
        state.cursor = state.cursor + 1;
    }
    if state.cursor == start { state.failed = true; }
}

unsafe void project_record_source(
    ptr byte source_data,
    ref PackedBuffer sources,
    TextSpan source_path
) {
    usize record = sources.length;
    write_record_field(source_data, record, 0, source_path.start);
    write_record_field(source_data, record, 1, source_path.length);
    write_record_field(source_data, record, 2, 0);
    write_record_field(source_data, record, 3, 0);
    write_record_field(source_data, record, 4, 0);
    sources.length = sources.length + 1;
}

unsafe void project_parse_source_array(
    text source,
    ref JsonState state,
    ptr byte source_data,
    ref PackedBuffer sources
) {
    if !project_json_take(source, state, 91) { return; }
    project_json_skip_space(source, state);
    if byte_at_or_zero(source, state.cursor) == 93 {
        state.cursor = state.cursor + 1;
        return;
    }
    while !state.failed {
        TextSpan source_path = project_json_string(source, state);
        if state.failed { return; }
        project_record_source(source_data, sources, source_path);
        project_json_skip_space(source, state);
        u8 next = byte_at_or_zero(source, state.cursor);
        if next == 93 {
            state.cursor = state.cursor + 1;
            return;
        }
        if next != 44 {
            state.failed = true;
            return;
        }
        state.cursor = state.cursor + 1;
    }
}

unsafe void project_record_module(
    ptr byte module_data,
    ref PackedBuffer modules,
    TextSpan name,
    usize source_first,
    usize source_count
) {
    usize record = modules.length;
    write_record_field(module_data, record, 0, name.start);
    write_record_field(module_data, record, 1, name.length);
    write_record_field(module_data, record, 2, source_first);
    write_record_field(module_data, record, 3, source_count);
    write_record_field(module_data, record, 4, 0);
    modules.length = modules.length + 1;
}

unsafe void project_parse_modules(
    text source,
    ref JsonState state,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ref PackedBuffer sources
) {
    modules.length = 0;
    sources.length = 0;
    if !project_json_take(source, state, 123) { return; }
    project_json_skip_space(source, state);
    if byte_at_or_zero(source, state.cursor) == 125 {
        state.cursor = state.cursor + 1;
        return;
    }
    while !state.failed {
        TextSpan name = project_json_string(source, state);
        if !project_json_take(source, state, 58) { return; }
        usize source_first = sources.length;
        project_parse_source_array(source, state, source_data, sources);
        if state.failed { return; }
        project_record_module(
            module_data, modules, name,
            source_first, sources.length - source_first
        );
        project_json_skip_space(source, state);
        u8 next = byte_at_or_zero(source, state.cursor);
        if next == 125 {
            state.cursor = state.cursor + 1;
            return;
        }
        if next != 44 {
            state.failed = true;
            return;
        }
        state.cursor = state.cursor + 1;
    }
}
