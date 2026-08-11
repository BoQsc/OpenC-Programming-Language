import system.file;
import system.memory;
import system.path;
import system.text;

unsafe bool c_call_builtin_out(
    ref IrContext context,
    usize instruction,
    usize index
) {
    if (c_builtin_is(
            context, instruction,
            "file.read_text", "system.file.read_text"
        ) || c_builtin_is(
            context, instruction,
            "file.read_text_cached", "system.file.read_text_cached"
        )) && index == 1 { return true; }
    if c_builtin_is(
            context, instruction,
            "text.slice", "system.text.slice"
        ) && index == 3 { return true; }
    if c_builtin_is(
            context, instruction,
            "process.run", "system.process.run"
        ) && (index == 1 || index == 2) { return true; }
    return false;
}

unsafe void c_put_call_argument(
    ref IrContext context,
    ref DBuffer buffer,
    usize instruction,
    usize index,
    ptr byte value_types
) {
    if c_builtin_is(
            context, instruction,
            "c_parallel_jobs", "openc.selfhost.main.c_parallel_jobs"
        ) && index == 2 {
        d_put(
            buffer,
            "(void *)oc_openc_selfhost_main_c_emit_parallel_worker"
        );
        return;
    }
    usize parameter = c_call_parameter(context, instruction, index);
    usize value = d_operand_value(context, instruction, index);
    if parameter < context.symbols.length {
        usize expected_type = read_record_field(
            context.symbol_data, parameter, 4
        );
        usize actual_type = c_value_type(value_types, value);
        if actual_type < context.types.length &&
            expected_type < context.types.length &&
            read_record_field(context.type_data, actual_type, 0) == 10 &&
            read_record_field(context.type_data, expected_type, 0) == 11 {
            d_put(buffer, "(");
            c_put_type(context, buffer, expected_type);
            d_put(buffer, "){v");
            d_put_usize(buffer, value);
            d_put(buffer, ".data, ");
            d_put_usize(
                buffer,
                read_record_field(context.type_data, actual_type, 2)
            );
            d_put(buffer, "}");
            return;
        }
    }
    if parameter < context.symbols.length {
        usize mode = read_record_field(context.detail_data, parameter, 3);
        usize type_id = read_record_field(context.symbol_data, parameter, 4);
        if (mode == 1 || d_parameter_owned(context, parameter)) &&
            !c_type_is_reference(context, type_id) {
            d_put(buffer, "&");
        }
    } else if c_call_builtin_out(context, instruction, index) {
        d_put(buffer, "&");
    }
    d_put(buffer, "v");
    d_put_usize(buffer, d_operand_value(context, instruction, index));
}

unsafe void c_emit_checked_binary(
    ref IrContext context,
    ref DBuffer buffer,
    usize instruction,
    usize type_id,
    text operation
) {
    d_put(buffer, "oc_checked_"); d_put(buffer, operation);
    d_put(buffer, "_"); c_put_checked_suffix(context, buffer, type_id);
    d_put(buffer, "(v");
    d_put_usize(buffer, d_operand_value(context, instruction, 0));
    d_put(buffer, ", v");
    d_put_usize(buffer, d_operand_value(context, instruction, 1));
    d_put(buffer, ", 0)");
}

unsafe void c_emit_instruction(
    ref IrContext context,
    ref DBuffer buffer,
    usize instruction,
    ptr byte value_types,
    ptr byte reference_storage,
    ptr byte instruction_order,
    ref DScopeState next_scope_guard,
    usize guard_count
) {
    usize opcode = read_record_field(
        context.instruction_data, instruction, 2
    );
    usize result = read_record_field(
        context.instruction_data, instruction, 1
    );
    usize type_id = read_record_field(
        context.instruction_data, instruction, 3
    );
    bool produces = result != 0 && type_id < context.types.length &&
        read_record_field(context.type_data, type_id, 0) != 1;

    if opcode == ir_op_nop() {
        if produces {
            c_put_lhs(buffer, result);
            d_put(buffer, "("); c_put_type(context, buffer, type_id);
            d_put(buffer, "){0};\n");
        }
        return;
    }
    if opcode == ir_op_const_integer() {
        c_put_lhs(buffer, result);
        d_put(buffer, "("); c_put_type(context, buffer, type_id);
        d_put(buffer, ")(");
        d_put_instruction_text(context, buffer, instruction);
        d_put(buffer, ");\n");
        return;
    }
    if opcode == ir_op_const_float() || opcode == ir_op_const_bool() {
        c_put_lhs(buffer, result);
        d_put_instruction_text(context, buffer, instruction);
        d_put(buffer, ";\n");
        return;
    }
    if opcode == ir_op_const_text() {
        c_put_lhs(buffer, result);
        d_put(buffer, "OC_TEXT_LITERAL(");
        d_put_instruction_text(context, buffer, instruction);
        d_put(buffer, ");\n");
        return;
    }
    if opcode == ir_op_local_alloc() {
        usize parameter = c_local_parameter(context, instruction);
        if parameter < context.symbols.length {
            c_put_lhs(buffer, result);
            usize parameter_type = read_record_field(
                context.symbol_data, parameter, 4
            );
            if d_parameter_owned(context, parameter) &&
                !c_type_is_reference(context, parameter_type) {
                d_put(buffer, "*");
            }
            d_put_symbol_name(context, buffer, parameter);
            d_put(buffer, ";\n");
        }
        return;
    }
    if opcode == ir_op_load() {
        c_put_lhs(buffer, result);
        usize source = d_operand_value(context, instruction, 0);
        usize source_type = c_value_type(value_types, source);
        bool source_reference = c_type_is_reference(context, source_type);
        bool result_reference = c_type_is_reference(context, type_id);
        if source_reference && !result_reference { d_put(buffer, "*"); }
        d_put(buffer, "v"); d_put_usize(buffer, source);
        d_put(buffer, ";\n");
        return;
    }
    if opcode == ir_op_store() {
        d_put(buffer, "    ");
        usize destination = d_operand_value(context, instruction, 0);
        usize destination_type = c_value_type(value_types, destination);
        bool reference = c_type_is_reference(context, destination_type);
        bool bind = d_operand_immediate_is(
            context, instruction, 0, "bind"
        );
        bool deref = d_operand_immediate_is(
            context, instruction, 0, "deref"
        );
        if (reference && !bind) || deref { d_put(buffer, "*"); }
        d_put(buffer, "v"); d_put_usize(buffer, destination);
        d_put(buffer, " = v");
        d_put_usize(buffer, d_operand_value(context, instruction, 1));
        d_put(buffer, ";\n");
        return;
    }
    if opcode == ir_op_unary() {
        c_put_lhs(buffer, result);
        if d_instruction_text_is(context, instruction, "-") &&
            c_type_is_integer(context, type_id) {
            d_put(buffer, "oc_checked_sub_");
            c_put_checked_suffix(context, buffer, type_id);
            d_put(buffer, "(0, v");
            d_put_usize(buffer, d_operand_value(context, instruction, 0));
            d_put(buffer, ", 0)");
        } else {
            d_put_instruction_text(context, buffer, instruction);
            d_put(buffer, "v");
            d_put_usize(buffer, d_operand_value(context, instruction, 0));
        }
        d_put(buffer, ";\n");
        return;
    }
    if opcode == ir_op_address() {
        c_put_lhs(buffer, result);
        d_put(buffer, "&v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ";\n");
        return;
    }
    if opcode == ir_op_binary() {
        c_put_lhs(buffer, result);
        bool helper = c_type_is_integer(context, type_id);
        if helper && d_instruction_text_is(context, instruction, "+") {
            c_emit_checked_binary(context, buffer, instruction, type_id, "add");
        } else if helper && d_instruction_text_is(context, instruction, "-") {
            c_emit_checked_binary(context, buffer, instruction, type_id, "sub");
        } else if helper && d_instruction_text_is(context, instruction, "*") {
            c_emit_checked_binary(context, buffer, instruction, type_id, "mul");
        } else if helper && d_instruction_text_is(context, instruction, "/") {
            c_emit_checked_binary(context, buffer, instruction, type_id, "div");
        } else if helper && d_instruction_text_is(context, instruction, "%") {
            c_emit_checked_binary(context, buffer, instruction, type_id, "rem");
        } else if helper && d_instruction_text_is(context, instruction, "<<") {
            c_emit_checked_binary(context, buffer, instruction, type_id, "shl");
        } else if helper && d_instruction_text_is(context, instruction, ">>") {
            c_emit_checked_binary(context, buffer, instruction, type_id, "shr");
        } else {
            d_put(buffer, "v");
            d_put_usize(buffer, d_operand_value(context, instruction, 0));
            d_put(buffer, " ");
            d_put_instruction_text(context, buffer, instruction);
            d_put(buffer, " v");
            d_put_usize(buffer, d_operand_value(context, instruction, 1));
        }
        d_put(buffer, ";\n");
        return;
    }
    if opcode == ir_op_short_begin() {
        usize left = d_operand_value(context, instruction, 0);
        c_put_lhs(buffer, result);
        d_put(buffer, "v"); d_put_usize(buffer, left);
        d_put(buffer, ";\n    if (");
        if !d_instruction_text_is(context, instruction, "&&") {
            d_put(buffer, "!");
        }
        d_put(buffer, "v"); d_put_usize(buffer, left);
        d_put(buffer, ") {\n");
        return;
    }
    if opcode == ir_op_short_end() {
        d_put(buffer, "        v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, " = v");
        d_put_usize(buffer, d_operand_value(context, instruction, 1));
        d_put(buffer, ";\n    }\n");
        return;
    }
    if opcode == ir_op_compare() {
        c_put_lhs(buffer, result);
        usize left = d_operand_value(context, instruction, 0);
        usize left_type = c_value_type(value_types, left);
        if c_type_is_text(context, left_type) && (
            d_instruction_text_is(context, instruction, "==") ||
            d_instruction_text_is(context, instruction, "!=")
        ) {
            if d_instruction_text_is(context, instruction, "!=") {
                d_put(buffer, "!");
            }
            d_put(buffer, "ocb_text_equal(v"); d_put_usize(buffer, left);
            d_put(buffer, ", v");
            d_put_usize(buffer, d_operand_value(context, instruction, 1));
            d_put(buffer, ")");
        } else {
            d_put(buffer, "v"); d_put_usize(buffer, left);
            d_put(buffer, " ");
            d_put_instruction_text(context, buffer, instruction);
            d_put(buffer, " v");
            d_put_usize(buffer, d_operand_value(context, instruction, 1));
        }
        d_put(buffer, ";\n");
        return;
    }
    if opcode == ir_op_cast() {
        c_put_lhs(buffer, result);
        usize operand = d_operand_value(context, instruction, 0);
        usize operand_type = c_value_type(value_types, operand);
        if operand_type == type_id {
            d_put(buffer, "v");
            d_put_usize(buffer, operand);
        } else if c_type_is_integer(context, type_id) {
            d_put(buffer, "oc_checked_cast_");
            c_put_checked_suffix(context, buffer, type_id);
            d_put(buffer, "((long double)v");
            d_put_usize(buffer, operand);
            d_put(buffer, ", 0)");
        } else {
            d_put(buffer, "("); c_put_type(context, buffer, type_id);
            d_put(buffer, ")v");
            d_put_usize(buffer, operand);
        }
        d_put(buffer, ";\n");
        return;
    }
    if opcode == ir_op_reinterpret() {
        c_put_lhs(buffer, result);
        d_put(buffer, "("); c_put_type(context, buffer, type_id);
        d_put(buffer, ")v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ";\n");
        return;
    }
    if opcode == ir_op_call() {
        if produces { c_put_lhs(buffer, result); }
        else { d_put(buffer, "    "); }
        c_put_call_name(context, buffer, instruction, value_types);
        d_put(buffer, "(");
        usize count = d_operand_count(context, instruction);
        usize index = 0;
        while index < count {
            if index != 0 { d_put(buffer, ", "); }
            c_put_call_argument(
                context, buffer, instruction, index, value_types
            );
            index = index + 1;
        }
        d_put(buffer, ");\n");
        return;
    }
    if opcode == ir_op_branch() {
        d_put(buffer, "    goto block_");
        d_put_operand_immediate(context, buffer, instruction, 0);
        d_put(buffer, ";\n");
        return;
    }
    if opcode == ir_op_branch_conditional() {
        d_put(buffer, "    if (v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ") goto block_");
        d_put_operand_immediate(context, buffer, instruction, 1);
        d_put(buffer, "; else goto block_");
        d_put_operand_immediate(context, buffer, instruction, 2);
        d_put(buffer, ";\n");
        return;
    }
    if opcode == ir_op_return() {
        c_emit_cleanup_guards(
            context, buffer, instruction_order,
            reference_storage, value_types, guard_count
        );
        d_put(buffer, "    return v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ";\n");
        return;
    }
    if opcode == ir_op_return_void() {
        c_emit_cleanup_guards(
            context, buffer, instruction_order,
            reference_storage, value_types, guard_count
        );
        d_put(buffer, "    return;\n");
        return;
    }
    if opcode == ir_op_scope_register() {
        d_put(buffer, "    scope_active_");
        d_put_usize(buffer, next_scope_guard.next);
        d_put(buffer, " = true;\n");
        next_scope_guard.next = next_scope_guard.next + 1;
        return;
    }
    if opcode == ir_op_status_create() {
        usize code_value = 0;
        usize message_value = 0;
        usize index = 0;
        while index < d_operand_count(context, instruction) {
            if d_operand_immediate_is(context, instruction, index, "code") {
                code_value = d_operand_value(context, instruction, index);
            } else if d_operand_immediate_is(
                context, instruction, index, "message"
            ) { message_value = d_operand_value(context, instruction, index); }
            index = index + 1;
        }
        c_put_lhs(buffer, result);
        d_put(buffer, "(oc_status){");
        if code_value == 0 { d_put(buffer, "0"); }
        else { d_put(buffer, "v"); d_put_usize(buffer, code_value); }
        d_put(buffer, ", ");
        if message_value == 0 { d_put(buffer, "OC_TEXT_EMPTY"); }
        else { d_put(buffer, "v"); d_put_usize(buffer, message_value); }
        d_put(buffer, "};\n");
        return;
    }
    if opcode == ir_op_aggregate_create() {
        d_put(buffer, "    v"); d_put_usize(buffer, result);
        d_put(buffer, " = ("); c_put_type(context, buffer, type_id);
        d_put(buffer, "){0};\n");
        usize index = 0;
        while index < d_operand_count(context, instruction) {
            d_put(buffer, "    v"); d_put_usize(buffer, result);
            d_put(buffer, ".");
            d_put_operand_immediate(context, buffer, instruction, index);
            d_put(buffer, " = v");
            d_put_usize(buffer, d_operand_value(context, instruction, index));
            d_put(buffer, ";\n");
            index = index + 1;
        }
        return;
    }
    if opcode == ir_op_array_create() {
        d_put(buffer, "    v"); d_put_usize(buffer, result);
        d_put(buffer, " = ("); c_put_type(context, buffer, type_id);
        d_put(buffer, "){0};\n");
        usize index = 0;
        while index < d_operand_count(context, instruction) {
            d_put(buffer, "    v"); d_put_usize(buffer, result);
            d_put(buffer, ".data["); d_put_usize(buffer, index);
            d_put(buffer, "] = v");
            d_put_usize(buffer, d_operand_value(context, instruction, index));
            d_put(buffer, ";\n");
            index = index + 1;
        }
        return;
    }
    if opcode == ir_op_aggregate_field() {
        usize base = d_operand_value(context, instruction, 0);
        usize base_type = c_value_type(value_types, base);
        usize base_kind = read_record_field(
            context.type_data, base_type, 0
        );
        if base_kind == 14 &&
            d_instruction_text_is(context, instruction, "value") {
            d_put(buffer, "    if (!v");
            d_put_usize(buffer, base);
            d_put(buffer, ".present) { ");
            d_put(buffer, "ocb_checked_failure(OC_TEXT_LITERAL(");
            d_put(buffer, "\"optional has no value\")); }\n");
        }
        c_put_lhs(buffer, result);
        if d_instruction_address_field(context, instruction) { d_put(buffer, "&"); }
        if base_type == semantic_type_status() &&
            d_instruction_text_is(context, instruction, "ok") {
            d_put(buffer, "(v"); d_put_usize(buffer, base);
            d_put(buffer, ".code == 0)");
        } else if base_kind == 10 &&
            d_instruction_text_is(context, instruction, "length") {
            d_put_usize(
                buffer,
                read_record_field(context.type_data, base_type, 2)
            );
        } else if d_instruction_text_is(context, instruction, "index") ||
            (read_record_field(context.instruction_detail, instruction, 0) == 2 &&
             read_record_field(context.instruction_detail, instruction, 1) == 4) {
            d_put(buffer, "v"); d_put_usize(buffer, base);
            if c_type_is_pointer_like(context, base_type) { d_put(buffer, "->"); }
            else { d_put(buffer, "."); }
            d_put(buffer, "data[v");
            d_put_usize(buffer, d_operand_value(context, instruction, 1));
            d_put(buffer, "]");
        } else {
            d_put(buffer, "v"); d_put_usize(buffer, base);
            if c_type_is_pointer_like(context, base_type) { d_put(buffer, "->"); }
            else { d_put(buffer, "."); }
            if d_instruction_text_is(context, instruction, "present") {
                d_put(buffer, "present");
            } else {
                usize kind = read_record_field(
                    context.instruction_detail, instruction, 0
                );
                if kind == 5 {
                    d_put_slice(
                        buffer, context.source,
                        read_record_field(context.instruction_detail, instruction, 1),
                        read_record_field(context.instruction_detail, instruction, 2)
                    );
                } else { d_put_instruction_text(context, buffer, instruction); }
            }
        }
        d_put(buffer, ";\n");
        return;
    }
    if opcode == ir_op_optional_none() {
        c_put_lhs(buffer, result);
        d_put(buffer, "("); c_put_type(context, buffer, type_id);
        d_put(buffer, "){0};\n");
        return;
    }
    if opcode == ir_op_optional_some() {
        c_put_lhs(buffer, result);
        d_put(buffer, "("); c_put_type(context, buffer, type_id);
        d_put(buffer, "){true, v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, "};\n");
        return;
    }
    if opcode == ir_op_slice_create() {
        usize base = d_operand_value(context, instruction, 0);
        usize lower = d_operand_value(context, instruction, 1);
        usize upper = d_operand_value(context, instruction, 2);
        c_put_lhs(buffer, result);
        if c_type_is_text(context, c_value_type(value_types, base)) {
            d_put(buffer, "oc_text_slice(v"); d_put_usize(buffer, base);
            d_put(buffer, ", v"); d_put_usize(buffer, lower);
            d_put(buffer, ", v"); d_put_usize(buffer, upper);
            d_put(buffer, ", 0)");
        } else {
            d_put(buffer, "("); c_put_type(context, buffer, type_id);
            d_put(buffer, "){&v"); d_put_usize(buffer, base);
            d_put(buffer, ".data[v"); d_put_usize(buffer, lower);
            d_put(buffer, "], oc_range_length(v"); d_put_usize(buffer, lower);
            d_put(buffer, ", v"); d_put_usize(buffer, upper);
            d_put(buffer, ", v"); d_put_usize(buffer, base);
            d_put(buffer, ".length, 0)}");
        }
        d_put(buffer, ";\n");
        return;
    }
    if opcode == ir_op_object_construct() {
        c_put_lhs(buffer, result);
        d_put(buffer, "("); c_put_type(context, buffer, type_id);
        d_put(buffer, ")&v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ".bytes[0];\n    *v"); d_put_usize(buffer, result);
        d_put(buffer, " = v");
        d_put_usize(buffer, d_operand_value(context, instruction, 1));
        d_put(buffer, ";\n");
        return;
    }
    if opcode == ir_op_object_destroy() { return; }
    if opcode == ir_op_bounds() {
        usize aggregate = d_operand_value(context, instruction, 0);
        usize index = d_operand_value(context, instruction, 1);
        usize aggregate_type = c_value_type(value_types, aggregate);
        bool fixed_array = aggregate_type < context.types.length &&
            read_record_field(context.type_data, aggregate_type, 0) == 10;
        if guard_count != 0 {
            d_put(buffer, "    if (v");
            d_put_usize(buffer, index);
            d_put(buffer, " >= ");
            if fixed_array {
                d_put_usize(
                    buffer,
                    read_record_field(context.type_data, aggregate_type, 2)
                );
            } else {
                d_put(buffer, "v");
                d_put_usize(buffer, aggregate);
                d_put(buffer, ".length");
            }
            d_put(buffer, ") {\n");
            c_emit_cleanup_guards(
                context, buffer, instruction_order,
                reference_storage, value_types, guard_count
            );
            d_put(buffer, "    }\n");
        }
        d_put(buffer, "    (void)oc_bounds_index(v");
        d_put_usize(buffer, index); d_put(buffer, ", ");
        if fixed_array {
            d_put_usize(
                buffer,
                read_record_field(context.type_data, aggregate_type, 2)
            );
        } else {
            d_put(buffer, "v");
            d_put_usize(buffer, aggregate);
            d_put(buffer, ".length");
        }
        d_put(buffer, ", 0);\n");
        return;
    }
    if opcode == ir_op_target_fault() {
        d_put(buffer, "    ocb_target_fault(OC_TEXT_LITERAL(\"");
        d_put_instruction_text(context, buffer, instruction);
        d_put(buffer, "\"));\n");
        return;
    }
    d_put(buffer, "    /* unsupported IR: ");
    d_put(buffer, ir_opcode_text(opcode));
    d_put(buffer, " */\n");
}
