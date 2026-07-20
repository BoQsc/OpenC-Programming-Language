import system.file;
import system.io;
import system.process;
import system.text;

struct LexResult {
    usize tokens;
    usize errors;
}

struct LexerState {
    usize cursor;
    usize tokens;
    usize errors;
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

void emit_token(bool enabled, i32 kind, usize start, usize length) {
    if !enabled {
        return;
    }
    io.print("TOKEN ");
    io.print(kind);
    io.print(" ");
    io.print(start);
    io.print(" ");
    io.println(length);
}

void report_error(
    bool enabled,
    text rule,
    usize start,
    usize length,
    ref LexerState state
) {
    state.errors = state.errors + 1;
    if !enabled {
        return;
    }
    io.print("ERROR ");
    io.print(rule);
    io.print(" ");
    io.print(start);
    io.print(" ");
    io.println(length);
}

void skip_ignored(
    text source,
    usize source_length,
    bool emit_errors,
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
                    emit_errors,
                    "OPENC-LEX-COMMENT-001",
                    start,
                    state.cursor - start,
                    state
                );
            }
            continue;
        }
        break;
    }
}

void lex_digits(
    text source,
    usize source_length,
    usize literal_start,
    bool hexadecimal,
    bool binary,
    bool emit_errors,
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
                    emit_errors,
                    "OPENC-LEX-NUMBER-SEPARATOR-001",
                    state.cursor,
                    1,
                    state
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
            emit_errors,
            "OPENC-LEX-NUMBER-001",
            literal_start,
            state.cursor - literal_start,
            state
        );
    }
}

void lex_number(
    text source,
    usize source_length,
    usize start,
    bool emit_tokens,
    bool emit_errors,
    ref LexerState state
) {
    bool floating = false;
    if byte_at_or_zero(source, state.cursor) == 48 &&
        (peek_byte(source, state.cursor, 1) == 120 ||
         peek_byte(source, state.cursor, 1) == 88) {
        state.cursor = state.cursor + 2;
        lex_digits(
            source, source_length, start, true, false,
            emit_errors, state
        );
    } else if byte_at_or_zero(source, state.cursor) == 48 &&
        (peek_byte(source, state.cursor, 1) == 98 ||
         peek_byte(source, state.cursor, 1) == 66) {
        state.cursor = state.cursor + 2;
        lex_digits(
            source, source_length, start, false, true,
            emit_errors, state
        );
    } else {
        lex_digits(
            source, source_length, start, false, false,
            emit_errors, state
        );
        if state.cursor < source_length &&
            byte_at_or_zero(source, state.cursor) == 46 &&
            peek_byte(source, state.cursor, 1) != 46 {
            floating = true;
            state.cursor = state.cursor + 1;
            lex_digits(
                source, source_length, start, false, false,
                emit_errors, state
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
                emit_errors, state
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
            emit_errors,
            "OPENC-LEX-NUMBER-SUFFIX-001",
            suffix_start,
            state.cursor - suffix_start,
            state
        );
    }

    if floating {
        emit_token(emit_tokens, 3, start, state.cursor - start);
    } else {
        emit_token(emit_tokens, 2, start, state.cursor - start);
    }
}

bool is_standard_escape(u8 value) {
    return value == 92 || value == 34 || value == 110 ||
        value == 114 || value == 116 || value == 48;
}

void lex_text(
    text source,
    usize source_length,
    usize start,
    bool emit_tokens,
    bool emit_errors,
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
                emit_errors,
                "OPENC-LEX-TEXT-LINE-001",
                start,
                state.cursor - start,
                state
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
                        emit_errors,
                        "OPENC-LEX-TEXT-ESCAPE-001",
                        escape_start,
                        state.cursor - escape_start,
                        state
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
                            emit_errors,
                            "OPENC-LEX-TEXT-UNICODE-001",
                            escape_start,
                            state.cursor - escape_start,
                            state
                        );
                    } else {
                        if (scalar >= 55296 && scalar <= 57343) ||
                            scalar > 1114111 {
                            report_error(
                                emit_errors,
                                "OPENC-LITERAL-UNICODE-001",
                                escape_start,
                                state.cursor - escape_start + 1,
                                state
                            );
                        }
                        state.cursor = state.cursor + 1;
                    }
                }
            } else {
                if !is_standard_escape(escape) {
                    report_error(
                        emit_errors,
                        "OPENC-LEX-TEXT-ESCAPE-001",
                        escape_start,
                        2,
                        state
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
            emit_errors,
            "OPENC-LEX-TEXT-001",
            start,
            state.cursor - start,
            state
        );
    }
    emit_token(emit_tokens, 4, start, state.cursor - start);
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

void lex_symbol(
    text source,
    usize start,
    bool emit_tokens,
    bool emit_errors,
    ref LexerState state
) {
    usize length = symbol_length(source, start);
    if length != 0 {
        state.cursor = state.cursor + length;
        emit_token(emit_tokens, 6, start, length);
        return;
    }
    u8 current = byte_at_or_zero(source, state.cursor);
    state.cursor = state.cursor + 1;
    if !is_single_symbol(current) {
        if current == 63 {
            report_error(
                emit_errors,
                "OPENC-SYNTAX-OPTIONAL-001",
                start,
                1,
                state
            );
        } else {
            report_error(
                emit_errors,
                "OPENC-LEX-TOKEN-001",
                start,
                1,
                state
            );
        }
    }
    emit_token(emit_tokens, 6, start, 1);
}

LexResult lex_source(text source, bool emit_tokens, bool emit_errors) {
    LexerState state = LexerState{
        cursor = 0,
        tokens = 0,
        errors = 0
    };
    usize source_length = text.byte_length(source);

    while state.cursor < source_length {
        skip_ignored(
            source, source_length, emit_errors, state
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
            emit_token(emit_tokens, kind, start, state.cursor - start);
        } else if is_digit(current) {
            lex_number(
                source, source_length, start,
                emit_tokens, emit_errors, state
            );
        } else if current == 34 {
            lex_text(
                source, source_length, start,
                emit_tokens, emit_errors, state
            );
        } else {
            lex_symbol(
                source, start,
                emit_tokens, emit_errors, state
            );
        }
        state.tokens = state.tokens + 1;
    }

    emit_token(emit_tokens, 0, state.cursor, 0);
    state.tokens = state.tokens + 1;
    return LexResult{
        tokens = state.tokens,
        errors = state.errors
    };
}

i32 main() {
    if process.argument_count() != 1 {
        io.error("usage: openc-selfhost-lexer SOURCE.p\n");
        return 64;
    }

    text path = process.argument(0);
    text source;
    status loaded = file.read_text(path, out source);
    if !loaded.ok {
        io.println("OPENC-LEX-OBSERVATION 1");
        io.println("SOURCE_ERROR OPENC-SOURCE-INVALID-001 0 0");
        io.println("SUMMARY 0 1");
        return 1;
    }

    io.println("OPENC-LEX-OBSERVATION 1");
    LexResult tokens = lex_source(source, true, false);
    LexResult errors = lex_source(source, false, true);
    io.print("SUMMARY ");
    io.print(tokens.tokens);
    io.print(" ");
    io.println(errors.errors);

    if errors.errors != 0 {
        return 1;
    }
    return 0;
}
