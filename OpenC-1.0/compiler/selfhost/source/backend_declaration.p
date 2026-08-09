import system.file;
import system.memory;
import system.path;
import system.text;

unsafe void d_emit_type_declarations(
    ref IrContext context,
    ref DBuffer buffer,
    usize module_index
) {
    usize symbol = 0;
    while symbol < context.symbols.length {
        usize kind = read_record_field(context.symbol_data, symbol, 0);
        if read_record_field(context.detail_data, symbol, 0) == module_index &&
            read_record_field(context.detail_data, symbol, 2) == 0 &&
            (kind == resolution_symbol_struct() ||
             kind == resolution_symbol_resource()) {
            d_put(buffer, "struct "); d_put_symbol_name(context, buffer, symbol);
            d_put(buffer, " {\n");
            usize field = 0;
            while field < context.symbols.length {
                if read_record_field(context.symbol_data, field, 0) ==
                        resolution_symbol_field() &&
                    read_record_field(context.detail_data, field, 2) ==
                        symbol + 1 {
                    d_put(buffer, "    ");
                    d_put_type(
                        context, buffer,
                        read_record_field(context.symbol_data, field, 4)
                    );
                    d_put(buffer, " "); d_put_symbol_name(context, buffer, field);
                    d_put(buffer, ";\n");
                }
                field = field + 1;
            }
            d_put(buffer, "}\n\n");
        } else if read_record_field(
                context.detail_data, symbol, 0
            ) == module_index && read_record_field(
                context.detail_data, symbol, 2
            ) == 0 && kind == resolution_symbol_enum() {
            text enum_source = d_symbol_source(context, symbol);
            usize name_end = read_record_field(
                context.symbol_data, symbol, 2
            ) + read_record_field(context.symbol_data, symbol, 3);
            usize declaration_end = resolution_span_start(read_record_field(
                context.detail_data, symbol, 4
            )) + resolution_span_length(read_record_field(
                context.detail_data, symbol, 4
            ));
            usize colon = name_end;
            while colon < declaration_end && byte_at_or_zero(
                enum_source, colon
            ) != 58 && byte_at_or_zero(enum_source, colon) != 123 {
                colon = colon + 1;
            }
            usize underlying = semantic_builtin_type("u32", 0, 3);
            if colon < declaration_end && byte_at_or_zero(
                enum_source, colon
            ) == 58 {
                usize type_start = colon + 1;
                while type_start < declaration_end && (
                    byte_at_or_zero(enum_source, type_start) == 32 ||
                    byte_at_or_zero(enum_source, type_start) == 9 ||
                    byte_at_or_zero(enum_source, type_start) == 10 ||
                    byte_at_or_zero(enum_source, type_start) == 13
                ) { type_start = type_start + 1; }
                usize type_end = type_start;
                while type_end < declaration_end &&
                    byte_at_or_zero(enum_source, type_end) != 32 &&
                    byte_at_or_zero(enum_source, type_end) != 9 &&
                    byte_at_or_zero(enum_source, type_end) != 10 &&
                    byte_at_or_zero(enum_source, type_end) != 13 &&
                    byte_at_or_zero(enum_source, type_end) != 123 {
                    type_end = type_end + 1;
                }
                underlying = semantic_builtin_type(
                    enum_source, type_start, type_end - type_start
                );
            }
            d_put(buffer, "enum "); d_put_symbol_name(context, buffer, symbol);
            d_put(buffer, " : "); d_put_type(context, buffer, underlying);
            d_put(buffer, " {\n");
            usize item_value = 0;
            usize item = 0;
            while item < context.symbols.length {
                if read_record_field(context.symbol_data, item, 0) ==
                        resolution_symbol_enum_item() &&
                    read_record_field(context.detail_data, item, 2) ==
                        symbol + 1 {
                    d_put(buffer, "    "); d_put_symbol_name(context, buffer, item);
                    d_put(buffer, " = "); d_put_usize(buffer, item_value);
                    d_put(buffer, ",\n");
                    item_value = item_value + 1;
                }
                item = item + 1;
            }
            d_put(buffer, "}\n\n");
        }
        symbol = symbol + 1;
    }
}

unsafe void d_emit_function(
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

    d_put_type(context, buffer, context.function_result);
    d_put(buffer, " ");
    bool entry = context.module_index == entry_module &&
        d_symbol_name_is(context, function_symbol, "main");
    if entry { d_put(buffer, "__openc_entry_main"); }
    else { d_put_qualified_symbol(context, buffer, function_symbol, true); }
    d_put(buffer, "(");
    usize parameter_count = d_parameter_count(context, function_symbol);
    usize parameter_index = 0;
    while parameter_index < parameter_count {
        if parameter_index != 0 { d_put(buffer, ", "); }
        usize parameter = d_parameter_at(
            context, function_symbol, parameter_index
        );
        usize mode = read_record_field(context.detail_data, parameter, 3);
        usize parameter_type = read_record_field(
            context.symbol_data, parameter, 4
        );
        if mode == 1 { d_put(buffer, "out "); }
        else if d_parameter_owned(context, parameter) ||
            (parameter_type < context.types.length && read_record_field(
                context.type_data, parameter_type, 0
            ) == 12) { d_put(buffer, "ref "); }
        d_put_type(context, buffer, parameter_type);
        d_put(buffer, " "); d_put_symbol_name(context, buffer, parameter);
        parameter_index = parameter_index + 1;
    }
    d_put(buffer, ") {\n");

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
            d_put_value_type(context, buffer, type_id);
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

    usize guard = 0;
    ordered = 0;
    while ordered < context.instructions.length {
        usize instruction = read_usize(
            instruction_order, ordered * size_of(usize)
        );
        if read_record_field(
            context.instruction_data, instruction, 2
        ) == ir_op_scope_register() {
            d_put(buffer, "    bool scope_active_");
            d_put_usize(buffer, guard);
            d_put(buffer, ";\n    scope(exit) { if (scope_active_");
            d_put_usize(buffer, guard); d_put(buffer, ") { ");
            d_emit_scope_action(
                context, buffer, instruction, reference_storage
            );
            d_put(buffer, "; } }\n");
            guard = guard + 1;
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
            d_emit_instruction(
                context, buffer, instruction,
                value_types, reference_storage, next_guard
            );
            emitted = true;
            ordered = ordered + 1;
        }
        if !emitted { d_put(buffer, "    ;\n"); }
        block = block + 1;
    }
    if context.function_result == semantic_type_void() {
        d_put(buffer, "    return;\n");
    } else {
        d_put(buffer, "    openc.runtime.checked.opencCheckedFailure(\"function completed without a return\");\n");
    }
    d_put(buffer, "}\n\n");
    memory.free(instruction_order);
    memory.free(reference_storage);
    memory.free(value_types);
}
