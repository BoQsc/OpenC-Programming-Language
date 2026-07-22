import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

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

