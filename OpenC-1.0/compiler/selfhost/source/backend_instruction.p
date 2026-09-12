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

    if backend_instruction_basic(
        context, buffer, instruction, value_types, reference_storage,
        next_scope_guard, opcode, result, type_id, produces
    ) { return; }
    if backend_instruction_control(
        context, buffer, instruction, value_types, reference_storage,
        next_scope_guard, opcode, result, type_id, produces
    ) { return; }
    if backend_instruction_aggregate(
        context, buffer, instruction, value_types, reference_storage,
        next_scope_guard, opcode, result, type_id, produces
    ) { return; }
    d_put(buffer, "    // "); d_put(buffer, ir_opcode_text(opcode));
    d_put(buffer, " "); d_put_instruction_text(context, buffer, instruction);
    d_put(buffer, "\n");
}
