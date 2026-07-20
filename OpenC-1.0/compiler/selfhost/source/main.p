import system.file;
import system.io;
import system.process;
import system.text;

struct ScanResult {
    bool valid;
    usize tokens;
    usize lines;
    i32 error_code;
}

bool is_space(u32 scalar) {
    return scalar == 9 || scalar == 10 || scalar == 13 || scalar == 32;
}

bool is_digit(u32 scalar) {
    return scalar >= 48 && scalar <= 57;
}

bool is_identifier_start(u32 scalar) {
    return scalar == 95 ||
        (scalar >= 65 && scalar <= 90) ||
        (scalar >= 97 && scalar <= 122) ||
        scalar >= 128;
}

bool is_identifier_continue(u32 scalar) {
    return is_identifier_start(scalar) || is_digit(scalar);
}

ScanResult scan_source(text source) {
    ScanResult result = ScanResult{
        valid = true,
        tokens = 0,
        lines = 1,
        error_code = 0
    };

    usize length = text.length(source);
    usize index = 0;
    i32 brace_depth = 0;
    i32 parenthesis_depth = 0;
    i32 bracket_depth = 0;
    i32 state = 0;
    bool escaped = false;

    while index < length {
        u32 scalar;
        status current = text.scalar_at(source, index, out scalar);
        if !current.ok {
            result.valid = false;
            result.error_code = 10;
            return result;
        }

        u32 next_scalar;
        bool has_next;
        if index + 1 < length {
            status next = text.scalar_at(source, index + 1, out next_scalar);
            if !next.ok {
                result.valid = false;
                result.error_code = 11;
                return result;
            }
            has_next = true;
        } else {
            next_scalar = 0;
            has_next = false;
        }

        if state == 1 {
            if scalar == 10 {
                result.valid = false;
                result.error_code = 20;
                return result;
            }
            if escaped {
                escaped = false;
            } else if scalar == 92 {
                escaped = true;
            } else if scalar == 34 {
                state = 0;
            }
            index = index + 1;
            continue;
        }

        if state == 2 {
            if scalar == 10 {
                result.lines = result.lines + 1;
                state = 0;
            }
            index = index + 1;
            continue;
        }

        if state == 3 {
            if scalar == 10 {
                result.lines = result.lines + 1;
            }
            if scalar == 42 && has_next && next_scalar == 47 {
                state = 0;
                index = index + 2;
            } else {
                index = index + 1;
            }
            continue;
        }

        if scalar == 47 && has_next && next_scalar == 47 {
            state = 2;
            index = index + 2;
            continue;
        }
        if scalar == 47 && has_next && next_scalar == 42 {
            state = 3;
            index = index + 2;
            continue;
        }
        if scalar == 34 {
            state = 1;
            escaped = false;
            result.tokens = result.tokens + 1;
            index = index + 1;
            continue;
        }
        if is_space(scalar) {
            if scalar == 10 {
                result.lines = result.lines + 1;
            }
            index = index + 1;
            continue;
        }

        if is_identifier_start(scalar) {
            result.tokens = result.tokens + 1;
            index = index + 1;
            while index < length {
                u32 part;
                status part_status = text.scalar_at(source, index, out part);
                if !part_status.ok {
                    result.valid = false;
                    result.error_code = 12;
                    return result;
                }
                if !is_identifier_continue(part) {
                    break;
                }
                index = index + 1;
            }
            continue;
        }

        if is_digit(scalar) {
            result.tokens = result.tokens + 1;
            index = index + 1;
            while index < length {
                u32 digit;
                status digit_status = text.scalar_at(source, index, out digit);
                if !digit_status.ok {
                    result.valid = false;
                    result.error_code = 13;
                    return result;
                }
                if !is_digit(digit) {
                    break;
                }
                index = index + 1;
            }
            continue;
        }

        if scalar == 123 {
            brace_depth = brace_depth + 1;
        } else if scalar == 125 {
            brace_depth = brace_depth - 1;
        } else if scalar == 40 {
            parenthesis_depth = parenthesis_depth + 1;
        } else if scalar == 41 {
            parenthesis_depth = parenthesis_depth - 1;
        } else if scalar == 91 {
            bracket_depth = bracket_depth + 1;
        } else if scalar == 93 {
            bracket_depth = bracket_depth - 1;
        }

        if brace_depth < 0 || parenthesis_depth < 0 || bracket_depth < 0 {
            result.valid = false;
            result.error_code = 30;
            return result;
        }

        result.tokens = result.tokens + 1;
        index = index + 1;
    }

    if state == 1 {
        result.valid = false;
        result.error_code = 21;
    } else if state == 3 {
        result.valid = false;
        result.error_code = 22;
    } else if brace_depth != 0 || parenthesis_depth != 0 || bracket_depth != 0 {
        result.valid = false;
        result.error_code = 31;
    }

    return result;
}

i32 main() {
    if process.argument_count() != 1 {
        io.error("usage: openc-selfhost-seed SOURCE.p\n");
        return 64;
    }

    text path = process.argument(0);
    text source;
    status loaded = file.read_text(path, out source);
    if !loaded.ok {
        io.error("openc-selfhost-seed: cannot read UTF-8 source\n");
        return loaded.code;
    }

    ScanResult result = scan_source(source);
    if !result.valid {
        io.error("openc-selfhost-seed: lexical structure rejected; code=");
        io.error("see exit status\n");
        return result.error_code;
    }

    io.println("OpenC self-host seed: source accepted");
    io.print("tokens: ");
    io.println(result.tokens);
    io.print("lines: ");
    io.println(result.lines);
    return 0;
}
