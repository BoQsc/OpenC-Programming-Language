import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe void native_process_results(
    ref IrContext context, ref NativeFunction function, usize instruction,
    usize result, ref NativeProcessPatches patches
) {
    x64_mov_r64_memory(function.code, 0, 4, 1120);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize working_set_within_budget_result = native_skip(function.code, 4);
    native_constant_ascii(function,
        "fatal[OPENC-NATIVE-PROCESS-WORKING-SET-BUDGET]: child working set exceeds 64 MiB\n",
        false, 2);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 81));
    native_write_console(function, true);
    x64_mov_r64_memory(function.code, 8, 4, 800);
    native_heap_free_r8(function);
    native_process_failure_outputs(context, function, instruction, result, 2);
    patches.working_set_failure_finished = native_jump(function.code);
    native_skip_end(function.code, working_set_within_budget_result);

    x64_mov_r64_memory(function.code, 0, 4, 1128);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize time_within_budget_result = native_skip(function.code, 4);
    native_constant_ascii(function,
        "fatal[OPENC-NATIVE-PROCESS-TIME-BUDGET]: child exceeds its timeout\n",
        false, 2);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 67));
    native_write_console(function, true);
    x64_mov_r64_memory(function.code, 8, 4, 800);
    native_heap_free_r8(function);
    native_process_failure_outputs(context, function, instruction, result, 3);
    patches.time_failure_finished = native_jump(function.code);
    native_skip_end(function.code, time_within_budget_result);

    x64_mov_r64_memory(function.code, 0, 4, 840);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize output_within_budget = native_skip(function.code, 4);
    native_constant_ascii(function,
        "fatal[OPENC-NATIVE-PROCESS-OUTPUT-BUDGET]: child output exceeds 4 MiB\n",
        false, 2);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 70));
    native_write_console(function, true);
    x64_mov_r64_memory(function.code, 8, 4, 800);
    native_heap_free_r8(function);
    native_process_failure_outputs(context, function, instruction, result, 4);
    patches.output_failure_finished = native_jump(function.code);

    native_skip_end(function.code, output_within_budget);
    usize exit_operand = 1;
    usize output_operand = 2;
    if d_operand_count(context, instruction) >= 4 {
        exit_operand = 2;
        output_operand = 3;
    }
    usize exit_value = d_operand_value(context, instruction, exit_operand);
    native_output_address(function, exit_value, 11);
    x64_mov_r64_memory(function.code, 0, 4, 832);
    x64_mov_memory_r64(function.code, 11, 0, 0);
    usize output_value = d_operand_value(context, instruction, output_operand);
    native_output_address(function, output_value, 11);
    x64_mov_r64_memory(function.code, 0, 4, 800);
    x64_mov_memory_r64(function.code, 11, 0, 0);
    x64_mov_r64_memory(function.code, 0, 4, 808);
    x64_mov_memory_r64(function.code, 11, 8, 0);
    if d_operand_count(context, instruction) == 6 {
        usize private_value = d_operand_value(context, instruction, 4);
        native_output_address(function, private_value, 11);
        x64_mov_r64_memory(function.code, 0, 4, 1408);
        x64_mov_memory_r64(function.code, 11, 0, 0);
        usize working_set_value = d_operand_value(context, instruction, 5);
        native_output_address(function, working_set_value, 11);
        x64_mov_r64_memory(function.code, 0, 4, 1144);
        x64_mov_memory_r64(function.code, 11, 0, 0);
    }
    native_status_success(function, result);
}
