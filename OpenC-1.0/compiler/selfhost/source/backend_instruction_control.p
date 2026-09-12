import system.file;
import system.memory;
import system.path;
import system.text;


unsafe bool backend_instruction_control(
    ref IrContext context, ref DBuffer buffer, usize instruction,
    ptr byte value_types, ptr byte reference_storage,
    ref DScopeState next_scope_guard, usize opcode, usize result,
    usize type_id, bool produces
) {
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
        d_put(buffer, ");\n"); return true;
    }
    if opcode == ir_op_branch() {
        d_put(buffer, "    ");
        d_put(buffer, "goto block_");
        d_put_operand_immediate(context, buffer, instruction, 0);
        d_put(buffer, ";\n"); return true;
    }
    if opcode == ir_op_branch_conditional() {
        d_put(buffer, "    ");
        d_put(buffer, "if (v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ") goto block_");
        d_put_operand_immediate(context, buffer, instruction, 1);
        d_put(buffer, "; else goto block_");
        d_put_operand_immediate(context, buffer, instruction, 2);
        d_put(buffer, ";\n"); return true;
    }
    if opcode == ir_op_return() {
        d_put(buffer, "    ");
        d_put(buffer, "return cast(");
        d_put_type(context, buffer, context.function_result);
        d_put(buffer, ") v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ";\n"); return true;
    }
    if opcode == ir_op_return_void() {
        d_put(buffer, "    return;\n"); return true;
    }
    if opcode == ir_op_scope_register() {
        d_put(buffer, "    scope_active_");
        d_put_usize(buffer, next_scope_guard.next);
        d_put(buffer, " = true;\n");
        next_scope_guard.next = next_scope_guard.next + 1;
        return true;
    }
    if opcode == ir_op_object_construct() {
        d_put_lhs(buffer, result);
        d_put(buffer, "&v");
        d_put_usize(buffer, d_operand_value(context, instruction, 0));
        d_put(buffer, ".construct(v");
        d_put_usize(buffer, d_operand_value(context, instruction, 1));
        d_put(buffer, ");\n"); return true;
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
        return true;
    }
    return false;
}
