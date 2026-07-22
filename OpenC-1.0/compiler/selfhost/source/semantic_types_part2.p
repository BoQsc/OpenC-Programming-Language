import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe void semantic_record_error(
    ptr byte error_data,
    ref PackedBuffer errors,
    usize source_record,
    usize start,
    usize length,
    usize rule
) {
    usize record = errors.length;
    write_record_field(error_data, record, 0, source_record);
    write_record_field(error_data, record, 1, start);
    write_record_field(error_data, record, 2, length);
    write_record_field(error_data, record, 3, rule);
    write_record_field(error_data, record, 4, 0);
    errors.length = errors.length + 1;
}

unsafe bool semantic_type_resource(ptr byte type_data, usize type_id) {
    return (read_record_field(type_data, type_id, 4) / 2) % 2 == 1;
}

unsafe void semantic_emit_named_type(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte type_data,
    usize type_id
) {
    usize source_record = read_record_field(type_data, type_id, 1);
    text source;
    status source_status = project_read_source_record(
        project_source, project_root, source_data, source_record,
        out source
    );
    if !source_status.ok { return; }
    usize flags = read_record_field(type_data, type_id, 4);
    if (flags / 4) % 2 == 1 {
        usize module_index = semantic_source_module(
            module_data, modules, source_record
        );
        project_emit_hex(project_slice(
            project_source,
            read_record_field(module_data, module_index, 0),
            read_record_field(module_data, module_index, 1)
        ));
        io.print("2e");
    }
    project_emit_hex(project_slice(
        source,
        read_record_field(type_data, type_id, 2),
        read_record_field(type_data, type_id, 3)
    ));
}

void semantic_emit_decimal_hex(usize value) {
    if value >= 10 { semantic_emit_decimal_hex(value / 10); }
    usize octet = 48 + value % 10;
    io.print(project_hex_digit(octet / 16));
    io.print(project_hex_digit(octet % 16));
}

unsafe void semantic_emit_type_display(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte type_data,
    usize type_id
) {
    if type_id < 18 {
        project_emit_hex(semantic_builtin_name(type_id));
        return;
    }
    usize kind = read_record_field(type_data, type_id, 0);
    usize flags = read_record_field(type_data, type_id, 4);
    if (flags / 8) % 2 == 1 {
        project_emit_hex("const ");
        semantic_emit_type_display(
            project_source, project_root,
            module_data, modules, source_data,
            type_data, read_record_field(type_data, type_id, 1)
        );
        return;
    }
    if kind == 9 {
        semantic_emit_named_type(
            project_source, project_root,
            module_data, modules, source_data,
            type_data, type_id
        );
        return;
    }
    if kind == 12 { project_emit_hex("ref "); }
    if kind == 13 { project_emit_hex("ptr "); }
    if kind == 14 { project_emit_hex("optional "); }
    if kind == 15 { project_emit_hex("storage "); }
    if (kind == 12 || kind == 13 || kind == 14) && flags % 2 == 1 {
        project_emit_hex("const ");
    }
    semantic_emit_type_display(
        project_source, project_root,
        module_data, modules, source_data,
        type_data, read_record_field(type_data, type_id, 1)
    );
    if kind == 10 {
        io.print("5b");
        semantic_emit_decimal_hex(read_record_field(type_data, type_id, 2));
        io.print("5d");
    }
    if kind == 11 { io.print("5b5d"); }
}
