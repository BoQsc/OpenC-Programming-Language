import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

struct JsonState {
    usize cursor;
    bool failed;
}

struct TextSpan {
    usize start;
    usize length;
}

text project_hex_digit(usize value) {
    if value == 0 { return "0"; }
    if value == 1 { return "1"; }
    if value == 2 { return "2"; }
    if value == 3 { return "3"; }
    if value == 4 { return "4"; }
    if value == 5 { return "5"; }
    if value == 6 { return "6"; }
    if value == 7 { return "7"; }
    if value == 8 { return "8"; }
    if value == 9 { return "9"; }
    if value == 10 { return "a"; }
    if value == 11 { return "b"; }
    if value == 12 { return "c"; }
    if value == 13 { return "d"; }
    if value == 14 { return "e"; }
    return "f";
}

void project_emit_hex(text value) {
    usize index = 0;
    usize length = text.byte_length(value);
    while index < length {
        usize octet = cast(usize, byte_at_or_zero(value, index));
        io.print(project_hex_digit(octet / 16));
        io.print(project_hex_digit(octet % 16));
        index = index + 1;
    }
}

bool project_json_space(u8 value) {
    return value == 32 || value == 9 || value == 10 || value == 13;
}

void project_json_skip_space(text source, ref JsonState state) {
    usize length = text.byte_length(source);
    while state.cursor < length && project_json_space(byte_at_or_zero(source, state.cursor)) {
        state.cursor = state.cursor + 1;
    }
}

bool project_json_take(text source, ref JsonState state, u8 expected) {
    project_json_skip_space(source, state);
    if byte_at_or_zero(source, state.cursor) != expected {
        state.failed = true;
        return false;
    }
    state.cursor = state.cursor + 1;
    return true;
}

bool project_json_escape(u8 value) {
    return value == 34 || value == 47 || value == 92 || value == 98 ||
        value == 102 || value == 110 || value == 114 || value == 116;
}

TextSpan project_json_string(text source, ref JsonState state) {
    TextSpan result = TextSpan{ start = state.cursor, length = 0 };
    if !project_json_take(source, state, 34) { return result; }
    usize length = text.byte_length(source);
    result.start = state.cursor;
    while state.cursor < length {
        u8 value = byte_at_or_zero(source, state.cursor);
        if value == 34 {
            result.length = state.cursor - result.start;
            state.cursor = state.cursor + 1;
            return result;
        }
        if value < 32 {
            state.failed = true;
            return result;
        }
        if value == 92 {
            state.cursor = state.cursor + 1;
            u8 escaped = byte_at_or_zero(source, state.cursor);
            if escaped == 117 {
                usize digit = 0;
                while digit < 4 {
                    state.cursor = state.cursor + 1;
                    if !is_hex_digit(byte_at_or_zero(source, state.cursor)) {
                        state.failed = true;
                        return result;
                    }
                    digit = digit + 1;
                }
            } else if !project_json_escape(escaped) {
                state.failed = true;
                return result;
            }
        }
        state.cursor = state.cursor + 1;
    }
    state.failed = true;
    return result;
}

void project_json_skip_value(text source, ref JsonState state) {
    project_json_skip_space(source, state);
    usize length = text.byte_length(source);
    if state.cursor >= length {
        state.failed = true;
        return;
    }
    if byte_at_or_zero(source, state.cursor) == 34 {
        project_json_string(source, state);
        return;
    }
    u8 first = byte_at_or_zero(source, state.cursor);
    if first == 123 || first == 91 {
        usize depth = 0;
        while state.cursor < length {
            u8 value = byte_at_or_zero(source, state.cursor);
            if value == 34 {
                project_json_string(source, state);
                if state.failed { return; }
                continue;
            }
            if value == 123 || value == 91 { depth = depth + 1; }
            if value == 125 || value == 93 {
                if depth == 0 {
                    state.failed = true;
                    return;
                }
                depth = depth - 1;
                state.cursor = state.cursor + 1;
                if depth == 0 { return; }
                continue;
            }
            state.cursor = state.cursor + 1;
        }
        state.failed = true;
        return;
    }
    usize start = state.cursor;
    while state.cursor < length {
        u8 value = byte_at_or_zero(source, state.cursor);
        if project_json_space(value) || value == 44 || value == 125 || value == 93 {
            break;
        }
        state.cursor = state.cursor + 1;
    }
    if state.cursor == start { state.failed = true; }
}

unsafe void project_record_source(
    ptr byte source_data,
    ref PackedBuffer sources,
    TextSpan source_path
) {
    usize record = sources.length;
    write_record_field(source_data, record, 0, source_path.start);
    write_record_field(source_data, record, 1, source_path.length);
    write_record_field(source_data, record, 2, 0);
    write_record_field(source_data, record, 3, 0);
    write_record_field(source_data, record, 4, 0);
    sources.length = sources.length + 1;
}

unsafe void project_parse_source_array(
    text source,
    ref JsonState state,
    ptr byte source_data,
    ref PackedBuffer sources
) {
    if !project_json_take(source, state, 91) { return; }
    project_json_skip_space(source, state);
    if byte_at_or_zero(source, state.cursor) == 93 {
        state.cursor = state.cursor + 1;
        return;
    }
    while !state.failed {
        TextSpan source_path = project_json_string(source, state);
        if state.failed { return; }
        project_record_source(source_data, sources, source_path);
        project_json_skip_space(source, state);
        u8 next = byte_at_or_zero(source, state.cursor);
        if next == 93 {
            state.cursor = state.cursor + 1;
            return;
        }
        if next != 44 {
            state.failed = true;
            return;
        }
        state.cursor = state.cursor + 1;
    }
}

unsafe void project_record_module(
    ptr byte module_data,
    ref PackedBuffer modules,
    TextSpan name,
    usize source_first,
    usize source_count
) {
    usize record = modules.length;
    write_record_field(module_data, record, 0, name.start);
    write_record_field(module_data, record, 1, name.length);
    write_record_field(module_data, record, 2, source_first);
    write_record_field(module_data, record, 3, source_count);
    write_record_field(module_data, record, 4, 0);
    modules.length = modules.length + 1;
}

unsafe void project_parse_modules(
    text source,
    ref JsonState state,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ref PackedBuffer sources
) {
    modules.length = 0;
    sources.length = 0;
    if !project_json_take(source, state, 123) { return; }
    project_json_skip_space(source, state);
    if byte_at_or_zero(source, state.cursor) == 125 {
        state.cursor = state.cursor + 1;
        return;
    }
    while !state.failed {
        TextSpan name = project_json_string(source, state);
        if !project_json_take(source, state, 58) { return; }
        usize source_first = sources.length;
        project_parse_source_array(source, state, source_data, sources);
        if state.failed { return; }
        project_record_module(
            module_data, modules, name,
            source_first, sources.length - source_first
        );
        project_json_skip_space(source, state);
        u8 next = byte_at_or_zero(source, state.cursor);
        if next == 125 {
            state.cursor = state.cursor + 1;
            return;
        }
        if next != 44 {
            state.failed = true;
            return;
        }
        state.cursor = state.cursor + 1;
    }
}

unsafe bool project_parse_json(
    text source,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ref PackedBuffer sources
) {
    JsonState state = JsonState{ cursor = 0, failed = false };
    if !project_json_take(source, state, 123) { return false; }
    project_json_skip_space(source, state);
    if byte_at_or_zero(source, state.cursor) == 125 {
        state.cursor = state.cursor + 1;
    } else {
        while !state.failed {
            TextSpan key = project_json_string(source, state);
            if !project_json_take(source, state, 58) { return false; }
            if span_equals_ascii(source, key.start, key.length, "modules") {
                project_parse_modules(
                    source, state,
                    module_data, modules,
                    source_data, sources
                );
            } else {
                project_json_skip_value(source, state);
            }
            if state.failed { return false; }
            project_json_skip_space(source, state);
            u8 next = byte_at_or_zero(source, state.cursor);
            if next == 125 {
                state.cursor = state.cursor + 1;
                break;
            }
            if next != 44 { return false; }
            state.cursor = state.cursor + 1;
        }
    }
    project_json_skip_space(source, state);
    return !state.failed && state.cursor == text.byte_length(source);
}

unsafe i32 project_compare_spans(
    text source,
    usize left_start,
    usize left_length,
    usize right_start,
    usize right_length
) {
    usize common = left_length;
    if right_length < common { common = right_length; }
    usize index = 0;
    while index < common {
        u8 left = byte_at_or_zero(source, left_start + index);
        u8 right = byte_at_or_zero(source, right_start + index);
        if left < right { return -1; }
        if left > right { return 1; }
        index = index + 1;
    }
    if left_length < right_length { return -1; }
    if left_length > right_length { return 1; }
    return 0;
}

unsafe void project_swap_records(ptr byte data, usize left, usize right) {
    usize field = 0;
    while field < 5 {
        usize value = read_record_field(data, left, field);
        write_record_field(data, left, field, read_record_field(data, right, field));
        write_record_field(data, right, field, value);
        field = field + 1;
    }
}

unsafe void project_sort_modules(
    text project_source,
    ptr byte module_data,
    ref PackedBuffer modules
) {
    usize index = 1;
    while index < modules.length {
        usize current = index;
        while current > 0 && project_compare_spans(
            project_source,
            read_record_field(module_data, current - 1, 0),
            read_record_field(module_data, current - 1, 1),
            read_record_field(module_data, current, 0),
            read_record_field(module_data, current, 1)
        ) > 0 {
            project_swap_records(module_data, current - 1, current);
            current = current - 1;
        }
        index = index + 1;
    }
}

text project_slice(text source, usize start, usize length) {
    text value;
    status sliced = text.slice(source, start, start + length, out value);
    if !sliced.ok { return ""; }
    return value;
}

unsafe bool project_module_is(
    text project_source,
    ptr byte module_data,
    usize module_record,
    text expected
) {
    return span_equals_ascii(
        project_source,
        read_record_field(module_data, module_record, 0),
        read_record_field(module_data, module_record, 1),
        expected
    );
}

unsafe bool project_has_module(
    text project_source,
    ptr byte module_data,
    ref PackedBuffer modules,
    text name
) {
    usize module_record = 0;
    while module_record < modules.length {
        if project_module_is(project_source, module_data, module_record, name) {
            return true;
        }
        module_record = module_record + 1;
    }
    return false;
}

bool project_builtin_module(text name) {
    if name == "system.io" { return true; }
    if name == "system.memory" { return true; }
    if name == "system.text" { return true; }
    if name == "system.process" { return true; }
    if name == "system.path" { return true; }
    return name == "system.file";
}

unsafe usize project_emit_modules(
    text project_source,
    ptr byte module_data,
    ref PackedBuffer modules
) {
    usize module_record = 0;
    while module_record < modules.length {
        text name = project_slice(
            project_source,
            read_record_field(module_data, module_record, 0),
            read_record_field(module_data, module_record, 1)
        );
        io.print("MODULE ");
        io.print(module_record);
        io.print(" ");
        project_emit_hex(name);
        io.print(" ");
        io.println(read_record_field(module_data, module_record, 3));
        module_record = module_record + 1;
    }
    text builtin0 = "system.io";
    text builtin1 = "system.memory";
    text builtin2 = "system.text";
    text builtin3 = "system.process";
    text builtin4 = "system.path";
    text builtin5 = "system.file";
    usize builtin = 0;
    while builtin < 6 {
        text name = builtin5;
        if builtin == 0 { name = builtin0; }
        if builtin == 1 { name = builtin1; }
        if builtin == 2 { name = builtin2; }
        if builtin == 3 { name = builtin3; }
        if builtin == 4 { name = builtin4; }
        if !project_has_module(project_source, module_data, modules, name) {
            io.print("MODULE ");
            io.print(module_record);
            io.print(" ");
            project_emit_hex(name);
            io.println(" 0");
            module_record = module_record + 1;
        }
        builtin = builtin + 1;
    }
    return module_record;
}

unsafe void project_record_imports(
    text source,
    ptr byte token_data,
    ref PackedBuffer tokens,
    usize module_index,
    usize source_index,
    usize source_record,
    ptr byte import_data,
    ref PackedBuffer imports
) {
    usize depth = 0;
    usize token = 0;
    while token < tokens.length {
        if span_equals_ascii(
            source,
            read_record_field(token_data, token, 1),
            read_record_field(token_data, token, 2),
            "{"
        ) {
            depth = depth + 1;
        } else if span_equals_ascii(
            source,
            read_record_field(token_data, token, 1),
            read_record_field(token_data, token, 2),
            "}"
        ) {
            if depth > 0 { depth = depth - 1; }
        } else if depth == 0 && span_equals_ascii(
            source,
            read_record_field(token_data, token, 1),
            read_record_field(token_data, token, 2),
            "import"
        ) {
            usize first = token + 1;
            usize last = first;
            usize cursor = first;
            while cursor < tokens.length && !span_equals_ascii(
                source,
                read_record_field(token_data, cursor, 1),
                read_record_field(token_data, cursor, 2),
                ";"
            ) {
                if read_record_field(token_data, cursor, 0) == 1 ||
                    read_record_field(token_data, cursor, 0) == 5 {
                    last = cursor;
                }
                cursor = cursor + 1;
            }
            usize start = read_record_field(token_data, first, 1);
            usize finish = read_record_field(token_data, last, 1) +
                read_record_field(token_data, last, 2);
            usize record = imports.length;
            write_record_field(import_data, record, 0, module_index);
            write_record_field(import_data, record, 1, source_index);
            write_record_field(import_data, record, 2, source_record);
            write_record_field(import_data, record, 3, start);
            write_record_field(import_data, record, 4, finish - start);
            imports.length = imports.length + 1;
            token = cursor;
        }
        token = token + 1;
    }
}

unsafe text project_source_record_path(
    text project_source,
    text project_root,
    ptr byte source_data,
    usize source_record
) {
    text relative = project_slice(
        project_source,
        read_record_field(source_data, source_record, 0),
        read_record_field(source_data, source_record, 1)
    );
    return path.join(project_root, relative);
}

unsafe status project_read_source_record(
    text project_source,
    text project_root,
    ptr byte source_data,
    usize source_record,
    out text source
) {
    text source_path = project_source_record_path(
        project_source, project_root, source_data, source_record
    );
    text loaded_source;
    status loaded = file.read_text(source_path, out loaded_source);
    if !loaded.ok { return loaded; }
    source = loaded_source;
    return loaded;
}

unsafe bool project_import_equals(
    text source,
    ptr byte import_data,
    usize import_record,
    text expected
) {
    return span_equals_ascii(
        source,
        read_record_field(import_data, import_record, 3),
        read_record_field(import_data, import_record, 4),
        expected
    );
}

unsafe text project_import_text(
    text source,
    ptr byte import_data,
    usize import_record
) {
    return project_slice(
        source,
        read_record_field(import_data, import_record, 3),
        read_record_field(import_data, import_record, 4)
    );
}

usize project_short_start(text value) {
    usize length = text.byte_length(value);
    usize index = length;
    while index > 0 {
        if byte_at_or_zero(value, index - 1) == 46 { return index; }
        index = index - 1;
    }
    return 0;
}

bool project_same_short(text left, text right) {
    usize left_start = project_short_start(left);
    usize right_start = project_short_start(right);
    usize left_length = text.byte_length(left) - left_start;
    usize right_length = text.byte_length(right) - right_start;
    if left_length != right_length { return false; }
    usize index = 0;
    while index < left_length {
        if byte_at_or_zero(left, left_start + index) !=
            byte_at_or_zero(right, right_start + index) {
            return false;
        }
        index = index + 1;
    }
    return true;
}

unsafe i32 project_find_module(
    text project_source,
    ptr byte module_data,
    ref PackedBuffer modules,
    text name
) {
    usize module_record = 0;
    while module_record < modules.length {
        text module_name = project_slice(
            project_source,
            read_record_field(module_data, module_record, 0),
            read_record_field(module_data, module_record, 1)
        );
        if module_name == name { return cast(i32, module_record); }
        module_record = module_record + 1;
    }
    return -1;
}

unsafe void project_graph_error(
    text rule,
    usize module_index,
    usize source_index,
    usize source_length
) {
    io.print("ERROR ");
    io.print(rule);
    io.print(" ");
    io.print(module_index);
    io.print(" ");
    io.print(source_index);
    io.print(" 0 ");
    io.print(source_length);
    io.println(" 1 1");
}

unsafe usize project_emit_graph_errors(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte import_data,
    ref PackedBuffer imports
) {
    usize errors = 0;
    usize import_record = 0;
    while import_record < imports.length {
        usize source_record = read_record_field(import_data, import_record, 2);
        text source;
        status source_status = project_read_source_record(
            project_source, project_root, source_data, source_record,
            out source
        );
        if !source_status.ok {
            import_record = import_record + 1;
            continue;
        }
        text import_name = project_import_text(source, import_data, import_record);
        if project_find_module(
            project_source, module_data, modules, import_name
        ) < 0 && !project_builtin_module(import_name) {
            project_graph_error(
                "OPENC-MODULE-IMPORT-MISSING-001",
                read_record_field(import_data, import_record, 0),
                read_record_field(import_data, import_record, 1),
                read_record_field(source_data, source_record, 2)
            );
            errors = errors + 1;
        }
        usize previous = 0;
        while previous < import_record {
            if read_record_field(import_data, previous, 0) ==
                read_record_field(import_data, import_record, 0) {
                usize previous_source_record = read_record_field(import_data, previous, 2);
                text previous_source;
                status previous_status = project_read_source_record(
                    project_source, project_root, source_data, previous_source_record,
                    out previous_source
                );
                if previous_status.ok {
                    text previous_name = project_import_text(
                        previous_source, import_data, previous
                    );
                    if project_same_short(previous_name, import_name) &&
                        previous_name != import_name {
                        project_graph_error(
                            "OPENC-MODULE-QUALIFIER-AMBIGUOUS-001",
                            read_record_field(import_data, import_record, 0),
                            read_record_field(import_data, import_record, 1),
                            read_record_field(source_data, source_record, 2)
                        );
                        errors = errors + 1;
                        break;
                    }
                }
            }
            previous = previous + 1;
        }
        import_record = import_record + 1;
    }

    import_record = 0;
    while import_record < imports.length {
        usize source_record = read_record_field(import_data, import_record, 2);
        text source;
        status source_status = project_read_source_record(
            project_source, project_root, source_data, source_record,
            out source
        );
        if !source_status.ok {
            import_record = import_record + 1;
            continue;
        }
        text import_name = project_import_text(source, import_data, import_record);
        i32 imported_module = project_find_module(
            project_source, module_data, modules, import_name
        );
        if imported_module >= 0 {
            text current_module = project_slice(
                project_source,
                read_record_field(
                    module_data,
                    read_record_field(import_data, import_record, 0),
                    0
                ),
                read_record_field(
                    module_data,
                    read_record_field(import_data, import_record, 0),
                    1
                )
            );
            usize reverse = 0;
            usize last_source = 0;
            bool has_last_source = false;
            while reverse < imports.length {
                if read_record_field(import_data, reverse, 0) ==
                    cast(usize, imported_module) {
                    usize reverse_source_record = read_record_field(import_data, reverse, 2);
                    if !has_last_source || reverse_source_record != last_source {
                        text reverse_source;
                        status reverse_status = project_read_source_record(
                            project_source, project_root, source_data, reverse_source_record,
                            out reverse_source
                        );
                        if reverse_status.ok {
                            if project_import_equals(
                                reverse_source, import_data, reverse, current_module
                            ) {
                                project_graph_error(
                                    "OPENC-MODULE-CYCLE-001",
                                    read_record_field(import_data, import_record, 0),
                                    read_record_field(import_data, import_record, 1),
                                    read_record_field(source_data, source_record, 2)
                                );
                                errors = errors + 1;
                                last_source = reverse_source_record;
                                has_last_source = true;
                            }
                        }
                    }
                }
                reverse = reverse + 1;
            }
        }
        import_record = import_record + 1;
    }
    return errors;
}

unsafe void project_emit_source_diagnostics(
    text source,
    usize module_index,
    usize source_index
) {
    usize source_length = text.byte_length(source);
    PackedBuffer tokens = PackedBuffer{
        length = 0,
        capacity = source_length + 2
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
    PackedBuffer syntax = PackedBuffer{
        length = 0,
        capacity = tokens.length * 6 + 8
    };
    ptr byte syntax_data = memory.alloc(syntax.capacity * record_stride());
    scope memory.free(syntax_data);
    parse_source_syntax(
        source,
        token_data, tokens,
        syntax_data, syntax,
        diagnostic_data, diagnostics
    );
    assign_diagnostic_positions(source, diagnostic_data, diagnostics);
    usize diagnostic = 0;
    while diagnostic < diagnostics.length {
        io.print("ERROR ");
        io.print(diagnostic_rule(read_record_field(diagnostic_data, diagnostic, 0)));
        io.print(" ");
        io.print(module_index);
        io.print(" ");
        io.print(source_index);
        io.print(" ");
        io.print(read_record_field(diagnostic_data, diagnostic, 1));
        io.print(" ");
        io.print(read_record_field(diagnostic_data, diagnostic, 2));
        io.print(" ");
        io.print(read_record_field(diagnostic_data, diagnostic, 3));
        io.print(" ");
        io.println(read_record_field(diagnostic_data, diagnostic, 4));
        diagnostic = diagnostic + 1;
    }
}

unsafe i32 observe_project(text project_path) {
    io.println("OPENC-PROJECT-OBSERVATION 1");
    text project_source;
    status loaded_project = file.read_text(project_path, out project_source);
    if !loaded_project.ok {
        io.println("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
        io.println("SUMMARY 0 0 0 0 0 1");
        return 1;
    }

    usize project_length = text.byte_length(project_source);
    PackedBuffer modules = PackedBuffer{ length = 0, capacity = project_length + 1 };
    PackedBuffer sources = PackedBuffer{ length = 0, capacity = project_length + 1 };
    PackedBuffer imports = PackedBuffer{ length = 0, capacity = project_length + 1 };
    ptr byte module_data = memory.alloc(modules.capacity * record_stride());
    scope memory.free(module_data);
    ptr byte source_data = memory.alloc(sources.capacity * record_stride());
    scope memory.free(source_data);
    ptr byte import_data = memory.alloc(imports.capacity * record_stride());
    scope memory.free(import_data);

    if !project_parse_json(
        project_source,
        module_data, modules,
        source_data, sources
    ) {
        io.println("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
        io.println("SUMMARY 0 0 0 0 0 1");
        return 1;
    }
    project_sort_modules(project_source, module_data, modules);
    usize graph_modules = project_emit_modules(project_source, module_data, modules);
    text project_root = path.directory(project_path);
    usize unit_count = 0;
    usize node_count = 0;
    usize error_count = 0;
    usize module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            usize source_record = source_first + source_index;
            text source_path = project_source_record_path(
                project_source, project_root, source_data, source_record
            );
            text source;
            status read_status = project_read_source_record(
                project_source, project_root, source_data, source_record,
                out source
            );
            io.print("UNIT ");
            io.print(module_index);
            io.print(" ");
            io.print(source_index);
            io.print(" ");
            project_emit_hex(source_path);
            io.println("");
            unit_count = unit_count + 1;
            if !read_status.ok {
                io.print("PROJECT_ERROR OPENC-PROJECT-SOURCE-READ-001 ");
                io.print(module_index);
                io.print(" ");
                io.println(source_index);
                error_count = error_count + 1;
                source_index = source_index + 1;
                continue;
            }

            usize source_length = text.byte_length(source);
            PackedBuffer tokens = PackedBuffer{
                length = 0,
                capacity = source_length + 2
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
            PackedBuffer syntax = PackedBuffer{
                length = 0,
                capacity = tokens.length * 6 + 8
            };
            ptr byte syntax_data = memory.alloc(syntax.capacity * record_stride());
            scope memory.free(syntax_data);
            parse_source_syntax(
                source,
                token_data, tokens,
                syntax_data, syntax,
                diagnostic_data, diagnostics
            );
            assign_diagnostic_positions(source, diagnostic_data, diagnostics);
            write_record_field(source_data, source_record, 2, source_length);
            write_record_field(source_data, source_record, 3, syntax.length);
            write_record_field(source_data, source_record, 4, 1);
            io.print("SOURCE ");
            io.print(module_index);
            io.print(" ");
            io.print(source_index);
            io.print(" ");
            io.print(source_length);
            io.print(" ");
            io.println(syntax.length);
            node_count = node_count + syntax.length;
            usize before_imports = imports.length;
            project_record_imports(
                source,
                token_data, tokens,
                module_index, source_index, source_record,
                import_data, imports
            );
            usize import_record = before_imports;
            while import_record < imports.length {
                io.print("IMPORT ");
                io.print(module_index);
                io.print(" ");
                io.print(source_index);
                io.print(" ");
                project_emit_hex(project_import_text(source, import_data, import_record));
                io.println("");
                import_record = import_record + 1;
            }
            error_count = error_count + diagnostics.length;
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            usize source_record = source_first + source_index;
            if read_record_field(source_data, source_record, 4) == 1 {
                text source;
                status source_status = project_read_source_record(
                    project_source, project_root, source_data, source_record,
                    out source
                );
                if source_status.ok {
                    project_emit_source_diagnostics(source, module_index, source_index);
                }
            }
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    if error_count == 0 {
        error_count = error_count + project_emit_graph_errors(
            project_source, project_root,
            module_data, modules,
            source_data,
            import_data, imports
        );
    }
    io.print("SUMMARY ");
    io.print(modules.length);
    io.print(" ");
    io.print(graph_modules);
    io.print(" ");
    io.print(unit_count);
    io.print(" ");
    io.print(imports.length);
    io.print(" ");
    io.print(node_count);
    io.print(" ");
    io.println(error_count);
    if error_count != 0 { return 1; }
    return 0;
}
