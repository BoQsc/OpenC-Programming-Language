import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe void ir_record_call_argument(
    ref IrContext context,
    usize call,
    usize argument_node
) {
    if context.call_argument_first == null ||
        context.call_argument_last == null || context.argument_next == null ||
        call >= context.syntax.length ||
        argument_node >= context.syntax.length { return; }
    usize last = read_usize(
        context.call_argument_last, call * size_of(usize)
    );
    if last == 0 {
        write_usize(
            context.call_argument_first,
            call * size_of(usize), argument_node + 1
        );
    } else {
        write_usize(
            context.argument_next,
            (last - 1) * size_of(usize), argument_node + 1
        );
    }
    write_usize(
        context.call_argument_last,
        call * size_of(usize), argument_node + 1
    );
}

unsafe usize ir_call_argument_node(
    ref IrContext context,
    usize call,
    usize requested
) {
    if context.call_argument_first == null ||
        context.argument_next == null || call >= context.syntax.length {
        return context.syntax.length;
    }
    usize encoded = read_usize(
        context.call_argument_first, call * size_of(usize)
    );
    usize index = 0;
    while encoded != 0 && index < requested {
        encoded = read_usize(
            context.argument_next,
            (encoded - 1) * size_of(usize)
        );
        index = index + 1;
    }
    if encoded == 0 { return context.syntax.length; }
    return encoded - 1;
}

unsafe void ir_initialize_statement_adjacency(ref IrContext context) {
    if context.block_statement_first == null ||
        context.statement_next == null { return; }
    usize node = 0;
    while node <= context.syntax.length {
        write_usize(
            context.block_statement_first,
            node * size_of(usize), 0
        );
        write_usize(
            context.statement_next,
            node * size_of(usize), 0
        );
        node = node + 1;
    }
    usize index = 0;
    while index < context.statement_count {
        usize record = read_usize(
            context.statement_nodes, index * size_of(usize)
        );
        usize block = ir_block_parent(context, record);
        if block < context.syntax.length {
            usize control = ir_control_parent(context, record);
            bool direct = control >= context.syntax.length;
            if !direct {
                direct = ir_block_parent(context, control) != block;
            }
            if direct {
                usize start = read_record_field(
                    context.syntax_data, record, 1
                );
                usize previous = 0;
                usize encoded = read_usize(
                    context.block_statement_first,
                    block * size_of(usize)
                );
                while encoded != 0 {
                    usize current = encoded - 1;
                    usize current_start = read_record_field(
                        context.syntax_data, current, 1
                    );
                    if current_start > start ||
                        (current_start == start && current > record) {
                        break;
                    }
                    previous = encoded;
                    encoded = read_usize(
                        context.statement_next,
                        current * size_of(usize)
                    );
                }
                if previous == 0 {
                    write_usize(
                        context.block_statement_first,
                        block * size_of(usize), record + 1
                    );
                } else {
                    write_usize(
                        context.statement_next,
                        (previous - 1) * size_of(usize), record + 1
                    );
                }
                write_usize(
                    context.statement_next,
                    record * size_of(usize), encoded
                );
            }
        }
        index = index + 1;
    }
}
