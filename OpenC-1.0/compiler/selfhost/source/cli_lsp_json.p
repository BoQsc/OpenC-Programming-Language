import system.file;
import system.io;
import system.memory;
import system.text;

bool lsp_json_space(u8 value) {
    return value == 32 || value == 9 || value == 10 || value == 13;
}

usize lsp_skip_json_space(text source, usize cursor) {
    usize length = text.byte_length(source);
    while cursor < length && lsp_json_space(
        byte_at_or_zero(source, cursor)
    ) {
        cursor = cursor + 1;
    }
    return cursor;
}

usize lsp_json_span(usize start, usize length) {
    return ((start + 1) << 32) |
        (length & cast(usize, 4294967295));
}

usize lsp_json_span_start(usize span) {
    return (span >> 32) - 1;
}

usize lsp_json_span_length(usize span) {
    return span & cast(usize, 4294967295);
}

unsafe usize lsp_json_field_value(
    text source,
    text field
) {
    DBuffer needle = d_buffer_create(text.byte_length(field) + 3);
    d_put(needle, "\"");
    d_put(needle, field);
    d_put(needle, "\"");
    if !needle.ok {
        d_buffer_destroy(needle);
        return 0;
    }
    usize found = native_find(source, d_buffer_text(needle));
    usize needle_length = text.byte_length(d_buffer_text(needle));
    d_buffer_destroy(needle);
    usize source_length = text.byte_length(source);
    if found > source_length {
        return 0;
    }
    usize cursor = lsp_skip_json_space(
        source, found + needle_length
    );
    if cursor >= source_length ||
        byte_at_or_zero(source, cursor) != 58 {
        return 0;
    }
    cursor = lsp_skip_json_space(source, cursor + 1);
    if cursor >= source_length {
        return 0;
    }
    usize start = cursor;
    u8 first = byte_at_or_zero(source, cursor);
    if first == 34 {
        cursor = cursor + 1;
        bool escaped = false;
        while cursor < source_length {
            u8 current = byte_at_or_zero(source, cursor);
            if escaped {
                escaped = false;
            } else if current == 92 {
                escaped = true;
            } else if current == 34 {
                cursor = cursor + 1;
                return lsp_json_span(start, cursor - start);
            }
            cursor = cursor + 1;
        }
        return 0;
    }
    while cursor < source_length {
        u8 current = byte_at_or_zero(source, cursor);
        if current == 44 || current == 125 ||
            current == 93 || lsp_json_space(current) {
            usize delimited_length = cursor - start;
            if delimited_length != 0 {
                return lsp_json_span(start, delimited_length);
            }
            return 0;
        }
        cursor = cursor + 1;
    }
    usize terminal_length = cursor - start;
    if terminal_length != 0 {
        return lsp_json_span(start, terminal_length);
    }
    return 0;
}

usize lsp_hex_value(u8 value) {
    if value >= 48 && value <= 57 {
        return cast(usize, value - 48);
    }
    if value >= 65 && value <= 70 {
        return cast(usize, value - 65 + 10);
    }
    if value >= 97 && value <= 102 {
        return cast(usize, value - 97 + 10);
    }
    return 16;
}

unsafe bool lsp_put_utf8(ref DBuffer output, usize scalar) {
    if scalar <= 127 {
        d_put_byte(output, cast(u8, scalar));
    } else if scalar <= 2047 {
        d_put_byte(output, cast(u8, 192 + scalar / 64));
        d_put_byte(output, cast(u8, 128 + scalar % 64));
    } else if scalar <= 65535 {
        d_put_byte(output, cast(u8, 224 + scalar / 4096));
        d_put_byte(output, cast(u8, 128 + (scalar / 64) % 64));
        d_put_byte(output, cast(u8, 128 + scalar % 64));
    } else if scalar <= 1114111 {
        d_put_byte(output, cast(u8, 240 + scalar / 262144));
        d_put_byte(output, cast(u8, 128 + (scalar / 4096) % 64));
        d_put_byte(output, cast(u8, 128 + (scalar / 64) % 64));
        d_put_byte(output, cast(u8, 128 + scalar % 64));
    } else {
        return false;
    }
    return output.ok;
}

unsafe bool lsp_decode_json_string(
    text source,
    TextSpan raw,
    ref DBuffer output
) {
    output.length = 0;
    output.ok = true;
    if raw.length < 2 ||
        byte_at_or_zero(source, raw.start) != 34 ||
        byte_at_or_zero(source, raw.start + raw.length - 1) != 34 {
        return false;
    }
    usize cursor = raw.start + 1;
    usize end = raw.start + raw.length - 1;
    while cursor < end {
        u8 value = byte_at_or_zero(source, cursor);
        if value != 92 {
            d_put_byte(output, value);
            cursor = cursor + 1;
        } else {
            cursor = cursor + 1;
            if cursor >= end { return false; }
            u8 escaped = byte_at_or_zero(source, cursor);
            if escaped == 34 || escaped == 92 || escaped == 47 {
                d_put_byte(output, escaped);
            } else if escaped == 98 {
                d_put_byte(output, 8);
            } else if escaped == 102 {
                d_put_byte(output, 12);
            } else if escaped == 110 {
                d_put_byte(output, 10);
            } else if escaped == 114 {
                d_put_byte(output, 13);
            } else if escaped == 116 {
                d_put_byte(output, 9);
            } else if escaped == 117 {
                if cursor + 4 >= end { return false; }
                usize one = lsp_hex_value(
                    byte_at_or_zero(source, cursor + 1)
                );
                usize two = lsp_hex_value(
                    byte_at_or_zero(source, cursor + 2)
                );
                usize three = lsp_hex_value(
                    byte_at_or_zero(source, cursor + 3)
                );
                usize four = lsp_hex_value(
                    byte_at_or_zero(source, cursor + 4)
                );
                if one > 15 || two > 15 || three > 15 || four > 15 {
                    return false;
                }
                usize scalar = one * 4096 + two * 256 +
                    three * 16 + four;
                if scalar >= 55296 && scalar <= 57343 {
                    return false;
                }
                if !lsp_put_utf8(output, scalar) { return false; }
                cursor = cursor + 4;
            } else {
                return false;
            }
            cursor = cursor + 1;
        }
    }
    return output.ok;
}

unsafe bool lsp_json_string(
    text source,
    text field,
    ref DBuffer output
) {
    usize found = lsp_json_field_value(source, field);
    if found == 0 { return false; }
    return lsp_decode_json_string(source, TextSpan{
        start = lsp_json_span_start(found),
        length = lsp_json_span_length(found)
    }, output);
}

unsafe usize lsp_json_usize(
    text source,
    text field,
    usize fallback
) {
    usize found = lsp_json_field_value(source, field);
    if found == 0 { return fallback; }
    usize found_start = lsp_json_span_start(found);
    usize found_length = lsp_json_span_length(found);
    usize value = 0;
    usize cursor = 0;
    if found_length == 0 { return fallback; }
    while cursor < found_length {
        u8 digit = byte_at_or_zero(
            source, found_start + cursor
        );
        if digit < 48 || digit > 57 { return fallback; }
        value = value * 10 + cast(usize, digit - 48);
        cursor = cursor + 1;
    }
    return value;
}
