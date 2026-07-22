import system.file;
import system.memory;
import system.path;
import system.text;

unsafe bool d_local_is_parameter(
    ref IrContext context,
    usize instruction
) {
    usize symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_parameter() &&
            read_record_field(context.detail_data, symbol, 2) ==
                context.function_symbol + 1 && span_equals_ascii(
                    context.source,
                    read_record_field(context.instruction_detail, instruction, 1),
                    read_record_field(context.instruction_detail, instruction, 2),
                    project_slice(
                        context.source,
                        read_record_field(context.symbol_data, symbol, 2),
                        read_record_field(context.symbol_data, symbol, 3)
                    )
                ) { return true; }
        symbol = symbol + 1;
    }
    return false;
}

unsafe ptr byte d_instruction_order(ref IrContext context) {
    ptr byte order = memory.alloc(
        (context.instructions.length + 1) * size_of(usize)
    );
    ptr byte counts = memory.alloc(
        (context.blocks.length + 1) * size_of(usize)
    );
    ptr byte cursors = memory.alloc(
        (context.blocks.length + 1) * size_of(usize)
    );
    usize block = 0;
    while block <= context.blocks.length {
        write_usize(counts, block * size_of(usize), 0);
        write_usize(cursors, block * size_of(usize), 0);
        block = block + 1;
    }
    usize instruction = 0;
    while instruction < context.instructions.length {
        block = read_record_field(
            context.instruction_data, instruction, 0
        );
        if block < context.blocks.length {
            write_usize(
                counts, block * size_of(usize),
                read_usize(counts, block * size_of(usize)) + 1
            );
        }
        instruction = instruction + 1;
    }
    usize offset = 0;
    block = 0;
    while block < context.blocks.length {
        write_usize(cursors, block * size_of(usize), offset);
        offset = offset + read_usize(counts, block * size_of(usize));
        block = block + 1;
    }
    instruction = 0;
    while instruction < context.instructions.length {
        block = read_record_field(
            context.instruction_data, instruction, 0
        );
        if block < context.blocks.length {
            usize cursor = read_usize(cursors, block * size_of(usize));
            write_usize(order, cursor * size_of(usize), instruction);
            write_usize(cursors, block * size_of(usize), cursor + 1);
        }
        instruction = instruction + 1;
    }
    memory.free(cursors);
    memory.free(counts);
    return order;
}

unsafe void d_analyze_values(
    ref IrContext context,
    ptr byte value_types,
    ptr byte reference_storage,
    ptr byte instruction_order,
    usize capacity
) {
    usize index = 0;
    while index < capacity {
        write_usize(value_types, index * size_of(usize), 0);
        write_usize(reference_storage, index * size_of(usize), 0);
        index = index + 1;
    }
    usize ordered = 0;
    while ordered < context.instructions.length {
        usize instruction = read_usize(
            instruction_order, ordered * size_of(usize)
        );
        usize result = read_record_field(
            context.instruction_data, instruction, 1
        );
        usize opcode = read_record_field(
            context.instruction_data, instruction, 2
        );
        if result != 0 {
            write_usize(
                value_types, result * size_of(usize),
                read_record_field(context.instruction_data, instruction, 3)
            );
        }
        if opcode == ir_op_object_construct() && result != 0 {
            write_usize(
                reference_storage, result * size_of(usize),
                d_operand_value(context, instruction, 0) + 1
            );
        } else if opcode == ir_op_load() && result != 0 {
            usize source = d_operand_value(context, instruction, 0);
            write_usize(
                reference_storage, result * size_of(usize),
                read_usize(reference_storage, source * size_of(usize))
            );
        } else if opcode == ir_op_store() {
            usize destination = d_operand_value(context, instruction, 0);
            usize source = d_operand_value(context, instruction, 1);
            write_usize(
                reference_storage, destination * size_of(usize),
                read_usize(reference_storage, source * size_of(usize))
            );
        }
        ordered = ordered + 1;
    }
}

unsafe void d_emit_scope_action(
    ref IrContext context,
    ref DBuffer buffer,
    usize instruction,
    ptr byte reference_storage
) {
    if d_instruction_text_is(context, instruction, "destroy") {
        usize source = d_operand_value(context, instruction, 0);
        usize storage_value = read_usize(
            reference_storage, source * size_of(usize)
        );
        if storage_value != 0 {
            d_put(buffer, "v"); d_put_usize(buffer, storage_value - 1);
            d_put(buffer, ".destroyValue()");
        } else {
            d_put(buffer, "destroy(v"); d_put_usize(buffer, source);
            d_put(buffer, ")");
        }
        return;
    }
    if d_instruction_text_is(context, instruction, "unsupported") { return; }
    d_put_call_name(context, buffer, instruction);
    d_put(buffer, "(");
    usize count = d_operand_count(context, instruction);
    usize index = 0;
    while index < count {
        if index != 0 { d_put(buffer, ", "); }
        d_put(buffer, "v");
        d_put_usize(buffer, d_operand_value(context, instruction, index));
        index = index + 1;
    }
    d_put(buffer, ")");
}

unsafe void d_put_lhs(ref DBuffer buffer, usize result) {
    d_put(buffer, "    v");
    d_put_usize(buffer, result);
    d_put(buffer, " = ");
}
