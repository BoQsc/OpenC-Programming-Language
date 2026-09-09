import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

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
    // Source records own one stable view for the lifetime of a project build.
    // Keeping the view beside the manifest span prevents semantic lookup from
    // repeatedly joining the same path and rereading the same file when a
    // bounded runtime hash cache experiences collisions.
    usize cached_data = read_record_field(source_data, source_record, 3);
    if cached_data != 0 {
        text cached_source = "";
        ptr byte cached_representation = reinterpret(ptr byte, &cached_source);
        write_usize(cached_representation, 0, cached_data);
        write_usize(
            cached_representation, size_of(usize),
            read_record_field(source_data, source_record, 4)
        );
        source = cached_source;
        return status{ code = 0 };
    }
    text source_path = project_source_record_path(
        project_source, project_root, source_data, source_record
    );
    text loaded_source;
    status loaded = file.read_text_cached(source_path, out loaded_source);
    if !loaded.ok { return loaded; }
    source = source_without_initial_bom(loaded_source);
    ptr byte source_representation = reinterpret(ptr byte, &source);
    write_record_field(
        source_data, source_record, 3,
        read_usize(source_representation, 0)
    );
    write_record_field(
        source_data, source_record, 4,
        read_usize(source_representation, size_of(usize))
    );
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
