import system.io;
import system.memory;
import system.text;

unsafe void native_scalar_instruction(
    ref IrContext context, ref NativeFunction function, usize instruction
) {
    usize opcode = read_record_field(context.instruction_data, instruction, 2);
    usize result = read_record_field(context.instruction_data, instruction, 1);
    usize type_id = read_record_field(context.instruction_data, instruction, 3);
    NativeLayout result_layout = native_layout(context, type_id, 0);
    if result != 0 && !result_layout.valid {
        function.code.ok = false; return;
    }
    if backend_native_scalar_emit_basic(
        context, function, instruction, opcode, result, type_id, result_layout
    ) { return; }
    if backend_native_scalar_emit_composite(
        context, function, instruction, opcode, result, type_id, result_layout
    ) { return; }
    if backend_native_scalar_emit_operations(
        context, function, instruction, opcode, result, type_id, result_layout
    ) { return; }
    if backend_native_scalar_emit_call(
        context, function, instruction, opcode, result, type_id, result_layout
    ) { return; }
    function.code.ok = false;
}
