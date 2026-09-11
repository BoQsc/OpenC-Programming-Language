import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

struct CliFormatState {
    DBuffer output;
    usize indent;
    bool line_start;
    bool pending_space;
    bool in_text;
    bool in_line_comment;
    bool in_block_comment;
    bool escaped;
    u8 previous_significant;
}

unsafe bool cli_format_word(u8 value) {
    return is_identifier_continue(value);
}

unsafe bool cli_format_operator(u8 value) {
    return value == 43 || value == 45 || value == 42 ||
        value == 47 || value == 37 || value == 38 ||
        value == 124 || value == 94 || value == 33 ||
        value == 126 || value == 61 || value == 60 ||
        value == 62;
}

unsafe bool cli_format_needs_space(u8 left, u8 right) {
    if left == 0 { return false; }
    bool left_word = cli_format_word(left) || left == 34 ||
        left == 41 || left == 93;
    bool right_word = cli_format_word(right) || right == 34;
    return left_word && right_word;
}

unsafe void cli_format_indent(ref CliFormatState state) {
    if !state.line_start { return; }
    usize spaces = state.indent * 4;
    usize cursor = 0;
    while cursor < spaces {
        d_put_byte(state.output, 32);
        cursor = cursor + 1;
    }
    state.line_start = false;
}

unsafe void cli_format_trim(ref CliFormatState state) {
    while state.output.length != 0 && (
        cast(u8, *(state.output.data + state.output.length - 1)) == 32 ||
        cast(u8, *(state.output.data + state.output.length - 1)) == 9
    ) {
        state.output.length = state.output.length - 1;
    }
}

unsafe void cli_format_newline(ref CliFormatState state) {
    cli_format_trim(state);
    if state.output.length == 0 ||
        cast(u8, *(state.output.data + state.output.length - 1)) != 10 {
        d_put_byte(state.output, 10);
    }
    state.line_start = true;
    state.pending_space = false;
}

unsafe void cli_format_pending_space(
    ref CliFormatState state,
    u8 next
) {
    if state.pending_space &&
        cli_format_needs_space(state.previous_significant, next) &&
        !state.line_start {
        d_put_byte(state.output, 32);
    }
}

unsafe bool cli_format_pair_operator(u8 value, u8 next) {
    if value != 126 && next == 61 {
        return true;
    }
    return (value == 38 && next == 38) ||
        (value == 124 && next == 124) ||
        (value == 60 && next == 60) ||
        (value == 62 && next == 62);
}

unsafe bool cli_format_source_text(
    text source,
    ref DBuffer formatted
) {
    CliFormatState state = CliFormatState{
        output = d_buffer_create(
            text.byte_length(source) * 8 + 4096
        ),
        indent = 0,
        line_start = true,
        pending_space = false,
        in_text = false,
        in_line_comment = false,
        in_block_comment = false,
        escaped = false,
        previous_significant = 0
    };
    usize cursor = 0;
    usize length = text.byte_length(source);
    while cursor < length {
        u8 value = byte_at_or_zero(source, cursor);
        u8 next = byte_at_or_zero(source, cursor + 1);

        if state.in_line_comment {
            if value == 10 || value == 13 {
                state.in_line_comment = false;
                cli_format_newline(state);
                if value == 13 && next == 10 {
                    cursor = cursor + 1;
                }
            } else {
                cli_format_indent(state);
                d_put_byte(state.output, value);
            }
            cursor = cursor + 1;
            continue;
        }

        if state.in_block_comment {
            if value == 10 || value == 13 {
                cli_format_newline(state);
                if value == 13 && next == 10 {
                    cursor = cursor + 1;
                }
            } else {
                cli_format_indent(state);
                d_put_byte(state.output, value);
                if value == 42 && next == 47 {
                    d_put_byte(state.output, 47);
                    cursor = cursor + 1;
                    state.in_block_comment = false;
                    state.pending_space = true;
                }
            }
            cursor = cursor + 1;
            continue;
        }

        if state.in_text {
            cli_format_indent(state);
            d_put_byte(state.output, value);
            if state.escaped {
                state.escaped = false;
            } else if value == 92 {
                state.escaped = true;
            } else if value == 34 {
                state.in_text = false;
            }
            cursor = cursor + 1;
            continue;
        }

        if value == 47 && next == 47 {
            if state.pending_space && !state.line_start {
                d_put_byte(state.output, 32);
            }
            cli_format_indent(state);
            d_put(state.output, "//");
            cursor = cursor + 2;
            state.in_line_comment = true;
            continue;
        }
        if value == 47 && next == 42 {
            if state.pending_space && !state.line_start {
                d_put_byte(state.output, 32);
            }
            cli_format_indent(state);
            d_put(state.output, "/*");
            cursor = cursor + 2;
            state.in_block_comment = true;
            continue;
        }
        if value == 34 {
            cli_format_pending_space(state, value);
            cli_format_indent(state);
            d_put_byte(state.output, value);
            state.in_text = true;
            state.pending_space = false;
            state.previous_significant = value;
            cursor = cursor + 1;
            continue;
        }
        if value == 32 || value == 9 || value == 10 || value == 13 {
            state.pending_space = true;
            cursor = cursor + 1;
            continue;
        }
        if value == 123 {
            if state.pending_space && !state.line_start {
                d_put_byte(state.output, 32);
            }
            cli_format_indent(state);
            d_put_byte(state.output, value);
            state.indent = state.indent + 1;
            cli_format_newline(state);
            state.previous_significant = value;
            cursor = cursor + 1;
            continue;
        }
        if value == 125 {
            if !state.line_start { cli_format_newline(state); }
            if state.indent != 0 {
                state.indent = state.indent - 1;
            }
            cli_format_indent(state);
            d_put_byte(state.output, value);
            state.pending_space = false;
            state.previous_significant = value;
            if next != 59 && next != 44 &&
                next != 41 && next != 93 {
                cli_format_newline(state);
            }
            cursor = cursor + 1;
            continue;
        }
        if value == 59 {
            cli_format_indent(state);
            d_put_byte(state.output, value);
            cli_format_newline(state);
            state.previous_significant = value;
            cursor = cursor + 1;
            continue;
        }
        if value == 44 {
            cli_format_indent(state);
            d_put(state.output, ", ");
            state.pending_space = false;
            state.previous_significant = value;
            cursor = cursor + 1;
            continue;
        }
        if value == 40 || value == 91 || value == 46 {
            cli_format_indent(state);
            d_put_byte(state.output, value);
            state.pending_space = false;
            state.previous_significant = value;
            cursor = cursor + 1;
            continue;
        }
        if value == 41 || value == 93 {
            cli_format_trim(state);
            cli_format_indent(state);
            d_put_byte(state.output, value);
            state.pending_space = false;
            state.previous_significant = value;
            cursor = cursor + 1;
            continue;
        }
        if cli_format_operator(value) {
            if !state.line_start && state.output.length != 0 &&
                cast(u8, *(
                    state.output.data + state.output.length - 1
                )) != 32 {
                d_put_byte(state.output, 32);
            }
            cli_format_indent(state);
            d_put_byte(state.output, value);
            u8 after_next = byte_at_or_zero(source, cursor + 2);
            if (value == 60 || value == 62) &&
                next == value && after_next == 61 {
                d_put_byte(state.output, next);
                d_put_byte(state.output, after_next);
                cursor = cursor + 2;
            } else if cli_format_pair_operator(value, next) {
                d_put_byte(state.output, next);
                cursor = cursor + 1;
            }
            d_put_byte(state.output, 32);
            state.pending_space = false;
            state.previous_significant = value;
            cursor = cursor + 1;
            continue;
        }

        cli_format_pending_space(state, value);
        cli_format_indent(state);
        d_put_byte(state.output, value);
        state.pending_space = false;
        state.previous_significant = value;
        cursor = cursor + 1;
    }

    if !state.line_start { cli_format_newline(state); }
    if !state.output.ok {
        d_buffer_destroy(state.output);
        return false;
    }
    formatted = state.output;
    return true;
}

unsafe bool cli_format_validate(text source_path) {
    NativeRunResult parsed = native_run_mode(
        cli_self_executable(),
        "--parse",
        source_path
    );
    if !parsed.launched {
        io.error("error: native parser could not be launched\n");
        return false;
    }
    if parsed.exit_code != 0 {
        io.error("error: formatter rejected invalid OpenC source: ");
        io.error(source_path);
        io.error("\n");
        return false;
    }
    return true;
}

unsafe usize cli_format_one(
    text source_path,
    bool write
) {
    if !cli_format_validate(source_path) {
        return 2;
    }
    text source;
    status loaded = file.read_text(source_path, out source);
    if !loaded.ok {
        io.error("error: formatter could not read source: ");
        io.error(source_path);
        io.error("\n");
        return 2;
    }
    source = source_without_initial_bom(source);
    DBuffer formatted = d_buffer_create(1);
    if !cli_format_source_text(source, formatted) {
        d_buffer_destroy(formatted);
        io.error("error: formatter output capacity exceeded\n");
        return 2;
    }
    bool formatted_changed = text.byte_length(source) != formatted.length;
    usize compare_index = 0;
    while !formatted_changed && compare_index < formatted.length {
        if byte_at_or_zero(source, compare_index) !=
            cast(u8, *(formatted.data + compare_index)) {
            formatted_changed = true;
        }
        compare_index = compare_index + 1;
    }
    if write && formatted_changed {
        status written = file.write_text(
            source_path, d_buffer_text(formatted)
        );
        if !written.ok {
            d_buffer_destroy(formatted);
            io.error("error: formatter could not write source: ");
            io.error(source_path);
            io.error("\n");
            return 2;
        }
    }
    d_buffer_destroy(formatted);
    if formatted_changed { return 1; }
    return 0;
}
