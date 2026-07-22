import system.file;
import system.memory;
import system.path;
import system.text;

unsafe void d_emit_instruction(
    ref IrContext context,
    ref DBuffer buffer,
    usize instruction,
    ptr byte value_types,
    ptr byte reference_storage,
    ref DScopeState next_scope_guard
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
        if d_instruction_text_is(context, instruction, "null") {
            d_put_lhs(buffer, result);
            d_put(buffer, "cast("); d_put_type(context, buffer, type_id);
            d_put(buffer, ") null;\n");
        } else if produces {
            d_put_lhs(buffer, result);
            d_put_type(context, buffer, type_id); d_put(buffer, ".init;\n");
        }
        return;
    }
    if opcode == ir_op_const_integer() {
        d_put_lhs(buffer, result);
        d_put(buffer, "cast("); d_put_type(context, buffer, type_id);
        d_put(buffer, ") ("); d_put_instruction_text(context, buffer, instruction);
        d_put(buffer, ");\n"); return;
    }
    if opcode == ir_op_const_float() || opcode == ir_op_const_bool() ||
        opcode == ir_op_const_text() {
        d_put_lhs(buffer, result);
        d_put_instruction_text(context, buffer, instruction);
        d_put(buffer, ";\n"); return;
    }
    if opcode == ir_op_local_alloc() {
        if d_local_is_parameter(context, instruction) {
            d_put_lhs(buffer, result);
            if type_id < context.types.length && read_record_field(
                context.type_data, type_id, 0
            ) == 12 { d_put(buffer, "&"); }
            d_put_instruction_text(context, buffer, instruction);
            d_put(buffer, ";\n");
        }
        d_put(buffer, "    // local ");
        d_put_instruction_text(context, buffer, instruction);
        d_put(buffer, "\n"); return;
    }
    if opcode == ir_op_load() {
        d_put_lhs(buffer, result);
        usize source = d_operand_value(context, instruction, 0);
        usize source_type = read_usize(value_types, source * size_of(usize));
        bool source_reference = source_type < context.types.length &&
            read_record_field(context.type_data, source_type, 0) == 12;
        bool result_reference = type_id < context.types.length &&
            read_record_field(context.type_data, type_id, 0) == 12;
        if source_reference && !result_reference { d_put(buffer, "*"); }
        d_put(buffer, "v"); d_put_usize(buffer, source);
        d_put(buffer, ";\n"); return;
    }
    if opcode == ir_op_store() {
        d_put(buffer, "    ");
        usize destination = d_operand_value(context, instruction, 0);
        usize destination_type = read_usize(
            value_types, destination * size_of(usize)
        );
        bool reference = destination_type < context.types.length &&
            read_record_field(context.type_data, destination_type, 0) == 12;
        bool bind = d_operand_immediate_is(
            context, instruction, 0, "bind"
        );
        bool deref = d_operand_immediate_is(
            context, instruction, 0, "deref"
        );
        if (reference && !bind) || deref { d_put(buffer, "*"); }
        d_put(buffer, "v"); d_put_usize(buffer, destination);
        d_put(buffer, " = cast(typeof(");
        if (reference && !bind) || deref { d_put(buffer, "*"); }
        d_put(buffer, "v"); d_put_usize(buffer, destination);
        d_put(buffer, ")) v");
        d_put_usize(buffer, d_operand_value(context, instruction, 1));
        d_put(buffer, ";\n"); return;
    }
    if opcode == ir_op_unary() {
        d_put_lhs(buffer, result);
        if d_instruction_text_is(context, instruction, "-") &&
            d_type_is_integer(context, type_id) {
            d_put(buffer, "checkedSub(cast(");
            d_put_type(context, buffer, type_id);
            d_put(buffer, ") 0, v");
            d_put_usize(buffer, d_operand_value(context, instruction, 0));
            d_put(buffer, ");\n");
        } else {
            d_put_instruction_text(context, buffer, instruction);
            d_put(buffer, "v");
            d_put_usize(buffer, d_operand_value(context, instruction, 0));
            d_put(buffer, ";\n");
        }
        return;
    }
    if opcode == ir_op_address() {
        d_put_lhs(buffer, result);
        d_put(buffer, "&v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ";\n"); return;
    }
    if opcode == ir_op_binary() {
        d_put_lhs(buffer, result);
        bool helper = false;
        if d_type_is_integer(context, type_id) {
            if d_instruction_text_is(context, instruction, "+") {
                d_put(buffer, "checkedAdd"); helper = true;
            } else if d_instruction_text_is(context, instruction, "-") {
                d_put(buffer, "checkedSub"); helper = true;
            } else if d_instruction_text_is(context, instruction, "*") {
                d_put(buffer, "checkedMul"); helper = true;
            } else if d_instruction_text_is(context, instruction, "/") {
                d_put(buffer, "checkedDiv"); helper = true;
            } else if d_instruction_text_is(context, instruction, "%") {
                d_put(buffer, "checkedRem"); helper = true;
            } else if d_instruction_text_is(context, instruction, "<<") {
                d_put(buffer, "checkedShiftLeft"); helper = true;
            } else if d_instruction_text_is(context, instruction, ">>") {
                d_put(buffer, "checkedShiftRight"); helper = true;
            }
        }
        if helper {
            d_put(buffer, "(v");
            d_put_usize(buffer, d_operand_value(context, instruction, 0));
            d_put(buffer, ", v");
            d_put_usize(buffer, d_operand_value(context, instruction, 1));
            d_put(buffer, ");\n");
        } else {
            d_put(buffer, "v");
            d_put_usize(buffer, d_operand_value(context, instruction, 0));
            d_put(buffer, " "); d_put_instruction_text(context, buffer, instruction);
            d_put(buffer, " v");
            d_put_usize(buffer, d_operand_value(context, instruction, 1));
            d_put(buffer, ";\n");
        }
        return;
    }
    if opcode == ir_op_short_begin() {
        usize left = d_operand_value(context, instruction, 0);
        d_put_lhs(buffer, result);
        d_put(buffer, "v"); d_put_usize(buffer, left); d_put(buffer, ";\n");
        d_put(buffer, "    if (");
        if !d_instruction_text_is(context, instruction, "&&") {
            d_put(buffer, "!");
        }
        d_put(buffer, "v"); d_put_usize(buffer, left);
        d_put(buffer, ") {\n"); return;
    }
    if opcode == ir_op_short_end() {
        d_put(buffer, "        v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, " = v");
        d_put_usize(buffer, d_operand_value(context, instruction, 1));
        d_put(buffer, ";\n    }\n"); return;
    }
    if opcode == ir_op_compare() {
        d_put_lhs(buffer, result);
        d_put(buffer, "v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, " "); d_put_instruction_text(context, buffer, instruction);
        d_put(buffer, " v");
        d_put_usize(buffer, d_operand_value(context, instruction, 1));
        d_put(buffer, ";\n"); return;
    }
    if opcode == ir_op_cast() {
        d_put_lhs(buffer, result);
        d_put(buffer, "checkedCast!("); d_put_type(context, buffer, type_id);
        d_put(buffer, ")(v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ");\n"); return;
    }
    if opcode == ir_op_reinterpret() {
        d_put_lhs(buffer, result);
        d_put(buffer, "cast("); d_put_type(context, buffer, type_id);
        d_put(buffer, ") v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ";\n"); return;
    }
    if opcode == ir_op_call() {
        if produces { d_put_lhs(buffer, result); }
        else { d_put(buffer, "    "); }
        if d_instruction_text_is(context, instruction, "system.memory.alloc") ||
            d_instruction_text_is(context, instruction, "memory.alloc") {
            d_put(buffer, "cast("); d_put_type(context, buffer, type_id);
            d_put(buffer, ") ");
        }
        d_put_call_name(context, buffer, instruction);
        d_put(buffer, "(");
        usize count = d_operand_count(context, instruction);
        usize index = 0;
        while index < count {
            if index != 0 { d_put(buffer, ", "); }
            usize parameter_type = d_call_parameter_type(
                context, instruction, index
            );
            if parameter_type < context.types.length && read_record_field(
                context.type_data, parameter_type, 0
            ) == 12 { d_put(buffer, "*"); }
            d_put(buffer, "v");
            d_put_usize(buffer, d_operand_value(context, instruction, index));
            index = index + 1;
        }
        d_put(buffer, ");\n"); return;
    }
    if opcode == ir_op_branch() {
        d_put(buffer, "    ");
        d_put(buffer, "goto block_");
        d_put_operand_immediate(context, buffer, instruction, 0);
        d_put(buffer, ";\n"); return;
    }
    if opcode == ir_op_branch_conditional() {
        d_put(buffer, "    ");
        d_put(buffer, "if (v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ") goto block_");
        d_put_operand_immediate(context, buffer, instruction, 1);
        d_put(buffer, "; else goto block_");
        d_put_operand_immediate(context, buffer, instruction, 2);
        d_put(buffer, ";\n"); return;
    }
    if opcode == ir_op_return() {
        d_put(buffer, "    ");
        d_put(buffer, "return cast(");
        d_put_type(context, buffer, context.function_result);
        d_put(buffer, ") v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ";\n"); return;
    }
    if opcode == ir_op_return_void() {
        d_put(buffer, "    return;\n"); return;
    }
    if opcode == ir_op_scope_register() {
        d_put(buffer, "    scope_active_");
        d_put_usize(buffer, next_scope_guard.next);
        d_put(buffer, " = true;\n");
        next_scope_guard.next = next_scope_guard.next + 1;
        return;
    }
    if opcode == ir_op_object_construct() {
        d_put_lhs(buffer, result);
        d_put(buffer, "&v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ".construct(v");
        d_put_usize(buffer, d_operand_value(context, instruction, 1));
        d_put(buffer, ");\n"); return;
    }
    if opcode == ir_op_object_destroy() {
        d_put(buffer, "    ");
        usize source = d_operand_value(context, instruction, 0);
        usize storage_value = read_usize(
            reference_storage, source * size_of(usize)
        );
        if storage_value != 0 {
            d_put(buffer, "v"); d_put_usize(buffer, storage_value - 1);
            d_put(buffer, ".destroyValue();\n");
        } else {
            d_put(buffer, "destroy(v"); d_put_usize(buffer, source);
            d_put(buffer, ");\n");
        }
        return;
    }
    if opcode == ir_op_status_create() {
        d_put_lhs(buffer, result);
        d_put(buffer, "Status(");
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
        if code_value == 0 { d_put(buffer, "0"); }
        else { d_put(buffer, "v"); d_put_usize(buffer, code_value); }
        d_put(buffer, ", ");
        if message_value == 0 { d_put(buffer, "\"\""); }
        else { d_put(buffer, "v"); d_put_usize(buffer, message_value); }
        d_put(buffer, ");\n"); return;
    }
    if opcode == ir_op_aggregate_create() {
        usize index = 0;
        while index < d_operand_count(context, instruction) {
            d_put(buffer, "    v"); d_put_usize(buffer, result);
            d_put(buffer, ".");
            d_put_operand_immediate(context, buffer, instruction, index);
            d_put(buffer, " = cast(typeof(v"); d_put_usize(buffer, result);
            d_put(buffer, ".");
            d_put_operand_immediate(context, buffer, instruction, index);
            d_put(buffer, ")) v");
            d_put_usize(buffer, d_operand_value(context, instruction, index));
            d_put(buffer, ";\n");
            index = index + 1;
        }
        return;
    }
    if opcode == ir_op_array_create() {
        d_put_lhs(buffer, result);
        d_put(buffer, "[");
        usize index = 0;
        while index < d_operand_count(context, instruction) {
            if index != 0 { d_put(buffer, ", "); }
            d_put(buffer, "v");
            d_put_usize(buffer, d_operand_value(context, instruction, index));
            index = index + 1;
        }
        d_put(buffer, "];\n"); return;
    }
    if opcode == ir_op_aggregate_field() {
        bool address = d_instruction_address_field(context, instruction);
        d_put_lhs(buffer, result);
        if address {
            // Replace the already-emitted assignment prefix with the address
            // marker used by the stage-0 backend.
            d_put(buffer, "&");
        }
        d_put(buffer, "v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        if d_instruction_text_is(context, instruction, "index") ||
            (read_record_field(context.instruction_detail, instruction, 0) == 2 &&
             read_record_field(context.instruction_detail, instruction, 1) == 4) {
            d_put(buffer, "[v");
            d_put_usize(buffer, d_operand_value(context, instruction, 1));
            d_put(buffer, "]");
        } else {
            d_put(buffer, ".");
            if d_instruction_text_is(context, instruction, "present") {
                d_put(buffer, "hasValue");
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
        d_put(buffer, ";\n"); return;
    }
    if opcode == ir_op_optional_none() {
        d_put_lhs(buffer, result);
        d_put_type(context, buffer, type_id);
        d_put(buffer, ".none();\n"); return;
    }
    if opcode == ir_op_optional_some() {
        d_put_lhs(buffer, result);
        d_put_type(context, buffer, type_id);
        d_put(buffer, ".some(v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ");\n"); return;
    }
    if opcode == ir_op_bounds() {
        d_put(buffer, "    ");
        d_put(buffer, "if (v");
        d_put_usize(buffer, d_operand_value(context, instruction, 1));
        d_put(buffer, " >= v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ".length) openc.runtime.checked.opencCheckedFailure(\"index out of bounds\");\n");
        return;
    }
    if opcode == ir_op_target_fault() {
        d_put(buffer, "    ");
        d_put(buffer, "opencTargetFault(\"");
        d_put_instruction_text(context, buffer, instruction);
        d_put(buffer, "\");\n"); return;
    }
    d_put(buffer, "    // "); d_put(buffer, ir_opcode_text(opcode));
    d_put(buffer, " "); d_put_instruction_text(context, buffer, instruction);
    d_put(buffer, "\n");
}
