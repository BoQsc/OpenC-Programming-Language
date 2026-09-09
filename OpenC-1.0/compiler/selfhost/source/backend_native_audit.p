import system.memory;

// This census uses the exact typed IR consumed by the native emitter. It is
// intentionally conservative: every project function is included, even when
// it is not reachable from main. It is an inventory, not an acceptance proof.
unsafe void native_audit_function(
    ref IrContext context,
    ref DBuffer output,
    usize symbol,
    usize ordinal
) {
    if ordinal > 1 { d_put(output, ",\n"); }
    d_put(output, "{\"symbol\":"); d_put_usize(output, symbol);
    d_put(output, ",\"source\":"); d_put_usize(output, context.source_record);
    d_put(output, ",\"name\":\""); d_put_symbol_name(context, output, symbol);
    d_put(output, "\",\"opcodes\":[");
    ptr byte counts = memory.alloc(34 * size_of(usize));
    scope memory.free(counts);
    usize index = 0;
    while index < 34 {
        write_usize(counts, index * size_of(usize), 0);
        index = index + 1;
    }
    index = 0;
    while index < context.instructions.length {
        usize opcode = read_record_field(context.instruction_data, index, 2);
        if opcode < 34 {
            write_usize(counts, opcode * size_of(usize),
                read_usize(counts, opcode * size_of(usize)) + 1);
        }
        index = index + 1;
    }
    index = 1;
    while index < 34 {
        if index > 1 { d_put(output, ","); }
        d_put_usize(output, read_usize(counts, index * size_of(usize)));
        index = index + 1;
    }
    d_put(output, "],\"value_type_kinds\":[");
    index = 0;
    while index < 34 {
        write_usize(counts, index * size_of(usize), 0);
        index = index + 1;
    }
    index = 0;
    while index < context.instructions.length {
        usize type_id = read_record_field(context.instruction_data, index, 3);
        if type_id < context.types.length {
            usize kind = read_record_field(context.type_data, type_id, 0);
            if kind < 34 {
                write_usize(counts, kind * size_of(usize),
                    read_usize(counts, kind * size_of(usize)) + 1);
            }
        }
        index = index + 1;
    }
    index = 0;
    while index < 16 {
        if index > 0 { d_put(output, ","); }
        d_put_usize(output, read_usize(counts, index * size_of(usize)));
        index = index + 1;
    }
    d_put(output, "],\"calls\":[");
    usize value_capacity = context.next_value + 1;
    ptr byte value_types = memory.alloc(value_capacity * size_of(usize));
    scope memory.free(value_types);
    ptr byte reference_storage = memory.alloc(value_capacity * size_of(usize));
    scope memory.free(reference_storage);
    ptr byte order = d_instruction_order(context);
    scope memory.free(order);
    d_analyze_values(context, value_types, reference_storage, order);
    usize call_count = 0;
    index = 0;
    while index < context.instructions.length {
        if read_record_field(context.instruction_data, index, 2) == ir_op_call() {
            if call_count > 0 { d_put(output, ","); }
            d_put(output, "{\"instruction\":"); d_put_usize(output, index);
            d_put(output, ",\"kind\":");
            d_put_usize(output, read_record_field(context.instruction_detail, index, 0));
            d_put(output, ",\"target\":");
            d_put_usize(output, read_record_field(context.instruction_detail, index, 1));
            d_put(output, ",\"legacy_binding\":\"");
            c_put_call_name(context, output, index, value_types);
            d_put(output, "\"}");
            call_count = call_count + 1;
        }
        index = index + 1;
    }
    d_put(output, "],\"scopes\":[");
    usize scope_records = 0;
    index = 0;
    while index < context.instructions.length {
        if read_record_field(
            context.instruction_data, index, 2
        ) == ir_op_scope_register() {
            if scope_records != 0 { d_put(output, ","); }
            d_put(output, "{\"instruction\":"); d_put_usize(output, index);
            d_put(output, ",\"kind\":");
            d_put_usize(output,
                read_record_field(context.instruction_detail, index, 0));
            d_put(output, ",\"target\":");
            d_put_usize(output,
                read_record_field(context.instruction_detail, index, 1));
            d_put(output, ",\"operands\":");
            d_put_usize(output, d_operand_count(context, index));
            d_put(output, "}");
            scope_records = scope_records + 1;
        }
        index = index + 1;
    }
    d_put(output, "]}");
}
