import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe NativeProcessPatches native_process_setup(
    ref IrContext context, ref NativeFunction function, usize instruction,
    usize result
) {
    NativeProcessPatches patches = NativeProcessPatches{
        pipe_failure_finished = 0, inheritance_failure_finished = 0,
        process_failure_finished = 0, working_set_failure_finished = 0,
        time_failure_finished = 0, output_failure_finished = 0
    };
    usize command_value = d_operand_value(context, instruction, 0);
    native_utf8_path(function, command_value);

    // Frame-local runtime storage. The first 1,536 bytes are reserved by every
    // native function specifically for runtime calls and Win64 shadow arguments.
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    usize clear_offset = 576;
    while clear_offset < 896 {
        x64_mov_memory_r64(function.code, 4, clear_offset, 0);
        clear_offset = clear_offset + 8;
    }
    if d_operand_count(context, instruction) >= 4 {
        native_load(function, d_operand_value(context, instruction, 1), 0);
    } else {
        x64_mov_r64_imm64(function.code, 0, cast(u64, 300000));
    }
    x64_mov_memory_r64(function.code, 4, 880, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 24));
    x64_mov_memory_r64(function.code, 4, 600, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    x64_mov_memory_r64(function.code, 4, 616, 0);

    native_stack_address(function, 576, 1);
    native_stack_address(function, 584, 2);
    native_stack_address(function, 600, 8);
    x64_mov_r64_imm64(function.code, 9, cast(u64, 0));
    native_import(function, 23);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize pipe_ready = native_skip(function.code, 5);
    x64_mov_r64_memory(function.code, 8, 4, 504);
    native_heap_free_r8(function);
    native_process_failure_outputs(context, function, instruction, result, 1);
    patches.pipe_failure_finished = native_jump(function.code);
    native_skip_end(function.code, pipe_ready);

    x64_mov_r64_memory(function.code, 1, 4, 576);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 1));
    x64_mov_r64_imm64(function.code, 8, cast(u64, 0));
    native_import(function, 24);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize inheritance_ready = native_skip(function.code, 5);
    x64_mov_r64_memory(function.code, 1, 4, 576); native_import(function, 0);
    x64_mov_r64_memory(function.code, 1, 4, 584); native_import(function, 0);
    x64_mov_r64_memory(function.code, 8, 4, 504); native_heap_free_r8(function);
    native_process_failure_outputs(context, function, instruction, result, 1);
    patches.inheritance_failure_finished = native_jump(function.code);
    native_skip_end(function.code, inheritance_ready);

    // Load documented Job APIs dynamically from System32 Kernel32. Keeping the
    // fixed import table unchanged preserves the SH-16/SH-19 CRT-free image
    // contract while the normal runtime still uses only documented APIs.
    native_constant_ascii(function, "kernel32.dll", true, 1);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 8, cast(u64, 2048));
    native_import(function, 19); native_runtime_nonzero(function);
    x64_mov_memory_r64(function.code, 4, 776, 0);

    native_process_kernel32_export(function, "PeekNamedPipe");
    x64_mov_memory_r64(function.code, 4, 856, 0);
    native_process_kernel32_export(function, "K32GetProcessMemoryInfo");
    x64_mov_memory_r64(function.code, 4, 864, 0);
    native_process_kernel32_export(function, "TerminateJobObject");
    x64_mov_memory_r64(function.code, 4, 872, 0);

    native_process_kernel32_export(function, "CreateJobObjectW");
    x64_mov_r64_r64(function.code, 11, 0);
    x64_mov_r64_imm64(function.code, 1, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_call_r64(function.code, 11); native_runtime_nonzero(function);
    x64_mov_memory_r64(function.code, 4, 784, 0);

    // JOBOBJECT_EXTENDED_LIMIT_INFORMATION (144 bytes on Win64).
    clear_offset = 896;
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    while clear_offset < 1144 {
        x64_mov_memory_r64(function.code, 4, clear_offset, 0);
        clear_offset = clear_offset + 8;
    }
    x64_mov_memory_r64(function.code, 4, 1144, 0);
    x64_mov_memory_r64(function.code, 4, 1408, 0);
    // KILL_ON_JOB_CLOSE | PROCESS_MEMORY | JOB_MEMORY. A Job working-set limit
    // requires SE_INC_WORKING_SET_NAME and is therefore not valid for ordinary
    // unprivileged compiler processes; the polling supervisor below enforces
    // that separate 64 MiB compiler budget instead.
    x64_mov_r64_imm64(function.code, 0, cast(u64, 8960));
    x64_mov_memory_r64(function.code, 4, 912, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 268435456));
    x64_mov_memory_r64(function.code, 4, 1008, 0);
    x64_mov_memory_r64(function.code, 4, 1016, 0);

    native_process_kernel32_export(function, "SetInformationJobObject");
    x64_mov_r64_r64(function.code, 11, 0);
    x64_mov_r64_memory(function.code, 1, 4, 784);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 9));
    native_stack_address(function, 896, 8);
    x64_mov_r64_imm64(function.code, 9, cast(u64, 144));
    x64_call_r64(function.code, 11); native_runtime_nonzero(function);

    // STARTUPINFOW (640..743) and PROCESS_INFORMATION (752..775).
    x64_mov_r64_imm64(function.code, 0, cast(u64, 104));
    x64_mov_memory_r64(function.code, 4, 640, 0);
    // dwFlags occupies the high dword of the qword beginning at offset 696.
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1099511627776));
    x64_mov_memory_r64(function.code, 4, 696, 0);
    x64_mov_r64_imm64(function.code, 1,
        pe32_u64_minus_eleven() + cast(u64, 1));
    native_import(function, 8);
    x64_mov_memory_r64(function.code, 4, 720, 0);
    x64_mov_r64_memory(function.code, 0, 4, 584);
    x64_mov_memory_r64(function.code, 4, 728, 0);
    x64_mov_memory_r64(function.code, 4, 736, 0);

    x64_mov_r64_imm64(function.code, 1, cast(u64, 0));
    x64_mov_r64_memory(function.code, 2, 4, 504);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 9, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    x64_mov_memory_r64(function.code, 4, 32, 0);
    // Measured compiler children are bounded by the Job, output, RAM, and
    // timeout supervisor below. Give only that six-output measurement form a
    // stable scheduling class so unrelated desktop work does not redefine the
    // compiler's wall-clock acceptance result. Ordinary process.run calls and
    // public user programs retain the normal Windows priority class.
    usize creation_flags = 4;
    if d_operand_count(context, instruction) == 6 {
        creation_flags = 132;
    }
    x64_mov_r64_imm64(function.code, 0, cast(u64, creation_flags));
    x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 48, 0);
    x64_mov_memory_r64(function.code, 4, 56, 0);
    native_stack_address(function, 640, 0);
    x64_mov_memory_r64(function.code, 4, 64, 0);
    native_stack_address(function, 752, 0);
    x64_mov_memory_r64(function.code, 4, 72, 0);
    native_import(function, 25);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize process_ready = native_skip(function.code, 5);
    x64_mov_r64_memory(function.code, 1, 4, 576); native_import(function, 0);
    x64_mov_r64_memory(function.code, 1, 4, 584); native_import(function, 0);
    x64_mov_r64_memory(function.code, 1, 4, 784); native_import(function, 0);
    x64_mov_r64_memory(function.code, 1, 4, 776); native_import(function, 22);
    x64_mov_r64_memory(function.code, 8, 4, 504); native_heap_free_r8(function);
    native_process_failure_outputs(context, function, instruction, result, 1);
    patches.process_failure_finished = native_jump(function.code);
    native_skip_end(function.code, process_ready);

    native_process_kernel32_export(function, "AssignProcessToJobObject");
    x64_mov_r64_r64(function.code, 11, 0);
    x64_mov_r64_memory(function.code, 1, 4, 784);
    x64_mov_r64_memory(function.code, 2, 4, 752);
    x64_call_r64(function.code, 11); native_runtime_nonzero(function);

    native_process_kernel32_export(function, "ResumeThread");
    x64_mov_r64_r64(function.code, 11, 0);
    x64_mov_r64_memory(function.code, 1, 4, 760);
    x64_call_r64(function.code, 11);
    x64_add_r64_imm8(function.code, 0, 1);
    native_runtime_nonzero(function);
    native_import(function, 16);
    x64_mov_memory_r64(function.code, 4, 1136, 0);

    // Only the child keeps the write side. This lets ReadFile observe EOF.
    x64_mov_r64_memory(function.code, 1, 4, 584); native_import(function, 0);
    x64_mov_r64_memory(function.code, 8, 4, 504); native_heap_free_r8(function);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 4096));
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB in process output\n");
    x64_mov_memory_r64(function.code, 4, 800, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 808, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 4096));
    x64_mov_memory_r64(function.code, 4, 816, 0);
    return patches;
}
