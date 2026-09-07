import system.file;
import system.memory;
import system.path;
import system.text;

unsafe bool c_function_is_entry(
    ref IrContext context,
    usize function_symbol,
    usize entry_module
) {
    return read_record_field(context.detail_data, function_symbol, 0) ==
            entry_module &&
        d_symbol_name_is(context, function_symbol, "main");
}

unsafe void c_put_function_name(
    ref IrContext context,
    ref DBuffer buffer,
    usize function_symbol,
    usize entry_module
) {
    if c_function_is_entry(context, function_symbol, entry_module) {
        d_put(buffer, "oc_entry_main");
    } else {
        c_put_qualified_symbol(context, buffer, function_symbol);
    }
}

unsafe void c_put_parameter_declaration(
    ref IrContext context,
    ref DBuffer buffer,
    usize parameter
) {
    usize mode = read_record_field(context.detail_data, parameter, 3);
    usize type_id = read_record_field(context.symbol_data, parameter, 4);
    c_put_type(context, buffer, type_id);
    if (mode == 1 || d_parameter_owned(context, parameter)) &&
        !c_type_is_reference(context, type_id) {
        d_put(buffer, "*");
    }
    d_put(buffer, " ");
    d_put_symbol_name(context, buffer, parameter);
}

unsafe void c_put_function_signature(
    ref IrContext context,
    ref DBuffer buffer,
    usize function_symbol,
    usize entry_module
) {
    c_put_type(
        context, buffer,
        read_record_field(context.symbol_data, function_symbol, 4)
    );
    d_put(buffer, " ");
    c_put_function_name(context, buffer, function_symbol, entry_module);
    d_put(buffer, "(");
    usize count = d_parameter_count(context, function_symbol);
    if count == 0 { d_put(buffer, "void"); }
    usize index = 0;
    while index < count {
        if index != 0 { d_put(buffer, ", "); }
        c_put_parameter_declaration(
            context, buffer,
            d_parameter_at(context, function_symbol, index)
        );
        index = index + 1;
    }
    d_put(buffer, ")");
}

unsafe void c_emit_forward_types(
    ref IrContext context,
    ref DBuffer buffer
) {
    usize symbol = 0;
    while symbol < context.symbols.length {
        usize kind = read_record_field(context.symbol_data, symbol, 0);
        if read_record_field(context.detail_data, symbol, 2) == 0 &&
            (kind == resolution_symbol_struct() ||
             kind == resolution_symbol_resource()) {
            d_put(buffer, "typedef struct ");
            c_put_qualified_symbol(context, buffer, symbol);
            d_put(buffer, " ");
            c_put_qualified_symbol(context, buffer, symbol);
            d_put(buffer, ";\n");
        }
        symbol = symbol + 1;
    }
    d_put(buffer, "\n");
}

unsafe void c_emit_enum_types(
    ref IrContext context,
    ref DBuffer buffer
) {
    usize symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_enum() &&
            read_record_field(context.detail_data, symbol, 2) == 0 {
            d_put(buffer, "typedef uint32_t ");
            c_put_qualified_symbol(context, buffer, symbol);
            d_put(buffer, ";\n");
        }
        symbol = symbol + 1;
    }
    d_put(buffer, "\n");
}

unsafe void c_emit_compound_types(
    ref IrContext context,
    ref DBuffer buffer
) {
    usize type_id = 0;
    while type_id < context.types.length {
        usize kind = read_record_field(context.type_data, type_id, 0);
        if kind == 10 {
            d_put(buffer, "typedef struct oc_type_");
            d_put_usize(buffer, type_id); d_put(buffer, " { ");
            c_put_type(
                context, buffer,
                read_record_field(context.type_data, type_id, 1)
            );
            d_put(buffer, " data[");
            d_put_usize(
                buffer, read_record_field(context.type_data, type_id, 2)
            );
            d_put(buffer, "]; } oc_type_"); d_put_usize(buffer, type_id);
            d_put(buffer, ";\n");
        } else if kind == 11 {
            d_put(buffer, "typedef struct oc_type_");
            d_put_usize(buffer, type_id); d_put(buffer, " { ");
            c_put_type(
                context, buffer,
                read_record_field(context.type_data, type_id, 1)
            );
            d_put(buffer, " *data; uintptr_t length; } oc_type_");
            d_put_usize(buffer, type_id); d_put(buffer, ";\n");
        } else if kind == 14 {
            d_put(buffer, "typedef struct oc_type_");
            d_put_usize(buffer, type_id);
            d_put(buffer, " { bool present; ");
            c_put_type(
                context, buffer,
                read_record_field(context.type_data, type_id, 1)
            );
            d_put(buffer, " value; } oc_type_");
            d_put_usize(buffer, type_id); d_put(buffer, ";\n");
        } else if kind == 15 {
            d_put(buffer, "typedef union oc_type_");
            d_put_usize(buffer, type_id);
            d_put(buffer, " { uint64_t alignment; unsigned char bytes[sizeof(");
            c_put_type(
                context, buffer,
                read_record_field(context.type_data, type_id, 1)
            );
            d_put(buffer, ")]; } oc_type_");
            d_put_usize(buffer, type_id); d_put(buffer, ";\n");
        }
        type_id = type_id + 1;
    }
    d_put(buffer, "\n");
}

unsafe void c_emit_named_type_bodies(
    ref IrContext context,
    ref DBuffer buffer
) {
    usize symbol = 0;
    while symbol < context.symbols.length {
        usize kind = read_record_field(context.symbol_data, symbol, 0);
        if read_record_field(context.detail_data, symbol, 2) == 0 &&
            (kind == resolution_symbol_struct() ||
             kind == resolution_symbol_resource()) {
            d_put(buffer, "struct ");
            c_put_qualified_symbol(context, buffer, symbol);
            d_put(buffer, " {\n");
            usize fields = 0;
            usize field = 0;
            while field < context.symbols.length {
                if read_record_field(context.symbol_data, field, 0) ==
                        resolution_symbol_field() &&
                    read_record_field(context.detail_data, field, 2) ==
                        symbol + 1 {
                    d_put(buffer, "    ");
                    c_put_type(
                        context, buffer,
                        read_record_field(context.symbol_data, field, 4)
                    );
                    d_put(buffer, " ");
                    d_put_symbol_name(context, buffer, field);
                    d_put(buffer, ";\n");
                    fields = fields + 1;
                }
                field = field + 1;
            }
            if fields == 0 { d_put(buffer, "    uint8_t nonzero_size;\n"); }
            d_put(buffer, "};\n\n");
        }
        symbol = symbol + 1;
    }
}

unsafe void c_emit_function_prototypes(
    ref IrContext context,
    ref DBuffer buffer,
    usize entry_module
) {
    usize symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_function() &&
            read_record_field(context.detail_data, symbol, 2) == 0 {
            c_put_function_signature(
                context, buffer, symbol, entry_module
            );
            d_put(buffer, ";\n");
        }
        symbol = symbol + 1;
    }
    d_put(buffer, "\n");
}

unsafe void c_emit_scope_action(
    ref IrContext context,
    ref DBuffer buffer,
    usize instruction,
    ptr byte reference_storage,
    ptr byte value_types
) {
    if d_instruction_text_is(context, instruction, "destroy") {
        return;
    }
    if d_instruction_text_is(context, instruction, "unsupported") { return; }
    c_put_call_name(context, buffer, instruction, value_types);
    d_put(buffer, "(");
    usize count = d_operand_count(context, instruction);
    usize index = 0;
    while index < count {
        if index != 0 { d_put(buffer, ", "); }
        c_put_call_argument(
            context, buffer, instruction, index,
            value_types, reference_storage
        );
        index = index + 1;
    }
    d_put(buffer, ")");
}

unsafe void c_emit_cleanup_guards(
    ref IrContext context,
    ref DBuffer buffer,
    ptr byte instruction_order,
    ptr byte reference_storage,
    ptr byte value_types,
    usize guard_count
) {
    usize requested = guard_count;
    while requested != 0 {
        requested = requested - 1;
        usize seen = 0;
        usize ordered = 0;
        while ordered < context.instructions.length {
            usize instruction = read_usize(
                instruction_order, ordered * size_of(usize)
            );
            if read_record_field(
                context.instruction_data, instruction, 2
            ) == ir_op_scope_register() {
                if seen == requested {
                    d_put(buffer, "    if (scope_active_");
                    d_put_usize(buffer, requested); d_put(buffer, ") { ");
                    c_emit_scope_action(
                        context, buffer, instruction,
                        reference_storage, value_types
                    );
                    d_put(buffer, "; scope_active_");
                    d_put_usize(buffer, requested);
                    d_put(buffer, " = false; }\n");
                    ordered = context.instructions.length;
                }
                seen = seen + 1;
            }
            ordered = ordered + 1;
        }
    }
}

unsafe void c_emit_function(
    ref IrContext context,
    ref DBuffer buffer,
    usize function_symbol,
    usize entry_module
) {
    usize value_capacity = context.next_value + 1;
    ptr byte value_types = memory.alloc(value_capacity * size_of(usize));
    ptr byte reference_storage = memory.alloc(
        value_capacity * size_of(usize)
    );
    ptr byte instruction_order = d_instruction_order(context);
    d_analyze_values(
        context, value_types, reference_storage,
        instruction_order
    );

    c_put_function_signature(
        context, buffer, function_symbol, entry_module
    );
    d_put(buffer, " {\n");
    usize ordered = 0;
    while ordered < context.instructions.length {
        usize instruction = read_usize(
            instruction_order, ordered * size_of(usize)
        );
        usize result = read_record_field(
            context.instruction_data, instruction, 1
        );
        usize type_id = read_record_field(
            context.instruction_data, instruction, 3
        );
        if result != 0 && type_id < context.types.length &&
            read_record_field(context.type_data, type_id, 0) != 1 {
            d_put(buffer, "    ");
            c_put_type(context, buffer, type_id);
            if read_record_field(
                context.instruction_data, instruction, 2
            ) == ir_op_aggregate_field() && d_instruction_address_field(
                context, instruction
            ) { d_put(buffer, "*"); }
            d_put(buffer, " v"); d_put_usize(buffer, result);
            d_put(buffer, ";\n");
        }
        ordered = ordered + 1;
    }

    usize guard_count = 0;
    ordered = 0;
    while ordered < context.instructions.length {
        usize instruction = read_usize(
            instruction_order, ordered * size_of(usize)
        );
        if read_record_field(
            context.instruction_data, instruction, 2
        ) == ir_op_scope_register() {
            d_put(buffer, "    bool scope_active_");
            d_put_usize(buffer, guard_count);
            d_put(buffer, " = false;\n");
            guard_count = guard_count + 1;
        }
        ordered = ordered + 1;
    }

    DScopeState next_guard = DScopeState{ next = 0 };
    usize block = 0;
    ordered = 0;
    while block < context.blocks.length {
        d_put(buffer, "block_"); d_put_usize(buffer, block);
        d_put(buffer, ":\n");
        bool emitted = false;
        while ordered < context.instructions.length && read_record_field(
            context.instruction_data, read_usize(
                instruction_order, ordered * size_of(usize)
            ), 0
        ) == block {
            usize instruction = read_usize(
                instruction_order, ordered * size_of(usize)
            );
            c_emit_instruction(
                context, buffer, instruction,
                value_types, reference_storage, instruction_order,
                next_guard, guard_count
            );
            emitted = true;
            ordered = ordered + 1;
        }
        if !emitted { d_put(buffer, "    ;\n"); }
        block = block + 1;
    }
    c_emit_cleanup_guards(
        context, buffer, instruction_order,
        reference_storage, value_types, guard_count
    );
    if context.function_result == semantic_type_void() {
        d_put(buffer, "    return;\n");
    } else {
        d_put(buffer, "    ocb_checked_failure(OC_TEXT_LITERAL(\"function completed without a return\"));\n");
    }
    d_put(buffer, "}\n\n");
    memory.free(instruction_order);
    memory.free(reference_storage);
    memory.free(value_types);
}
