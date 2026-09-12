import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe void flow_move_owner(
    ptr byte state_data,
    usize symbol,
    usize source_record,
    usize site,
    ptr byte syntax_data,
    ptr byte error_data,
    ref PackedBuffer errors
) {
    usize state = flow_state_get(state_data, symbol);
    if state == 2 {
        flow_record_error(
            error_data, errors, source_record,
            read_record_field(syntax_data, site, 1),
            read_record_field(syntax_data, site, 2),
            flow_phase_ownership(), flow_rule_own_cleanup_reserved()
        );
    } else if state == 1 {
        flow_state_set(state_data, symbol, 3);
    } else if state == 4 {
        flow_record_error(
            error_data, errors, source_record,
            read_record_field(syntax_data, site, 1),
            read_record_field(syntax_data, site, 2),
            flow_phase_ownership(), flow_rule_own_use_destroy()
        );
    } else {
        flow_record_error(
            error_data, errors, source_record,
            read_record_field(syntax_data, site, 1),
            read_record_field(syntax_data, site, 2),
            flow_phase_ownership(), flow_rule_own_use_move()
        );
    }
}

unsafe void flow_move_initializer_owners(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize module_index,
    usize source_record,
    usize declaration,
    text source,
    ptr byte state_data,
    ptr byte error_data,
    ref PackedBuffer errors
) {
    usize initializer = flow_local_initializer_root(
        syntax_data, syntax, declaration
    );
    if initializer >= syntax.length || read_record_field(
        syntax_data, initializer, 0
    ) != 48 { return; }
    usize field = 0;
    while field < syntax.length {
        if read_record_field(syntax_data, field, 0) == 49 &&
            semantic_node_contains(syntax_data, initializer, field) &&
            resolution_smallest_parent(
                syntax_data, syntax, field, 48, 999, 998
            ) == initializer {
            usize start = read_record_field(syntax_data, field, 1);
            if start >= 4 && starts_with_ascii(source, start - 4, "own ") {
                usize name = flow_event_first_name(
                    syntax_data, syntax, field
                );
                if name < syntax.length {
                    usize owner = flow_name_symbol(
                        project_source, project_root,
                        module_data, modules, source_data,
                        symbol_data, detail_data, symbols,
                        syntax_data, syntax, module_index, source_record,
                        name, source
                    );
                    if owner < symbols.length &&
                        flow_state_get(state_data, owner) != 0 {
                        flow_move_owner(
                            state_data, owner, source_record, name,
                            syntax_data, error_data, errors
                        );
                    }
                }
            }
        }
        field = field + 1;
    }
}
