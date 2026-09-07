import system.file;
import system.io;
import system.memory;
import system.process;
import system.text;

struct LexerState {
    usize cursor;
}

struct PackedBuffer {
    usize length;
    usize capacity;
}

struct SourcePosition {
    usize line;
    usize column;
}

text source_without_initial_bom(text source) {
    text logical_source = source;
    if text.byte_length(source) >= 3 &&
        byte_at_or_zero(source, 0) == 239 &&
        byte_at_or_zero(source, 1) == 187 &&
        byte_at_or_zero(source, 2) == 191 {
        text sliced_source;
        status sliced = text.slice(
            source, 1, text.length(source), out sliced_source
        );
        if sliced.ok {
            logical_source = sliced_source;
        }
    }
    return logical_source;
}

usize record_stride() {
    return size_of(usize) * cast(usize, 5);
}

unsafe void write_usize(ptr byte data, usize offset, usize value) {
    memory.store_usize(data + offset, value);
}

unsafe usize read_usize(ptr byte data, usize offset) {
    return memory.load_usize(data + offset);
}

unsafe void write_record_field(
    ptr byte data,
    usize record,
    usize field,
    usize value
) {
    write_usize(
        data,
        record * record_stride() + field * size_of(usize),
        value
    );
}

unsafe usize read_record_field(
    ptr byte data,
    usize record,
    usize field
) {
    return read_usize(
        data,
        record * record_stride() + field * size_of(usize)
    );
}

u8 byte_at_or_zero(text source, usize index) {
    if index >= text.byte_length(source) {
        return 0;
    }
    return text.byte_at_unchecked(source, index);
}

u8 peek_byte(text source, usize cursor, usize distance) {
    usize index = cursor + distance;
    if index >= text.byte_length(source) {
        return 0;
    }
    return byte_at_or_zero(source, index);
}

bool is_space(u8 value) {
    return value == 32 || value == 9 || value == 10 || value == 13;
}

bool is_digit(u8 value) {
    return value >= 48 && value <= 57;
}

bool is_alpha(u8 value) {
    return (value >= 65 && value <= 90) ||
        (value >= 97 && value <= 122);
}

bool is_identifier_start(u8 value) {
    return is_alpha(value) || value == 95;
}

bool is_identifier_continue(u8 value) {
    return is_identifier_start(value) || is_digit(value);
}

bool is_hex_digit(u8 value) {
    return is_digit(value) ||
        (value >= 65 && value <= 70) ||
        (value >= 97 && value <= 102);
}

u32 hex_value(u8 value) {
    if value >= 48 && value <= 57 {
        return value - 48;
    }
    if value >= 97 && value <= 102 {
        return value - 97 + 10;
    }
    return value - 65 + 10;
}

bool starts_with_ascii(text source, usize start, text expected) {
    usize expected_length = text.byte_length(expected);
    usize source_length = text.byte_length(source);
    if start + expected_length > source_length {
        return false;
    }
    usize index = 0;
    while index < expected_length {
        if byte_at_or_zero(source, start + index) != byte_at_or_zero(expected, index) {
            return false;
        }
        index = index + 1;
    }
    return true;
}

bool span_equals_ascii(text source, usize start, usize length, text expected) {
    return length == text.byte_length(expected) &&
        starts_with_ascii(source, start, expected);
}

bool is_keyword(text source, usize start, usize length) {
    if span_equals_ascii(source, start, length, "import") { return true; }
    if span_equals_ascii(source, start, length, "external") { return true; }
    if span_equals_ascii(source, start, length, "export") { return true; }
    if span_equals_ascii(source, start, length, "const") { return true; }
    if span_equals_ascii(source, start, length, "struct") { return true; }
    if span_equals_ascii(source, start, length, "resource") { return true; }
    if span_equals_ascii(source, start, length, "enum") { return true; }
    if span_equals_ascii(source, start, length, "unsafe") { return true; }
    if span_equals_ascii(source, start, length, "void") { return true; }
    if span_equals_ascii(source, start, length, "own") { return true; }
    if span_equals_ascii(source, start, length, "out") { return true; }
    if span_equals_ascii(source, start, length, "when") { return true; }
    if span_equals_ascii(source, start, length, "ref") { return true; }
    if span_equals_ascii(source, start, length, "ptr") { return true; }
    if span_equals_ascii(source, start, length, "optional") { return true; }
    if span_equals_ascii(source, start, length, "storage") { return true; }
    if span_equals_ascii(source, start, length, "if") { return true; }
    if span_equals_ascii(source, start, length, "else") { return true; }
    if span_equals_ascii(source, start, length, "while") { return true; }
    if span_equals_ascii(source, start, length, "for") { return true; }
    if span_equals_ascii(source, start, length, "switch") { return true; }
    if span_equals_ascii(source, start, length, "case") { return true; }
    if span_equals_ascii(source, start, length, "default") { return true; }
    if span_equals_ascii(source, start, length, "break") { return true; }
    if span_equals_ascii(source, start, length, "continue") { return true; }
    if span_equals_ascii(source, start, length, "return") { return true; }
    if span_equals_ascii(source, start, length, "scope") { return true; }
    if span_equals_ascii(source, start, length, "cast") { return true; }
    if span_equals_ascii(source, start, length, "cast_unchecked") { return true; }
    if span_equals_ascii(source, start, length, "reinterpret") { return true; }
    if span_equals_ascii(source, start, length, "construct") { return true; }
    if span_equals_ascii(source, start, length, "destroy") { return true; }
    if span_equals_ascii(source, start, length, "size_of") { return true; }
    if span_equals_ascii(source, start, length, "align_of") { return true; }
    if span_equals_ascii(source, start, length, "true") { return true; }
    if span_equals_ascii(source, start, length, "false") { return true; }
    if span_equals_ascii(source, start, length, "null") { return true; }
    if span_equals_ascii(source, start, length, "none") { return true; }
    if span_equals_ascii(source, start, length, "i8") { return true; }
    if span_equals_ascii(source, start, length, "i16") { return true; }
    if span_equals_ascii(source, start, length, "i32") { return true; }
    if span_equals_ascii(source, start, length, "i64") { return true; }
    if span_equals_ascii(source, start, length, "u8") { return true; }
    if span_equals_ascii(source, start, length, "u16") { return true; }
    if span_equals_ascii(source, start, length, "u32") { return true; }
    if span_equals_ascii(source, start, length, "u64") { return true; }
    if span_equals_ascii(source, start, length, "isize") { return true; }
    if span_equals_ascii(source, start, length, "usize") { return true; }
    if span_equals_ascii(source, start, length, "bool") { return true; }
    if span_equals_ascii(source, start, length, "byte") { return true; }
    if span_equals_ascii(source, start, length, "f32") { return true; }
    if span_equals_ascii(source, start, length, "f64") { return true; }
    if span_equals_ascii(source, start, length, "text") { return true; }
    if span_equals_ascii(source, start, length, "status") { return true; }
    return false;
}

unsafe void record_token(
    ptr byte data,
    ref PackedBuffer tokens,
    i32 kind,
    usize start,
    usize length
) {
    usize record = tokens.length;
    write_record_field(data, record, 0, cast(usize, kind));
    write_record_field(data, record, 1, start);
    write_record_field(data, record, 2, length);
    write_record_field(data, record, 3, 0);
    write_record_field(data, record, 4, 0);
    tokens.length = tokens.length + 1;
}

unsafe void report_error(
    ptr byte data,
    ref PackedBuffer diagnostics,
    usize rule,
    usize start,
    usize length
) {
    usize record = diagnostics.length;
    write_record_field(data, record, 0, rule);
    write_record_field(data, record, 1, start);
    write_record_field(data, record, 2, length);
    write_record_field(data, record, 3, 0);
    write_record_field(data, record, 4, 0);
    diagnostics.length = diagnostics.length + 1;
}
