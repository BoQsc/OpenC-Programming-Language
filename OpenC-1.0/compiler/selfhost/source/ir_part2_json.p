import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

void ir_json_hex4(usize value) {
    io.print(project_hex_digit((value / 4096) % 16));
    io.print(project_hex_digit((value / 256) % 16));
    io.print(project_hex_digit((value / 16) % 16));
    io.print(project_hex_digit(value % 16));
}

void ir_json_slice(text value, usize start, usize length) {
    // Emit Unicode escapes from byte spans. This keeps byte-addressed source
    // spans exact even when text.slice would interpret offsets as code points.
    io.print("\"");
    usize cursor = 0;
    while cursor < length {
        usize first = cast(usize, byte_at_or_zero(value, start + cursor));
        usize codepoint = first;
        usize consumed = 1;
        if first >= 194 && first <= 223 && cursor + 1 < length {
            usize second = cast(usize, byte_at_or_zero(
                value, start + cursor + 1
            ));
            codepoint = (first % 32) * 64 + second % 64;
            consumed = 2;
        } else if first >= 224 && first <= 239 && cursor + 2 < length {
            usize second = cast(usize, byte_at_or_zero(
                value, start + cursor + 1
            ));
            usize third = cast(usize, byte_at_or_zero(
                value, start + cursor + 2
            ));
            codepoint = (first % 16) * 4096 +
                (second % 64) * 64 + third % 64;
            consumed = 3;
        } else if first >= 240 && first <= 244 && cursor + 3 < length {
            usize second = cast(usize, byte_at_or_zero(
                value, start + cursor + 1
            ));
            usize third = cast(usize, byte_at_or_zero(
                value, start + cursor + 2
            ));
            usize fourth = cast(usize, byte_at_or_zero(
                value, start + cursor + 3
            ));
            codepoint = (first % 8) * 262144 +
                (second % 64) * 4096 +
                (third % 64) * 64 + fourth % 64;
            consumed = 4;
        }
        if codepoint <= 65535 {
            io.print("\\u");
            ir_json_hex4(codepoint);
        } else {
            usize scalar = codepoint - 65536;
            io.print("\\u");
            ir_json_hex4(55296 + scalar / 1024);
            io.print("\\u");
            ir_json_hex4(56320 + scalar % 1024);
        }
        cursor = cursor + consumed;
    }
    io.print("\"");
}

void ir_json_text(text value) {
    ir_json_slice(value, 0, text.byte_length(value));
}

unsafe void ir_emit_symbol_name(ref IrContext context, usize symbol) {
    usize kind = read_record_field(context.symbol_data, symbol, 0);
    if read_record_field(context.detail_data, symbol, 2) == 0 &&
        kind != resolution_symbol_field() &&
        kind != resolution_symbol_enum_item() {
        usize module_index = read_record_field(
            context.detail_data, symbol, 0
        );
        ir_json_slice(
            context.project_source,
            read_record_field(context.module_data, module_index, 0),
            read_record_field(context.module_data, module_index, 1)
        );
        // Symbol identities need one JSON string. The caller uses the
        // dedicated combined form below instead of this helper.
    }
}
