import system.file;
import system.memory;
import system.path;
import system.text;


unsafe bool backend_instruction_aggregate(
    ref IrContext context, ref DBuffer buffer, usize instruction,
    ptr byte value_types, ptr byte reference_storage,
    ref DScopeState next_scope_guard, usize opcode, usize result,
    usize type_id, bool produces
) {
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
        d_put(buffer, ");\n"); return true;
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
        return true;
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
        d_put(buffer, "];\n"); return true;
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
        d_put(buffer, ";\n"); return true;
    }
    if opcode == ir_op_optional_none() {
        d_put_lhs(buffer, result);
        d_put_type(context, buffer, type_id);
        d_put(buffer, ".none();\n"); return true;
    }
    if opcode == ir_op_optional_some() {
        d_put_lhs(buffer, result);
        d_put_type(context, buffer, type_id);
        d_put(buffer, ".some(v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ");\n"); return true;
    }
    if opcode == ir_op_bounds() {
        d_put(buffer, "    ");
        d_put(buffer, "if (v");
        d_put_usize(buffer, d_operand_value(context, instruction, 1));
        d_put(buffer, " >= v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ".length) openc.runtime.checked.opencCheckedFailure(\"index out of bounds\");\n");
        return true;
    }
    if opcode == ir_op_target_fault() {
        d_put(buffer, "    ");
        d_put(buffer, "opencTargetFault(\"");
        d_put_instruction_text(context, buffer, instruction);
        d_put(buffer, "\");\n"); return true;
    }
    return false;
}
