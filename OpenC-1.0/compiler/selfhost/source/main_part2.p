import system.file;
import system.io;
import system.memory;
import system.process;
import system.text;

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
