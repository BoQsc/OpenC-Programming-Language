import system.io;
import system.memory;

unsafe i32 main() {
    PackedBuffer empty = PackedBuffer{ length = 0, capacity = 0 };
    PackedBuffer symbols = PackedBuffer{ length = 4, capacity = 4 };
    ptr byte symbol_data = memory.alloc(4 * record_stride());
    scope memory.free(symbol_data);
    ptr byte detail_data = memory.alloc(4 * record_stride());
    scope memory.free(detail_data);
    IrContext context = backend_base_context("", "", null, empty, null,
        null, empty, symbol_data, detail_data, symbols, 1);
    context.syntax = PackedBuffer{ length = 13, capacity = 14 };
    ptr byte syntax_data = memory.alloc(14 * record_stride());
    scope memory.free(syntax_data);
    context.syntax_data = syntax_data;
    ptr byte scratch = memory.alloc(cast(usize, 14) * 8 * size_of(usize));
    scope memory.free(scratch);
    context.block_parent_cache = scratch;
    context.control_parent_cache = scratch + 14 * size_of(usize);
    context.block_statement_first = scratch + 28 * size_of(usize);
    context.statement_next = scratch + 42 * size_of(usize);
    context.control_block_first = scratch + 56 * size_of(usize);
    context.block_next = scratch + 70 * size_of(usize);
    context.control_child_first = scratch + 84 * size_of(usize);
    context.control_child_next = scratch + 98 * size_of(usize);
    usize node = 0;
    while node < 14 {
        write_usize(context.block_parent_cache, node * size_of(usize), 13);
        write_usize(context.control_parent_cache, node * size_of(usize), 13);
        node = node + 1;
    }
    write_record_field(syntax_data, 0, 0, 11);
    write_record_field(syntax_data, 0, 1, 0);
    write_record_field(syntax_data, 0, 2, 120);
    node = 1;
    while node <= 5 {
        write_record_field(syntax_data, node, 0, 13);
        write_record_field(syntax_data, node, 2, 1);
        write_usize(context.block_parent_cache, node * size_of(usize), 0);
        node = node + 1;
    }
    write_record_field(syntax_data, 1, 1, 70);
    write_record_field(syntax_data, 2, 1, 30);
    write_record_field(syntax_data, 3, 1, 30);
    write_record_field(syntax_data, 4, 1, 50);
    write_record_field(syntax_data, 5, 1, 10);
    ptr byte statement_nodes = memory.alloc(5 * size_of(usize));
    scope memory.free(statement_nodes);
    context.statement_nodes = statement_nodes;
    context.statement_count = 5;
    write_usize(statement_nodes, 0, 4);
    write_usize(statement_nodes, 8, 2);
    write_usize(statement_nodes, 16, 5);
    write_usize(statement_nodes, 24, 1);
    write_usize(statement_nodes, 32, 3);
    ir_initialize_statement_adjacency(context);
    usize item = read_usize(context.block_statement_first, 0);
    if item != 6 { return 1; }
    item = read_usize(context.statement_next, (item - 1) * 8);
    if item != 3 { return 2; }
    item = read_usize(context.statement_next, (item - 1) * 8);
    if item != 4 { return 3; }
    item = read_usize(context.statement_next, (item - 1) * 8);
    if item != 5 { return 4; }
    item = read_usize(context.statement_next, (item - 1) * 8);
    if item != 2 || read_usize(context.statement_next, 8) != 0 { return 5; }
    // Reinitialization must not retain links from the first list.
    write_usize(statement_nodes, 0, 1);
    write_usize(statement_nodes, 8, 4);
    write_usize(statement_nodes, 16, 3);
    write_usize(statement_nodes, 24, 2);
    write_usize(statement_nodes, 32, 5);
    ir_initialize_statement_adjacency(context);
    if read_usize(context.block_statement_first, 0) != 6 { return 6; }
    if read_usize(context.statement_next, cast(usize, 2) * 8) != 4 { return 7; }

    write_record_field(syntax_data, 6, 0, 11);
    write_record_field(syntax_data, 6, 1, 20);
    write_record_field(syntax_data, 6, 2, 60);
    write_record_field(syntax_data, 9, 0, 11);
    write_record_field(syntax_data, 9, 1, 220);
    write_record_field(syntax_data, 9, 2, 50);
    ptr byte block_nodes = memory.alloc(3 * size_of(usize));
    scope memory.free(block_nodes);
    write_usize(block_nodes, 0, 6);
    write_usize(block_nodes, 8, 9);
    write_usize(block_nodes, 16, 0);
    context.block_nodes = block_nodes;
    context.block_count = 3;
    ptr byte control_nodes = memory.alloc(size_of(usize));
    scope memory.free(control_nodes);
    write_usize(control_nodes, 0, 12);
    context.control_nodes = control_nodes;
    context.control_count = 1;
    write_record_field(syntax_data, 12, 0, 14);
    write_record_field(syntax_data, 12, 1, 15);
    write_record_field(syntax_data, 12, 2, 80);
    write_usize(context.control_parent_cache, cast(usize, 6) * 8, 12);
    ir_initialize_control_adjacency(context);
    node = 0;
    while node < 4 {
        usize declaration = 7;
        if node == 1 { declaration = 8; }
        if node == 2 { declaration = 10; }
        if node == 3 { declaration = 11; }
        write_record_field(symbol_data, node, 0, resolution_symbol_function());
        write_record_field(symbol_data, node, 1, 0);
        write_record_field(detail_data, node, 1, declaration);
        write_record_field(syntax_data, declaration, 0, 2);
        node = node + 1;
    }
    write_record_field(syntax_data, 7, 1, 0);
    write_record_field(syntax_data, 7, 2, 140);
    write_record_field(syntax_data, 8, 1, 150);
    write_record_field(syntax_data, 8, 2, 20);
    write_record_field(syntax_data, 10, 1, 200);
    write_record_field(syntax_data, 10, 2, 100);
    write_record_field(syntax_data, 11, 1, 320);
    write_record_field(syntax_data, 11, 2, 30);
    ptr byte positions = memory.alloc(400 * size_of(usize));
    scope memory.free(positions);
    context.function_at_position = positions;
    context.expression_start_capacity = 400;
    ir_initialize_function_positions(context);
    if ir_largest_direct_block(context, 7) != 0 { return 8; }
    if ir_largest_direct_block(context, 8) != 13 { return 9; }
    if ir_largest_direct_block(context, 10) != 9 { return 10; }
    if ir_largest_direct_block(context, 11) != 13 { return 11; }
    if ir_direct_block(context, 12, 0) != 6 { return 12; }
    context.control_block_first = null;
    if ir_largest_direct_block(context, 7) != 0 { return 13; }
    context.block_nodes = null;
    if ir_largest_direct_block(context, 10) != 9 { return 14; }
    context.source = "memory.alloc(1) memory.alloc(2)";
    write_record_field(syntax_data, 7, 1, 0);
    write_record_field(syntax_data, 7, 2, 15);
    write_record_field(syntax_data, 8, 1, 16);
    write_record_field(syntax_data, 8, 2, 15);
    context.function_node = 7;
    if !ir_function_has_single_byte_allocation(context) { return 15; }
    if context.function_alloc_probe_state != 2 { return 16; }
    if !ir_function_has_single_byte_allocation(context) { return 17; }
    context.function_node = 8;
    if ir_function_has_single_byte_allocation(context) { return 18; }
    if context.function_alloc_probe_state != 1 { return 19; }
    context.function_node = 7;
    if !ir_function_has_single_byte_allocation(context) { return 20; }
    // A new lowering must clear the lazy fact, including on reused contexts.
    context.source = "memory.alloc(2) memory.alloc(2)";
    context.function_alloc_probe_state = 0;
    if ir_function_has_single_byte_allocation(context) { return 21; }
    // Direct-parent construction must retain self exclusion, input-order
    // ties, absence, and the old no-larger-parent containment fallback.
    context.block_nodes = block_nodes;
    context.block_count = 1;
    write_usize(block_nodes, 0, 0);
    ir_initialize_parent_position_kind(context, true, null);
    if read_usize(context.block_parent_cache, 0) != 13 { return 22; }
    if read_usize(context.block_parent_cache, cast(usize, 6) * 8) != 0 { return 23; }
    context.block_count = 2;
    write_usize(block_nodes, 8, 6);
    ir_initialize_parent_position_kind(context, true, null);
    if read_usize(context.block_parent_cache, cast(usize, 6) * 8) != 0 { return 24; }
    if read_usize(context.block_parent_cache, 8) != 6 { return 25; }
    write_record_field(syntax_data, 9, 1, 20);
    write_record_field(syntax_data, 9, 2, 60);
    write_usize(block_nodes, 0, 6);
    write_usize(block_nodes, 8, 9);
    ir_initialize_parent_position_kind(context, true, null);
    if read_usize(context.block_parent_cache, 8) != 6 { return 26; }
    if read_usize(context.block_parent_cache, cast(usize, 6) * 8) != 9 { return 27; }
    write_usize(block_nodes, 0, 9);
    write_usize(block_nodes, 8, 6);
    ir_initialize_parent_position_kind(context, true, null);
    if read_usize(context.block_parent_cache, 8) != 9 { return 28; }
    write_usize(block_nodes, 0, 0);
    write_usize(block_nodes, 8, 6);
    write_record_field(syntax_data, 9, 2, 100);
    ir_initialize_parent_position_kind(context, true, null);
    if read_usize(context.block_parent_cache, cast(usize, 9) * 8) != 13 { return 29; }
    context.block_count = 0;
    ir_initialize_parent_position_kind(context, true, null);
    if read_usize(context.block_parent_cache, 8) != 13 { return 30; }
    ptr byte probe_second = memory.alloc(400 * size_of(usize));
    scope memory.free(probe_second);
    ptr byte probe_expected = memory.alloc(13 * size_of(usize));
    scope memory.free(probe_expected);
    context.control_nodes = block_nodes;
    usize probe_case = 0;
    while probe_case < 96 {
        usize candidate_count = probe_case % 3;
        context.block_count = candidate_count;
        context.control_count = candidate_count;
        bool test_blocks = probe_case % 2 == 0;
        context.expression_start_capacity = 400;
        if probe_case % 7 == 0 { context.expression_start_capacity = 0; }
        if probe_case % 7 == 1 { context.expression_start_capacity = 1; }
        if probe_case % 7 == 2 { context.expression_start_capacity = 127; }
        write_usize(block_nodes, 0, 0);
        write_usize(block_nodes, 8, 6);
        if probe_case % 11 == 0 { write_usize(block_nodes, 8, 0); }
        write_record_field(syntax_data, 0, 1, probe_case * 17 % 450);
        write_record_field(syntax_data, 0, 2, probe_case * 13 % 550);
        write_record_field(syntax_data, 6, 1, probe_case * 43 % 410);
        write_record_field(syntax_data, 6, 2, probe_case * 29 % 500);
        ptr byte parent_cache = context.control_parent_cache;
        if test_blocks { parent_cache = context.block_parent_cache; }
        usize differential_node = 0;
        while differential_node < context.syntax.length {
            write_usize(parent_cache, differential_node * size_of(usize), 117);
            differential_node = differential_node + 1;
        }
        probe_parent_reference(context, test_blocks, probe_second);
        differential_node = 0;
        while differential_node < context.syntax.length {
            write_usize(probe_expected, differential_node * size_of(usize),
                read_usize(parent_cache, differential_node * size_of(usize)));
            write_usize(parent_cache, differential_node * size_of(usize), 117);
            differential_node = differential_node + 1;
        }
        ir_initialize_parent_position_kind(context, test_blocks, null);
        differential_node = 0;
        while differential_node < context.syntax.length {
            if read_usize(probe_expected, differential_node * size_of(usize)) !=
                read_usize(parent_cache, differential_node * size_of(usize)) {
                return 100 + cast(i32, probe_case);
            }
            differential_node = differential_node + 1;
        }
        probe_case = probe_case + 1;
    }
    io.println("statement-handoff-ok");
    return 0;
}
unsafe void probe_parent_reference(
    ref IrContext context,
    bool blocks,
    ptr byte second_at_position
) {
    if context.function_at_position == null ||
        context.expression_start_capacity == 0 { return; }
    usize position = 0;
    while position < context.expression_start_capacity {
        write_usize(
            context.function_at_position, position * size_of(usize), 0
        );
        write_usize(
            second_at_position, position * size_of(usize), 0
        );
        position = position + 1;
    }
    usize candidate_count = context.control_count;
    ptr byte candidates = context.control_nodes;
    if blocks {
        candidate_count = context.block_count;
        candidates = context.block_nodes;
    }
    usize index = 0;
    while index < candidate_count {
        usize candidate = read_usize(
            candidates, index * size_of(usize)
        );
        usize candidate_length = read_record_field(
            context.syntax_data, candidate, 2
        );
        usize start = read_record_field(
            context.syntax_data, candidate, 1
        );
        usize end = start + candidate_length;
        if end > context.expression_start_capacity {
            end = context.expression_start_capacity;
        }
        while start < end {
            usize best = read_usize(
                context.function_at_position, start * size_of(usize)
            );
            if best == 0 || candidate_length < read_record_field(
                    context.syntax_data, best - 1, 2
                ) {
                write_usize(
                    second_at_position, start * size_of(usize), best
                );
                write_usize(
                    context.function_at_position,
                    start * size_of(usize), candidate + 1
                );
            } else {
                usize second = read_usize(
                    second_at_position, start * size_of(usize)
                );
                if candidate + 1 != best && (second == 0 ||
                    candidate_length < read_record_field(
                        context.syntax_data, second - 1, 2
                    )) {
                    write_usize(
                        second_at_position,
                        start * size_of(usize), candidate + 1
                    );
                }
            }
            start = start + 1;
        }
        index = index + 1;
    }
    ptr byte parent_cache = context.control_parent_cache;
    if blocks { parent_cache = context.block_parent_cache; }
    usize node = 0;
    while node < context.syntax.length {
        usize start = read_record_field(context.syntax_data, node, 1);
        usize parent = 0;
        if start < context.expression_start_capacity {
            parent = read_usize(
                context.function_at_position, start * size_of(usize)
            );
            if parent == node + 1 {
                parent = read_usize(
                    second_at_position, start * size_of(usize)
                );
            }
        }
        usize selected = context.syntax.length;
        if parent != 0 && semantic_node_contains(
            context.syntax_data, parent - 1, node
        ) { selected = parent - 1; }
        write_usize(parent_cache, node * size_of(usize), selected);
        node = node + 1;
    }
}
