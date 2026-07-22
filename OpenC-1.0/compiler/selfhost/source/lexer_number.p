import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

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

