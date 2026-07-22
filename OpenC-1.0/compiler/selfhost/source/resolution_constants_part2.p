import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize resolution_constant_root(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize declaration,
    usize after
) {
    usize declaration_end = read_record_field(syntax_data, declaration, 1) +
        read_record_field(syntax_data, declaration, 2);
    usize selected = syntax.length;
    usize selected_length = 0;
    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        usize start = read_record_field(syntax_data, record, 1);
        usize end = start + read_record_field(syntax_data, record, 2);
        if resolution_expression_kind(kind) && start >= after &&
            end < declaration_end &&
            semantic_node_contains(syntax_data, declaration, record) &&
            read_record_field(syntax_data, record, 2) >= selected_length {
            selected = record;
            selected_length = read_record_field(syntax_data, record, 2);
        }
        record = record + 1;
    }
    return selected;
}

unsafe void resolution_emit_constant(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte type_data,
    usize ordinal,
    usize module_index,
    usize source_index,
    text owner_kind,
    text source,
    usize owner_start,
    usize owner_length,
    usize name_start,
    usize name_length,
    usize type_id,
    ResolutionConstant value
) {
    io.print("CONST ");
    io.print(ordinal);
    io.print(" ");
    io.print(module_index);
    io.print(" ");
    io.print(source_index);
    io.print(" ");
    io.print(owner_kind);
    io.print(" ");
    io.print(owner_start);
    io.print(" ");
    io.print(owner_length);
    io.print(" ");
    project_emit_hex(project_slice(source, name_start, name_length));
    io.print(" ");
    semantic_emit_type_display(
        project_source, project_root,
        module_data, modules, source_data,
        type_data, type_id
    );
    if value.kind == 1 {
        io.print(" integer ");
        io.println(value.signed_value);
    } else if value.kind == 2 {
        io.print(" bool ");
        if value.bool_value { io.println("1"); }
        else { io.println("0"); }
    } else if value.kind == 3 {
        io.print(" text ");
        project_emit_hex(project_slice(
            source, value.value_start, value.value_length
        ));
        io.println("");
    } else {
        io.print(" float_source ");
        project_emit_hex(project_slice(
            source, value.value_start, value.value_length
        ));
        io.println("");
    }
}
