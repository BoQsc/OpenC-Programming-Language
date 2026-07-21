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

usize record_stride() {
    return size_of(usize) * cast(usize, 5);
}

unsafe void write_usize(ptr byte data, usize offset, usize value) {
    usize index = 0;
    while index < size_of(usize) {
        *(data + offset + index) = cast(byte, value % 256);
        value = value / 256;
        index = index + 1;
    }
}

unsafe usize read_usize(ptr byte data, usize offset) {
    usize result = 0;
    usize multiplier = 1;
    usize index = 0;
    while index < size_of(usize) {
        result = result + cast(usize, *(data + offset + index)) * multiplier;
        index = index + 1;
        if index < size_of(usize) {
            multiplier = multiplier * 256;
        }
    }
    return result;
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
    u8 value;
    status found = text.byte_at(source, index, out value);
    if !found.ok {
        return 0;
    }
    return value;
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

text diagnostic_rule(usize code) {
    if code == 1 { return "OPENC-LEX-COMMENT-001"; }
    if code == 2 { return "OPENC-LEX-NUMBER-SEPARATOR-001"; }
    if code == 3 { return "OPENC-LEX-NUMBER-001"; }
    if code == 4 { return "OPENC-LEX-NUMBER-SUFFIX-001"; }
    if code == 5 { return "OPENC-LEX-TEXT-LINE-001"; }
    if code == 6 { return "OPENC-LEX-TEXT-ESCAPE-001"; }
    if code == 7 { return "OPENC-LEX-TEXT-UNICODE-001"; }
    if code == 8 { return "OPENC-LITERAL-UNICODE-001"; }
    if code == 9 { return "OPENC-LEX-TEXT-001"; }
    if code == 10 { return "OPENC-SYNTAX-OPTIONAL-001"; }
    if code == 11 { return "OPENC-LEX-TOKEN-001"; }
    if code == 12 { return "OPENC-LOOP-CONTEXT-001"; }
    if code == 13 { return "OPENC-RETURN-CONTEXT-001"; }
    if code == 14 { return "OPENC-STATUS-FIELD-001"; }
    if code == 15 { return "OPENC-SYNTAX-BRACES-001"; }
    if code == 16 { return "OPENC-SYNTAX-BRACKET-001"; }
    if code == 17 { return "OPENC-SYNTAX-COMMA-001"; }
    if code == 18 { return "OPENC-SYNTAX-CONST-001"; }
    if code == 19 { return "OPENC-SYNTAX-EXPR-001"; }
    if code == 20 { return "OPENC-SYNTAX-FUNCTION-001"; }
    if code == 21 { return "OPENC-SYNTAX-IDENTIFIER-001"; }
    if code == 22 { return "OPENC-SYNTAX-INITIALIZER-001"; }
    if code == 23 { return "OPENC-SYNTAX-PAREN-001"; }
    if code == 24 { return "OPENC-SYNTAX-PROGRESS-001"; }
    if code == 25 { return "OPENC-SYNTAX-SEMICOLON-001"; }
    if code == 26 { return "OPENC-SYNTAX-SWITCH-001"; }
    if code == 27 { return "OPENC-SYNTAX-TOP-DECL-001"; }
    if code == 28 { return "OPENC-TYPE-CONSTRUCTOR-ORDER-001"; }
    return "OPENC-TYPE-SUFFIX-001";
}

SourcePosition position_at(text source, usize target) {
    usize source_length = text.byte_length(source);
    usize cursor = 0;
    usize line = 1;
    usize line_start = 0;
    while cursor < target {
        u8 current = byte_at_or_zero(source, cursor);
        if current == 10 {
            line = line + 1;
            line_start = cursor + 1;
        } else if current == 13 &&
            (cursor + 1 >= source_length ||
             byte_at_or_zero(source, cursor + 1) != 10) {
            line = line + 1;
            line_start = cursor + 1;
        }
        cursor = cursor + 1;
    }
    return SourcePosition{
        line = line,
        column = target - line_start + 1
    };
}

unsafe void assign_token_positions(
    text source,
    ptr byte data,
    ref PackedBuffer tokens
) {
    usize source_length = text.byte_length(source);
    usize cursor = 0;
    usize line = 1;
    usize line_start = 0;
    usize record = 0;
    while record < tokens.length {
        usize target = read_record_field(data, record, 1);
        while cursor < target {
            u8 current = byte_at_or_zero(source, cursor);
            if current == 10 {
                line = line + 1;
                line_start = cursor + 1;
            } else if current == 13 &&
                (cursor + 1 >= source_length ||
                 byte_at_or_zero(source, cursor + 1) != 10) {
                line = line + 1;
                line_start = cursor + 1;
            }
            cursor = cursor + 1;
        }
        write_record_field(data, record, 3, line);
        write_record_field(data, record, 4, target - line_start + 1);
        record = record + 1;
    }
}

unsafe void assign_diagnostic_positions(
    text source,
    ptr byte data,
    ref PackedBuffer diagnostics
) {
    usize record = 0;
    while record < diagnostics.length {
        SourcePosition position = position_at(
            source,
            read_record_field(data, record, 1)
        );
        write_record_field(data, record, 3, position.line);
        write_record_field(data, record, 4, position.column);
        record = record + 1;
    }
}

unsafe void emit_observation_records(
    ptr byte data,
    ref PackedBuffer records,
    bool diagnostics
) {
    usize record = 0;
    while record < records.length {
        if diagnostics {
            io.print("ERROR ");
            io.print(diagnostic_rule(read_record_field(data, record, 0)));
        } else {
            io.print("TOKEN ");
            io.print(cast(i32, read_record_field(data, record, 0)));
        }
        io.print(" ");
        io.print(read_record_field(data, record, 1));
        io.print(" ");
        io.print(read_record_field(data, record, 2));
        io.print(" ");
        io.print(read_record_field(data, record, 3));
        io.print(" ");
        io.println(read_record_field(data, record, 4));
        record = record + 1;
    }
}

unsafe void skip_ignored(
    text source,
    usize source_length,
    ptr byte diagnostic_data,
    ref PackedBuffer diagnostics,
    ref LexerState state
) {
    while state.cursor < source_length {
        u8 current = byte_at_or_zero(source, state.cursor);
        if is_space(current) {
            state.cursor = state.cursor + 1;
            continue;
        }
        if current == 47 && peek_byte(source, state.cursor, 1) == 47 {
            state.cursor = state.cursor + 2;
            while state.cursor < source_length &&
                byte_at_or_zero(source, state.cursor) != 10 &&
                byte_at_or_zero(source, state.cursor) != 13 {
                state.cursor = state.cursor + 1;
            }
            continue;
        }
        if current == 47 && peek_byte(source, state.cursor, 1) == 42 {
            usize start = state.cursor;
            state.cursor = state.cursor + 2;
            bool closed = false;
            while state.cursor < source_length {
                if byte_at_or_zero(source, state.cursor) == 42 &&
                    peek_byte(source, state.cursor, 1) == 47 {
                    state.cursor = state.cursor + 2;
                    closed = true;
                    break;
                }
                state.cursor = state.cursor + 1;
            }
            if !closed {
                report_error(
                    diagnostic_data,
                    diagnostics,
                    1,
                    start,
                    state.cursor - start
                );
            }
            continue;
        }
        break;
    }
}

unsafe void lex_digits(
    text source,
    usize source_length,
    usize literal_start,
    bool hexadecimal,
    bool binary,
    ptr byte diagnostic_data,
    ref PackedBuffer diagnostics,
    ref LexerState state
) {
    bool saw_digit = false;
    bool last_separator = false;
    while state.cursor < source_length {
        u8 current = byte_at_or_zero(source, state.cursor);
        bool valid = false;
        if hexadecimal {
            valid = is_hex_digit(current);
        } else if binary {
            valid = current == 48 || current == 49;
        } else {
            valid = is_digit(current);
        }
        if valid {
            saw_digit = true;
            last_separator = false;
            state.cursor = state.cursor + 1;
        } else if current == 95 {
            if !saw_digit || last_separator {
                report_error(
                    diagnostic_data,
                    diagnostics,
                    2,
                    state.cursor,
                    1
                );
            }
            last_separator = true;
            state.cursor = state.cursor + 1;
        } else {
            break;
        }
    }
    if !saw_digit || last_separator {
        report_error(
            diagnostic_data,
            diagnostics,
            3,
            literal_start,
            state.cursor - literal_start
        );
    }
}

unsafe void lex_number(
    text source,
    usize source_length,
    usize start,
    ptr byte token_data,
    ref PackedBuffer tokens,
    ptr byte diagnostic_data,
    ref PackedBuffer diagnostics,
    ref LexerState state
) {
    bool floating = false;
    if byte_at_or_zero(source, state.cursor) == 48 &&
        (peek_byte(source, state.cursor, 1) == 120 ||
         peek_byte(source, state.cursor, 1) == 88) {
        state.cursor = state.cursor + 2;
        lex_digits(
            source, source_length, start, true, false,
            diagnostic_data, diagnostics, state
        );
    } else if byte_at_or_zero(source, state.cursor) == 48 &&
        (peek_byte(source, state.cursor, 1) == 98 ||
         peek_byte(source, state.cursor, 1) == 66) {
        state.cursor = state.cursor + 2;
        lex_digits(
            source, source_length, start, false, true,
            diagnostic_data, diagnostics, state
        );
    } else {
        lex_digits(
            source, source_length, start, false, false,
            diagnostic_data, diagnostics, state
        );
        if state.cursor < source_length &&
            byte_at_or_zero(source, state.cursor) == 46 &&
            peek_byte(source, state.cursor, 1) != 46 {
            floating = true;
            state.cursor = state.cursor + 1;
            lex_digits(
                source, source_length, start, false, false,
                diagnostic_data, diagnostics, state
            );
        }
        if state.cursor < source_length &&
            (byte_at_or_zero(source, state.cursor) == 101 ||
             byte_at_or_zero(source, state.cursor) == 69) {
            floating = true;
            state.cursor = state.cursor + 1;
            if state.cursor < source_length &&
                (byte_at_or_zero(source, state.cursor) == 43 ||
                 byte_at_or_zero(source, state.cursor) == 45) {
                state.cursor = state.cursor + 1;
            }
            lex_digits(
                source, source_length, start, false, false,
                diagnostic_data, diagnostics, state
            );
        }
    }

    if state.cursor < source_length &&
        is_identifier_start(byte_at_or_zero(source, state.cursor)) {
        usize suffix_start = state.cursor;
        while state.cursor < source_length &&
            is_identifier_continue(byte_at_or_zero(source, state.cursor)) {
            state.cursor = state.cursor + 1;
        }
        report_error(
            diagnostic_data,
            diagnostics,
            4,
            suffix_start,
            state.cursor - suffix_start
        );
    }

    if floating {
        record_token(token_data, tokens, 3, start, state.cursor - start);
    } else {
        record_token(token_data, tokens, 2, start, state.cursor - start);
    }
}

bool is_standard_escape(u8 value) {
    return value == 92 || value == 34 || value == 110 ||
        value == 114 || value == 116 || value == 48;
}

unsafe void lex_text(
    text source,
    usize source_length,
    usize start,
    ptr byte token_data,
    ref PackedBuffer tokens,
    ptr byte diagnostic_data,
    ref PackedBuffer diagnostics,
    ref LexerState state
) {
    state.cursor = state.cursor + 1;
    bool closed = false;
    while state.cursor < source_length {
        u8 current = byte_at_or_zero(source, state.cursor);
        if current == 34 {
            state.cursor = state.cursor + 1;
            closed = true;
            break;
        }
        if current == 10 || current == 13 {
            report_error(
                diagnostic_data,
                diagnostics,
                5,
                start,
                state.cursor - start
            );
            break;
        }
        if current == 92 {
            usize escape_start = state.cursor;
            state.cursor = state.cursor + 1;
            if state.cursor >= source_length {
                break;
            }
            u8 escape = byte_at_or_zero(source, state.cursor);
            if escape == 117 {
                state.cursor = state.cursor + 1;
                if state.cursor >= source_length ||
                    byte_at_or_zero(source, state.cursor) != 123 {
                    report_error(
                        diagnostic_data,
                        diagnostics,
                        6,
                        escape_start,
                        state.cursor - escape_start
                    );
                } else {
                    state.cursor = state.cursor + 1;
                    usize digits = 0;
                    u32 scalar = 0;
                    while state.cursor < source_length &&
                        is_hex_digit(byte_at_or_zero(source, state.cursor)) &&
                        digits < 6 {
                        scalar = scalar * 16 +
                            hex_value(byte_at_or_zero(source, state.cursor));
                        digits = digits + 1;
                        state.cursor = state.cursor + 1;
                    }
                    if digits == 0 ||
                        state.cursor >= source_length ||
                        byte_at_or_zero(source, state.cursor) != 125 {
                        report_error(
                            diagnostic_data,
                            diagnostics,
                            7,
                            escape_start,
                            state.cursor - escape_start
                        );
                    } else {
                        if (scalar >= 55296 && scalar <= 57343) ||
                            scalar > 1114111 {
                            report_error(
                                diagnostic_data,
                                diagnostics,
                                8,
                                escape_start,
                                state.cursor - escape_start + 1
                            );
                        }
                        state.cursor = state.cursor + 1;
                    }
                }
            } else {
                if !is_standard_escape(escape) {
                    report_error(
                        diagnostic_data,
                        diagnostics,
                        6,
                        escape_start,
                        2
                    );
                }
                state.cursor = state.cursor + 1;
            }
            continue;
        }
        state.cursor = state.cursor + 1;
    }
    if !closed {
        report_error(
            diagnostic_data,
            diagnostics,
            9,
            start,
            state.cursor - start
        );
    }
    record_token(token_data, tokens, 4, start, state.cursor - start);
}

bool is_single_symbol(u8 value) {
    return value == 59 || value == 44 || value == 46 ||
        value == 40 || value == 41 || value == 123 ||
        value == 125 || value == 91 || value == 93 ||
        value == 58 || value == 43 || value == 45 ||
        value == 42 || value == 47 || value == 37 ||
        value == 38 || value == 124 || value == 94 ||
        value == 33 || value == 126 || value == 61 ||
        value == 60 || value == 62;
}

usize symbol_length(text source, usize start) {
    if starts_with_ascii(source, start, "<<=") { return 3; }
    if starts_with_ascii(source, start, ">>=") { return 3; }
    if starts_with_ascii(source, start, "==") { return 2; }
    if starts_with_ascii(source, start, "!=") { return 2; }
    if starts_with_ascii(source, start, "<=") { return 2; }
    if starts_with_ascii(source, start, ">=") { return 2; }
    if starts_with_ascii(source, start, "<<") { return 2; }
    if starts_with_ascii(source, start, ">>") { return 2; }
    if starts_with_ascii(source, start, "&&") { return 2; }
    if starts_with_ascii(source, start, "||") { return 2; }
    if starts_with_ascii(source, start, "+=") { return 2; }
    if starts_with_ascii(source, start, "-=") { return 2; }
    if starts_with_ascii(source, start, "*=") { return 2; }
    if starts_with_ascii(source, start, "/=") { return 2; }
    if starts_with_ascii(source, start, "%=") { return 2; }
    if starts_with_ascii(source, start, "&=") { return 2; }
    if starts_with_ascii(source, start, "|=") { return 2; }
    if starts_with_ascii(source, start, "^=") { return 2; }
    if starts_with_ascii(source, start, "..") { return 2; }
    return 0;
}

unsafe void lex_symbol(
    text source,
    usize start,
    ptr byte token_data,
    ref PackedBuffer tokens,
    ptr byte diagnostic_data,
    ref PackedBuffer diagnostics,
    ref LexerState state
) {
    usize length = symbol_length(source, start);
    if length != 0 {
        state.cursor = state.cursor + length;
        record_token(token_data, tokens, 6, start, length);
        return;
    }
    u8 current = byte_at_or_zero(source, state.cursor);
    state.cursor = state.cursor + 1;
    if !is_single_symbol(current) {
        if current == 63 {
            report_error(
                diagnostic_data,
                diagnostics,
                10,
                start,
                1
            );
        } else {
            report_error(
                diagnostic_data,
                diagnostics,
                11,
                start,
                1
            );
        }
    }
    record_token(token_data, tokens, 6, start, 1);
}

unsafe void lex_source(
    text source,
    ptr byte token_data,
    ref PackedBuffer tokens,
    ptr byte diagnostic_data,
    ref PackedBuffer diagnostics
) {
    LexerState state = LexerState{
        cursor = 0
    };
    usize source_length = text.byte_length(source);

    while state.cursor < source_length {
        skip_ignored(
            source, source_length,
            diagnostic_data, diagnostics, state
        );
        if state.cursor >= source_length {
            break;
        }

        usize start = state.cursor;
        u8 current = byte_at_or_zero(source, state.cursor);
        if is_identifier_start(current) {
            state.cursor = state.cursor + 1;
            while state.cursor < source_length &&
                is_identifier_continue(byte_at_or_zero(source, state.cursor)) {
                state.cursor = state.cursor + 1;
            }
            i32 kind = 1;
            if is_keyword(source, start, state.cursor - start) {
                kind = 5;
            }
            record_token(
                token_data, tokens, kind, start, state.cursor - start
            );
        } else if is_digit(current) {
            lex_number(
                source, source_length, start,
                token_data, tokens,
                diagnostic_data, diagnostics, state
            );
        } else if current == 34 {
            lex_text(
                source, source_length, start,
                token_data, tokens,
                diagnostic_data, diagnostics, state
            );
        } else {
            lex_symbol(
                source, start,
                token_data, tokens,
                diagnostic_data, diagnostics, state
            );
        }
    }

    record_token(token_data, tokens, 0, state.cursor, 0);
}

unsafe i32 main() {
    usize arguments = process.argument_count();
    if arguments != 1 && arguments != 2 {
        io.error("usage: openc-selfhost-lexer [--parse] SOURCE.p\n");
        return 64;
    }

    bool parse_mode = false;
    text path = process.argument(0);
    if arguments == 2 {
        if process.argument(0) != "--parse" {
            io.error("usage: openc-selfhost-lexer [--parse] SOURCE.p\n");
            return 64;
        }
        parse_mode = true;
        path = process.argument(1);
    }
    text source;
    status loaded = file.read_text(path, out source);
    if !loaded.ok {
        if parse_mode {
            io.println("OPENC-PARSE-OBSERVATION 1");
        } else {
            io.println("OPENC-LEX-OBSERVATION 2");
        }
        io.println("SOURCE_ERROR OPENC-SOURCE-INVALID-001 0 0 1 1");
        io.println("SUMMARY 0 1");
        return 1;
    }

    usize source_length = text.byte_length(source);
    PackedBuffer tokens = PackedBuffer{
        length = 0,
        capacity = source_length + 1
    };
    PackedBuffer diagnostics = PackedBuffer{
        length = 0,
        capacity = source_length * 4 + 8
    };
    ptr byte token_data = memory.alloc(tokens.capacity * record_stride());
    scope memory.free(token_data);
    ptr byte diagnostic_data = memory.alloc(
        diagnostics.capacity * record_stride()
    );
    scope memory.free(diagnostic_data);

    lex_source(
        source,
        token_data, tokens,
        diagnostic_data, diagnostics
    );
    assign_token_positions(source, token_data, tokens);

    if parse_mode {
        PackedBuffer syntax = PackedBuffer{
            length = 0,
            capacity = tokens.length * 6 + 8
        };
        ptr byte syntax_data = memory.alloc(
            syntax.capacity * record_stride()
        );
        scope memory.free(syntax_data);
        parse_source_syntax(
            source,
            token_data, tokens,
            syntax_data, syntax,
            diagnostic_data, diagnostics
        );
        assign_diagnostic_positions(source, diagnostic_data, diagnostics);
        io.println("OPENC-PARSE-OBSERVATION 1");
        emit_syntax_records(syntax_data, syntax);
        emit_observation_records(diagnostic_data, diagnostics, true);
        io.print("SUMMARY ");
        io.print(syntax.length);
        io.print(" ");
        io.println(diagnostics.length);
        if diagnostics.length != 0 { return 1; }
        return 0;
    }

    assign_diagnostic_positions(source, diagnostic_data, diagnostics);
    io.println("OPENC-LEX-OBSERVATION 2");
    emit_observation_records(token_data, tokens, false);
    emit_observation_records(diagnostic_data, diagnostics, true);
    io.print("SUMMARY ");
    io.print(tokens.length);
    io.print(" ");
    io.println(diagnostics.length);

    if diagnostics.length != 0 {
        return 1;
    }
    return 0;
}
