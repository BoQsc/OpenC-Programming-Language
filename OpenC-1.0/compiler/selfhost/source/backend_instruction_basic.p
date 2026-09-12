import system.file;
import system.memory;
import system.path;
import system.text;


unsafe bool backend_instruction_basic(
    ref IrContext context, ref DBuffer buffer, usize instruction,
    ptr byte value_types, ptr byte reference_storage,
    ref DScopeState next_scope_guard, usize opcode, usize result,
    usize type_id, bool produces
) {
    if opcode == ir_op_nop() {
        if d_instruction_text_is(context, instruction, "null") {
            d_put_lhs(buffer, result);
            d_put(buffer, "cast("); d_put_type(context, buffer, type_id);
            d_put(buffer, ") null;\n");
        } else if produces {
            d_put_lhs(buffer, result);
            d_put_type(context, buffer, type_id); d_put(buffer, ".init;\n");
        }
        return true;
    }
    if opcode == ir_op_const_integer() {
        d_put_lhs(buffer, result);
        d_put(buffer, "cast("); d_put_type(context, buffer, type_id);
        d_put(buffer, ") ("); d_put_instruction_text(context, buffer, instruction);
        d_put(buffer, ");\n"); return true;
    }
    if opcode == ir_op_const_float() || opcode == ir_op_const_bool() ||
        opcode == ir_op_const_text() {
        d_put_lhs(buffer, result);
        d_put_instruction_text(context, buffer, instruction);
        d_put(buffer, ";\n"); return true;
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
        d_put(buffer, "\n"); return true;
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
        d_put(buffer, ";\n"); return true;
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
        d_put(buffer, ";\n"); return true;
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
        return true;
    }
    if opcode == ir_op_address() {
        d_put_lhs(buffer, result);
        d_put(buffer, "&v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ";\n"); return true;
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
        return true;
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
        d_put(buffer, ") {\n"); return true;
    }
    if opcode == ir_op_short_end() {
        d_put(buffer, "        v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, " = v");
        d_put_usize(buffer, d_operand_value(context, instruction, 1));
        d_put(buffer, ";\n    }\n"); return true;
    }
    if opcode == ir_op_compare() {
        d_put_lhs(buffer, result);
        d_put(buffer, "v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, " "); d_put_instruction_text(context, buffer, instruction);
        d_put(buffer, " v");
        d_put_usize(buffer, d_operand_value(context, instruction, 1));
        d_put(buffer, ";\n"); return true;
    }
    if opcode == ir_op_cast() {
        d_put_lhs(buffer, result);
        d_put(buffer, "checkedCast!("); d_put_type(context, buffer, type_id);
        d_put(buffer, ")(v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ");\n"); return true;
    }
    if opcode == ir_op_reinterpret() {
        d_put_lhs(buffer, result);
        d_put(buffer, "cast("); d_put_type(context, buffer, type_id);
        d_put(buffer, ") v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ";\n"); return true;
    }
    return false;
}
