import system.text;

unsafe void native_library_load(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize result,
    usize flags
) {
    native_load(function, d_operand_value(context, instruction, 0), 1);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 8, cast(u64, flags));
    native_import(function, 19);
    x64_emit_u8(function.code, 72);
    x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize loaded = native_skip(function.code, 5);
    native_status_failure(function, result, 1);
    usize finished = native_jump(function.code);
    native_skip_end(function.code, loaded);
    native_output_address(
        function, d_operand_value(context, instruction, 1), 11
    );
    x64_mov_memory_r64(function.code, 11, 0, 0);
    native_status_success(function, result);
    native_skip_end(function.code, finished);
}

unsafe void native_library_symbol(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize result
) {
    native_load(function, d_operand_value(context, instruction, 0), 1);
    native_load(function, d_operand_value(context, instruction, 1), 2);
    native_import(function, 20);
    x64_emit_u8(function.code, 72);
    x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize resolved = native_skip(function.code, 5);
    native_status_failure(function, result, 1);
    usize finished = native_jump(function.code);
    native_skip_end(function.code, resolved);
    native_output_address(
        function, d_operand_value(context, instruction, 2), 11
    );
    x64_mov_memory_r64(function.code, 11, 0, 0);
    native_status_success(function, result);
    native_skip_end(function.code, finished);
}

unsafe void native_library_close(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction
) {
    native_load(function, d_operand_value(context, instruction, 0), 1);
    native_import(function, 22);
}

unsafe void native_library_call_i32_two(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize result
) {
    native_load(function, d_operand_value(context, instruction, 0), 0);
    x64_mov_memory_r64(function.code, 4, 560, 0);
    native_load(function, d_operand_value(context, instruction, 1), 1);
    native_load(function, d_operand_value(context, instruction, 2), 2);
    x64_mov_r64_memory(function.code, 0, 4, 560);
    x64_call_r64(function.code, 0);
    native_store(function, result, 0);
}

// OpenC-native acceptance primitive for SH-22. It uses the same documented
// secure loader imports exposed by windows.resources, resolves an exported
// C-ABI function by name, invokes it with the Microsoft x64 ABI, and unloads
// the module. Negative values distinguish the two loader-boundary failures.
unsafe void native_library_dynamic_probe(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize result
) {
    native_utf8_path(function, d_operand_value(context, instruction, 0));
    x64_mov_r64_memory(function.code, 1, 4, 504);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 8, cast(u64, 4352));
    native_import(function, 19);
    x64_mov_memory_r64(function.code, 4, 520, 0);
    x64_mov_r64_memory(function.code, 8, 4, 504);
    native_heap_free_r8(function);
    x64_mov_r64_memory(function.code, 0, 4, 520);
    x64_emit_u8(function.code, 72);
    x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize loaded = native_skip(function.code, 5);
    x64_mov_r64_imm64(function.code, 0, ~cast(u64, 0));
    native_store(function, result, 0);
    usize finished_load = native_jump(function.code);
    native_skip_end(function.code, loaded);

    x64_mov_r64_memory(function.code, 1, 4, 520);
    native_constant_ascii(function, "openc_add", false, 2);
    native_import(function, 20);
    x64_mov_memory_r64(function.code, 4, 528, 0);
    x64_emit_u8(function.code, 72);
    x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize resolved = native_skip(function.code, 5);
    x64_mov_r64_memory(function.code, 1, 4, 520);
    native_import(function, 22);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 4294967294));
    native_store(function, result, 0);
    usize finished_symbol = native_jump(function.code);
    native_skip_end(function.code, resolved);

    x64_mov_r64_imm64(function.code, 1, cast(u64, 20));
    x64_mov_r64_imm64(function.code, 2, cast(u64, 22));
    x64_mov_r64_memory(function.code, 0, 4, 528);
    x64_call_r64(function.code, 0);
    x64_mov_memory_r64(function.code, 4, 536, 0);
    x64_mov_r64_memory(function.code, 1, 4, 520);
    native_import(function, 22);
    x64_mov_r64_memory(function.code, 0, 4, 536);
    native_store(function, result, 0);
    native_skip_end(function.code, finished_symbol);
    native_skip_end(function.code, finished_load);
}
