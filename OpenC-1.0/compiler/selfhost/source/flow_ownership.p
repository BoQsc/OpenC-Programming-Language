import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize flow_state_get(ptr byte state_data, usize symbol) {
    return read_usize(state_data, symbol * size_of(usize));
}

unsafe void flow_state_set(
    ptr byte state_data,
    usize symbol,
    usize state
) {
    write_usize(state_data, symbol * size_of(usize), state);
}

unsafe usize flow_event_next(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize function_node,
    usize after_end,
    usize after_record
) {
    usize selected = syntax.length;
    usize selected_end = cast(usize, 4294967295);
    usize selected_record = cast(usize, 4294967295);
    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        bool event = kind == 12 || kind == 23 || kind == 37 ||
            kind == 38 || kind == 45 || kind == 22;
        usize start = read_record_field(syntax_data, record, 1);
        usize end = start + read_record_field(syntax_data, record, 2);
        if event && semantic_node_contains(
            syntax_data, function_node, record
        ) && (end > after_end ||
            (end == after_end && record > after_record)) &&
            (selected == syntax.length || end < selected_end ||
             (end == selected_end && record < selected_record)) {
            selected = record;
            selected_end = end;
            selected_record = record;
        }
        record = record + 1;
    }
    return selected;
}

unsafe usize flow_collect_events(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize function_node,
    ptr byte event_data
) {
    usize count = 0;
    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        bool event = kind == 12 || kind == 23 || kind == 37 ||
            kind == 38 || kind == 45 || kind == 22;
        if event && semantic_node_contains(
            syntax_data, function_node, record
        ) {
            usize end = read_record_field(syntax_data, record, 1) +
                read_record_field(syntax_data, record, 2);
            usize insert = count;
            while insert > 0 {
                usize previous = read_usize(
                    event_data, (insert - 1) * size_of(usize)
                );
                usize previous_end = read_record_field(
                    syntax_data, previous, 1
                ) + read_record_field(syntax_data, previous, 2);
                if previous_end < end ||
                    (previous_end == end && previous < record) {
                    break;
                }
                write_usize(
                    event_data, insert * size_of(usize), previous
                );
                insert = insert - 1;
            }
            write_usize(event_data, insert * size_of(usize), record);
            count = count + 1;
        }
        record = record + 1;
    }
    return count;
}

unsafe usize flow_event_name_symbol(
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
    usize event,
    text source
) {
    usize selected_name = syntax.length;
    usize selected_start = cast(usize, 4294967295);
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == 27 &&
            semantic_node_contains(syntax_data, event, record) {
            usize start = read_record_field(syntax_data, record, 1);
            if start < selected_start {
                selected_name = record;
                selected_start = start;
            }
        }
        record = record + 1;
    }
    if selected_name >= syntax.length { return symbols.length; }
    return flow_name_symbol(
        project_source, project_root,
        module_data, modules, source_data,
        symbol_data, detail_data, symbols,
        syntax_data, syntax, module_index, source_record,
        selected_name, source
    );
}

unsafe usize flow_event_first_name(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize event
) {
    usize selected = syntax.length;
    usize selected_start = cast(usize, 4294967295);
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == 27 &&
            semantic_node_contains(syntax_data, event, record) {
            usize start = read_record_field(syntax_data, record, 1);
            if start < selected_start {
                selected = record;
                selected_start = start;
            }
        }
        record = record + 1;
    }
    return selected;
}
