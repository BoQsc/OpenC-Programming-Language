import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe void native_file_write(ref IrContext context, ref NativeFunction function,
    usize instruction, usize result, bool raw_bytes, bool append) {
    native_utf8_path(function, d_operand_value(context, instruction, 0));
    usize input = d_operand_value(context, instruction, 1);
    native_load(function, input, 0); x64_mov_memory_r64(function.code, 4, 520, 0);
    if raw_bytes {
        native_load(function, d_operand_value(context, instruction, 2), 0);
    } else {
        x64_mov_r64_memory(function.code, 0, 4, native_slot(function, input) + 8);
    }
    x64_mov_memory_r64(function.code, 4, 528, 0);
    x64_mov_r64_memory(function.code, 1, 4, 504);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 1073741824));
    x64_mov_r64_imm64(function.code, 8, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 9, cast(u64, 0));
    usize disposition = 2;
    if append { disposition = 4; }
    x64_mov_r64_imm64(function.code, 0, cast(u64, disposition)); x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 128)); x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0)); x64_mov_memory_r64(function.code, 4, 48, 0);
    native_import(function, 1); x64_mov_memory_r64(function.code, 4, 512, 0);
    native_import(function, 7); x64_mov_r64_r64(function.code, 1, 0);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_memory(function.code, 8, 4, 504); native_heap_free_r8(function);
    x64_mov_r64_memory(function.code, 0, 4, 512);
    x64_mov_r64_imm64(function.code, 11, ~cast(u64, 0)); x64_cmp_r64_r64(function.code, 0, 11);
    usize open_failed = native_skip(function.code, 4);

    usize seek_failed = 0;
    if append {
        x64_mov_r64_memory(function.code, 1, 4, 512);
        x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
        x64_mov_r64_imm64(function.code, 8, cast(u64, 0));
        x64_mov_r64_imm64(function.code, 9, cast(u64, 2));
        native_import(function, 29);
        x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
        x64_emit_u8(function.code, 192);
        seek_failed = native_skip(function.code, 4);
    }

    usize write_loop = function.code.bytes.length;
    x64_mov_r64_memory(function.code, 8, 4, 528);
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192); usize write_done = native_skip(function.code, 4);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 2147483647));
    x64_cmp_r64_r64(function.code, 8, 11); usize chunk_ready = native_skip(function.code, 6);
    x64_mov_r64_r64(function.code, 8, 11); native_skip_end(function.code, chunk_ready);
    x64_mov_r64_memory(function.code, 1, 4, 512);
    x64_mov_r64_memory(function.code, 2, 4, 520);
    x64_emit_rex(function.code, true, 9, 0, 4); x64_emit_u8(function.code, 141);
    x64_emit_memory_modrm(function.code, 9, 4, 536);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 536, 0);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    native_import(function, 14);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192); usize write_failed = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 0, 4, 536);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192); usize write_stalled = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 10, 4, 528);
    x64_cmp_r64_r64(function.code, 0, 10); usize write_too_large = native_skip(function.code, 7);
    x64_mov_r64_memory(function.code, 11, 4, 520); x64_add_r64_r64(function.code, 11, 0);
    x64_mov_memory_r64(function.code, 4, 520, 11);
    x64_binary_r64_r64(function.code, 41, 10, 0);
    x64_mov_memory_r64(function.code, 4, 528, 10);
    usize repeat_write = native_jump(function.code);
    x64_patch_u32(function.code, repeat_write,
        cast(u32, cast(u64, 4294967296) - cast(u64, repeat_write + 4 - write_loop)));

    native_skip_end(function.code, write_done);
    x64_mov_r64_memory(function.code, 1, 4, 512); native_import(function, 0);
    native_status_success(function, result); usize finished = native_jump(function.code);

    native_skip_end(function.code, write_failed); native_skip_end(function.code, write_stalled);
    native_skip_end(function.code, write_too_large);
    if append { native_skip_end(function.code, seek_failed); }
    x64_mov_r64_memory(function.code, 1, 4, 512); native_import(function, 0);
    native_skip_end(function.code, open_failed);
    native_status_failure(function, result, 1);
    native_skip_end(function.code, finished);
}

unsafe void native_create_directory(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize result
) {
    native_utf8_path(function, d_operand_value(context, instruction, 0));
    x64_mov_r64_memory(function.code, 1, 4, 504);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    native_import(function, 28);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize created = native_skip(function.code, 5);
    native_import(function, 6);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 183));
    x64_cmp_r64_r64(function.code, 0, 11);
    usize existed = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 8, 4, 504);
    native_heap_free_r8(function);
    native_status_failure(function, result, 1);
    usize finished = native_jump(function.code);
    native_skip_end(function.code, created);
    native_skip_end(function.code, existed);
    x64_mov_r64_memory(function.code, 8, 4, 504);
    native_heap_free_r8(function);
    native_status_success(function, result);
    native_skip_end(function.code, finished);
}

// RDX=data and R8=byte count. Handle and cursor survive partial writes and
// volatile-register clobbers in frame-local runtime scratch slots.
unsafe void native_write_console(ref NativeFunction function, bool error_stream) {
    x64_mov_memory_r64(function.code, 4, 160, 2);
    x64_mov_memory_r64(function.code, 4, 168, 8);
    u64 handle = pe32_u64_minus_eleven();
    if error_stream { handle = handle - cast(u64, 1); }
    x64_mov_r64_imm64(function.code, 1, handle);
    native_import(function, 8);
    x64_mov_memory_r64(function.code, 4, 176, 0);
    usize loop_start = function.code.bytes.length;
    x64_mov_r64_memory(function.code, 8, 4, 168);
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize done = native_skip(function.code, 4);
    x64_mov_r64_imm64(function.code, 10, cast(u64, 1048576));
    x64_cmp_r64_r64(function.code, 8, 10);
    usize small = native_skip(function.code, 6);
    x64_mov_r64_r64(function.code, 8, 10); native_skip_end(function.code, small);
    x64_mov_r64_memory(function.code, 1, 4, 176);
    x64_mov_r64_memory(function.code, 2, 4, 160);
    x64_emit_rex(function.code, true, 9, 0, 4); x64_emit_u8(function.code, 141);
    x64_emit_memory_modrm(function.code, 9, 4, 184);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 184, 0);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    native_import(function, 14); native_runtime_nonzero(function);
    x64_mov_r64_memory(function.code, 0, 4, 184); native_runtime_nonzero(function);
    x64_mov_r64_memory(function.code, 10, 4, 168);
    x64_cmp_r64_r64(function.code, 0, 10); native_require(function.code, 6);
    x64_binary_r64_r64(function.code, 41, 10, 0);
    x64_mov_memory_r64(function.code, 4, 168, 10);
    x64_mov_r64_memory(function.code, 10, 4, 160);
    x64_add_r64_r64(function.code, 10, 0);
    x64_mov_memory_r64(function.code, 4, 160, 10);
    usize repeat = native_jump(function.code);
    x64_patch_u32(function.code, repeat, cast(u32, cast(u64, 4294967296) -
        cast(u64, repeat + 4 - loop_start)));
    native_skip_end(function.code, done);
}

unsafe void native_stack_address(
    ref NativeFunction function, usize offset, usize register_code
) {
    x64_emit_rex(function.code, true, register_code, 0, 4);
    x64_emit_u8(function.code, 141);
    x64_emit_memory_modrm(function.code, register_code, 4, offset);
}

// Resolve a documented Kernel32 export through the already imported secure
// loader boundary. The module handle lives in the caller's runtime scratch at
// offset 776; RAX contains the resolved function pointer on return.
unsafe void native_process_kernel32_export(
    ref NativeFunction function, text name
) {
    x64_mov_r64_memory(function.code, 1, 4, 776);
    native_constant_ascii(function, name, false, 2);
    native_import(function, 20);
    native_runtime_nonzero(function);
}

unsafe void native_process_failure_outputs(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize result,
    usize status_code
) {
    usize exit_operand = 1;
    usize output_operand = 2;
    if d_operand_count(context, instruction) >= 4 {
        exit_operand = 2;
        output_operand = 3;
    }
    usize exit_value = d_operand_value(context, instruction, exit_operand);
    native_output_address(function, exit_value, 11);
    x64_mov_r64_imm64(function.code, 0, ~cast(u64, 0));
    x64_mov_memory_r64(function.code, 11, 0, 0);
    usize output_value = d_operand_value(context, instruction, output_operand);
    native_output_address(function, output_value, 11);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 11, 0, 0);
    x64_mov_memory_r64(function.code, 11, 8, 0);
    if d_operand_count(context, instruction) == 6 {
        usize private_value = d_operand_value(context, instruction, 4);
        native_output_address(function, private_value, 11);
        x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
        x64_mov_memory_r64(function.code, 11, 0, 0);
        usize working_set_value = d_operand_value(context, instruction, 5);
        native_output_address(function, working_set_value, 11);
        x64_mov_memory_r64(function.code, 11, 0, 0);
    }
    native_status_failure(function, result, status_code);
}

// Spawn a child with inherited pipe handles and capture both stdout and stderr.
// The implementation calls documented KERNEL32 APIs directly. Output grows from
// 4 KiB and is capped at 4 MiB; excess data is drained before a visible guarded
// failure is returned so a noisy child cannot deadlock or exhaust the compiler.
// Every child is created suspended, placed in a kill-on-close Job object with
// a 256 MiB per-process and whole-job memory limit, then resumed. A nonblocking
// pipe loop also enforces a 64 MiB working-set ceiling and a bounded wall clock.
// Descendants inherit the Job boundary and are terminated when supervision ends.
unsafe void native_process_run(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize result
) {
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
    usize pipe_failure_finished = native_jump(function.code);
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
    usize inheritance_failure_finished = native_jump(function.code);
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
    x64_mov_r64_imm64(function.code, 0, cast(u64, 4));
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
    usize process_failure_finished = native_jump(function.code);
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

    usize read_loop = function.code.bytes.length;

    // An exited process can no longer exceed a resource limit, and some Windows
    // versions no longer expose meaningful live counters after it is signaled.
    // Mark it first, skip supervision, then drain any bytes still in the pipe.
    x64_mov_r64_memory(function.code, 1, 4, 752);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    native_import(function, 26);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize supervise_running_process = native_skip(function.code, 5);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    x64_mov_memory_r64(function.code, 4, 888, 0);
    usize skip_process_supervision = native_jump(function.code);
    native_skip_end(function.code, supervise_running_process);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 258));
    x64_cmp_r64_r64(function.code, 0, 11); native_require(function.code, 4);

    // Enforce the unprivileged 64 MiB working-set rule by observing the child
    // directly; JOB_OBJECT_LIMIT_WORKINGSET requires a quota privilege and is
    // not available to ordinary compiler processes.
    x64_mov_r64_imm64(function.code, 0, cast(u64, 80));
    x64_mov_memory_r64(function.code, 4, 1040, 0);
    x64_mov_r64_memory(function.code, 11, 4, 864);
    x64_mov_r64_memory(function.code, 1, 4, 752);
    native_stack_address(function, 1040, 2);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 80));
    x64_call_r64(function.code, 11); native_runtime_nonzero(function);
    x64_mov_r64_memory(function.code, 10, 4, 1056);
    x64_mov_r64_memory(function.code, 9, 4, 1144);
    x64_cmp_r64_r64(function.code, 10, 9);
    usize working_set_not_peak = native_skip(function.code, 6);
    x64_mov_memory_r64(function.code, 4, 1144, 10);
    native_skip_end(function.code, working_set_not_peak);
    x64_mov_r64_memory(function.code, 10, 4, 1112);
    x64_mov_r64_memory(function.code, 9, 4, 1408);
    x64_cmp_r64_r64(function.code, 10, 9);
    usize private_not_peak = native_skip(function.code, 6);
    x64_mov_memory_r64(function.code, 4, 1408, 10);
    native_skip_end(function.code, private_not_peak);
    x64_mov_r64_memory(function.code, 10, 4, 1056);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 67108864));
    x64_cmp_r64_r64(function.code, 10, 11);
    usize working_set_within_budget = native_skip(function.code, 6);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    x64_mov_memory_r64(function.code, 4, 1120, 0);
    x64_mov_r64_memory(function.code, 11, 4, 872);
    x64_mov_r64_memory(function.code, 1, 4, 784);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 70));
    x64_call_r64(function.code, 11); native_runtime_nonzero(function);
    native_skip_end(function.code, working_set_within_budget);

    native_import(function, 16);
    x64_mov_r64_memory(function.code, 11, 4, 1136);
    x64_binary_r64_r64(function.code, 41, 0, 11);
    x64_mov_r64_memory(function.code, 11, 4, 880);
    x64_cmp_r64_r64(function.code, 0, 11);
    usize time_within_budget = native_skip(function.code, 2);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    x64_mov_memory_r64(function.code, 4, 1128, 0);
    x64_mov_r64_memory(function.code, 11, 4, 872);
    x64_mov_r64_memory(function.code, 1, 4, 784);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 70));
    x64_call_r64(function.code, 11); native_runtime_nonzero(function);
    native_skip_end(function.code, time_within_budget);
    native_skip_end(function.code, skip_process_supervision);

    // Peek before every synchronous read, then wait at most 25 ms for process
    // progress. This keeps output capture responsive to RAM and timeout rules.
    x64_mov_r64_memory(function.code, 11, 4, 856);
    x64_mov_r64_memory(function.code, 1, 4, 576);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 8, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 9, cast(u64, 0));
    native_stack_address(function, 824, 0);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_call_r64(function.code, 11);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize peek_ready = native_skip(function.code, 5);
    usize peek_finished = native_jump(function.code);
    native_skip_end(function.code, peek_ready);
    x64_mov_r64_memory(function.code, 0, 4, 824);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize data_ready = native_skip(function.code, 5);

    x64_mov_r64_memory(function.code, 0, 4, 888);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize wait_needed = native_skip(function.code, 4);
    usize signaled_finished = native_jump(function.code);
    native_skip_end(function.code, wait_needed);
    x64_mov_r64_memory(function.code, 1, 4, 752);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 25));
    native_import(function, 26);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize process_still_running = native_skip(function.code, 5);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    x64_mov_memory_r64(function.code, 4, 888, 0);
    usize repeat_after_signal = native_jump(function.code);
    native_skip_end(function.code, process_still_running);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 258));
    x64_cmp_r64_r64(function.code, 0, 11); native_require(function.code, 4);
    usize repeat_after_wait = native_jump(function.code);
    x64_patch_u32(function.code, repeat_after_signal,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_after_signal + 4 - read_loop)));
    x64_patch_u32(function.code, repeat_after_wait,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_after_wait + 4 - read_loop)));
    native_skip_end(function.code, data_ready);

    x64_mov_r64_memory(function.code, 10, 4, 808);
    x64_mov_r64_memory(function.code, 11, 4, 816);
    x64_cmp_r64_r64(function.code, 10, 11);
    usize buffer_has_room = native_skip(function.code, 5);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 4194304));
    x64_cmp_r64_r64(function.code, 11, 0);
    usize buffer_can_grow = native_skip(function.code, 2);

    // At the cap, continue draining into scratch and remember the overflow.
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    x64_mov_memory_r64(function.code, 4, 840, 0);
    x64_mov_r64_memory(function.code, 1, 4, 576);
    native_stack_address(function, 1152, 2);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 256));
    native_stack_address(function, 824, 9);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 824, 0);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    native_import(function, 12);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize drain_finished = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 0, 4, 824);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize drain_empty = native_skip(function.code, 4);
    usize repeat_drain = native_jump(function.code);
    x64_patch_u32(function.code, repeat_drain,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_drain + 4 - read_loop)));

    native_skip_end(function.code, buffer_can_grow);
    x64_mov_r64_memory(function.code, 8, 4, 816);
    x64_add_r64_r64(function.code, 8, 8);
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB growing process output\n");
    x64_mov_memory_r64(function.code, 4, 848, 0);
    x64_mov_r64_r64(function.code, 10, 0);
    x64_mov_r64_memory(function.code, 11, 4, 800);
    x64_mov_r64_memory(function.code, 9, 4, 808);
    native_copy_bytes(function);
    x64_mov_r64_memory(function.code, 8, 4, 800);
    native_heap_free_r8(function);
    x64_mov_r64_memory(function.code, 0, 4, 848);
    x64_mov_memory_r64(function.code, 4, 800, 0);
    x64_mov_r64_memory(function.code, 0, 4, 816);
    x64_add_r64_r64(function.code, 0, 0);
    x64_mov_memory_r64(function.code, 4, 816, 0);

    native_skip_end(function.code, buffer_has_room);
    x64_mov_r64_memory(function.code, 1, 4, 576);
    x64_mov_r64_memory(function.code, 2, 4, 800);
    x64_mov_r64_memory(function.code, 10, 4, 808);
    x64_add_r64_r64(function.code, 2, 10);
    x64_mov_r64_memory(function.code, 8, 4, 816);
    x64_binary_r64_r64(function.code, 41, 8, 10);
    native_stack_address(function, 824, 9);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 824, 0);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    native_import(function, 12);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize read_finished = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 0, 4, 824);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize read_empty = native_skip(function.code, 4);
    x64_add_r64_memory(function.code, 0, 4, 808);
    x64_mov_memory_r64(function.code, 4, 808, 0);
    usize repeat_read = native_jump(function.code);
    x64_patch_u32(function.code, repeat_read,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_read + 4 - read_loop)));

    native_skip_end(function.code, drain_finished);
    native_skip_end(function.code, drain_empty);
    native_skip_end(function.code, read_finished);
    native_skip_end(function.code, read_empty);
    native_skip_end(function.code, peek_finished);
    native_skip_end(function.code, signaled_finished);
    x64_mov_r64_memory(function.code, 1, 4, 576); native_import(function, 0);
    x64_mov_r64_memory(function.code, 1, 4, 752);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 4294967295));
    native_import(function, 26);
    x64_mov_r64_memory(function.code, 1, 4, 752);
    native_stack_address(function, 832, 2);
    native_import(function, 27);
    x64_mov_r64_memory(function.code, 1, 4, 760); native_import(function, 0);
    x64_mov_r64_memory(function.code, 1, 4, 752); native_import(function, 0);
    x64_mov_r64_memory(function.code, 1, 4, 784); native_import(function, 0);
    x64_mov_r64_memory(function.code, 1, 4, 776); native_import(function, 22);

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
    usize working_set_failure_finished = native_jump(function.code);
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
    usize time_failure_finished = native_jump(function.code);
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
    usize output_failure_finished = native_jump(function.code);

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

    native_skip_end(function.code, pipe_failure_finished);
    native_skip_end(function.code, inheritance_failure_finished);
    native_skip_end(function.code, process_failure_finished);
    native_skip_end(function.code, working_set_failure_finished);
    native_skip_end(function.code, time_failure_finished);
    native_skip_end(function.code, output_failure_finished);
}

unsafe DCompilerCallSpan native_runtime_call_span(
    ref IrContext context,
    usize kind,
    usize one,
    usize two
) {
    DCompilerCallSpan result = DCompilerCallSpan{
        found = false, source = "", start = 0, length = 0
    };
    if kind == 3 {
        if one >= context.symbols.length { return result; }
        result.source = d_symbol_source(context, one);
        if text.byte_length(result.source) == 0 { return result; }
        result.start = read_record_field(context.symbol_data, one, 2);
        result.length = read_record_field(context.symbol_data, one, 3);
        result.found = true;
        return result;
    }
    if kind == 2 {
        result.source = ir_static_text(one);
        result.length = text.byte_length(result.source);
        result.found = true;
        return result;
    }
    if kind != 1 && kind != 7 && kind != 8 { return result; }
    result.source = context.source;
    result.start = one;
    result.length = two;
    result.found = true;
    return result;
}

unsafe bool native_runtime_name(
    ref DCompilerCallSpan call_span,
    text short_name,
    text qualified_name
) {
    if !call_span.found { return false; }
    return span_equals_ascii(
            call_span.source, call_span.start, call_span.length, short_name
        ) || span_equals_ascii(
            call_span.source, call_span.start, call_span.length,
            qualified_name
        );
}

unsafe bool native_runtime_call(ref IrContext context, ref NativeFunction function,
    usize instruction) {
    usize result = read_record_field(context.instruction_data, instruction, 1);
    usize detail_kind = read_record_field(
        context.instruction_detail, instruction, 0
    );
    usize detail_one = read_record_field(
        context.instruction_detail, instruction, 1
    );
    usize detail_two = read_record_field(
        context.instruction_detail, instruction, 2
    );
    DCompilerCallSpan call_span = native_runtime_call_span(
        context, detail_kind, detail_one, detail_two
    );
    if detail_kind == 3 {
        if !native_runtime_name(
            call_span, "lsp_read_frame", "ocb_lsp_read_frame"
        ) && !native_runtime_name(
            call_span,
            "cli_process_run_bounded", "cli_process_run_bounded"
        ) && !native_runtime_name(
            call_span,
            "cli_process_run_measured", "cli_process_run_measured"
        ) && !native_runtime_name(
            call_span,
            "cli_file_append_bytes", "cli_file_append_bytes"
        ) && !native_runtime_name(
            call_span,
            "cli_file_create_directory", "cli_file_create_directory"
        ) {
            return false;
        }
    }
    if native_runtime_name(call_span, "memory.alloc", "system.memory.alloc") {
        native_load(function, d_operand_value(context, instruction, 0), 8);
        DBuffer allocation_message = d_buffer_create(512);
        d_put(allocation_message,
            "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB at memory.alloc in ");
        d_put_symbol_name(context, allocation_message, context.function_symbol);
        d_put(allocation_message, "\n");
        native_heap_allocate_named_r8(function, d_buffer_text(allocation_message));
        d_buffer_destroy(allocation_message);
        native_store(function, result, 0); return true;
    }
    if native_runtime_name(call_span, "memory.free", "system.memory.free") {
        native_load(function, d_operand_value(context, instruction, 0), 8);
        native_heap_free_r8(function); return true;
    }
    if native_runtime_name(call_span, "text.trim", "system.text.trim") {
        native_text_trim(function, d_operand_value(context, instruction, 0), result);
        return true;
    }
    if native_runtime_name(call_span, "text.length", "system.text.length") {
        native_text_scalar_length(function, d_operand_value(context, instruction, 0), result);
        return true;
    }
    if native_runtime_name(call_span, "memory.load_usize", "system.memory.load_usize") {
        native_load(function, d_operand_value(context, instruction, 0), 11);
        x64_mov_r64_memory(function.code, 0, 11, 0); native_store(function, result, 0);
        return true;
    }
    if native_runtime_name(call_span, "memory.store_usize", "system.memory.store_usize") {
        native_load(function, d_operand_value(context, instruction, 0), 11);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        x64_mov_memory_r64(function.code, 11, 0, 0); return true;
    }
    if native_runtime_name(call_span, "text.byte_at_unchecked", "system.text.byte_at_unchecked") {
        usize value = d_operand_value(context, instruction, 0);
        native_load(function, value, 11);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        x64_add_r64_r64(function.code, 11, 0);
        x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
        x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 3);
        native_store(function, result, 0); return true;
    }
    if native_runtime_name(call_span, "text.copy_utf8_unchecked",
        "system.text.copy_utf8_unchecked") {
        native_load(function, d_operand_value(context, instruction, 0), 10);
        usize value = d_operand_value(context, instruction, 1);
        native_load(function, value, 11);
        x64_mov_r64_memory(function.code, 9, 4, native_slot(function, value) + 8);
        native_copy_bytes(function); return true;
    }
    if native_runtime_name(call_span, "text.copy_utf8_slice_unchecked",
        "system.text.copy_utf8_slice_unchecked") {
        native_load(function, d_operand_value(context, instruction, 0), 10);
        usize value = d_operand_value(context, instruction, 1);
        native_load(function, value, 11);
        native_load(function, d_operand_value(context, instruction, 2), 0);
        x64_add_r64_r64(function.code, 11, 0);
        native_load(function, d_operand_value(context, instruction, 3), 9);
        native_copy_bytes(function); return true;
    }
    if native_runtime_name(call_span, "text.from_utf8", "system.text.from_utf8") {
        native_load(function, d_operand_value(context, instruction, 0), 0);
        native_store(function, result, 0);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        x64_mov_memory_r64(function.code, 4, native_slot(function, result) + 8, 0);
        return true;
    }
    if native_runtime_name(call_span, "text.equal", "system.text.equal") {
        native_text_equal(function, d_operand_value(context, instruction, 0),
            d_operand_value(context, instruction, 1));
        native_store(function, result, 0); return true;
    }
    if native_runtime_name(call_span, "text.slice", "system.text.slice") {
        if d_operand_count(context, instruction) != 4 { function.code.ok = false; return true; }
        native_text_scalar_slice(context, function, instruction, result); return true;
    }
    if native_runtime_name(call_span, "process.run", "system.process.run") {
        if d_operand_count(context, instruction) != 3 { function.code.ok = false; return true; }
        native_process_run(context, function, instruction, result); return true;
    }
    if native_runtime_name(
        call_span, "cli_process_run_bounded", "cli_process_run_bounded"
    ) {
        if d_operand_count(context, instruction) != 4 { function.code.ok = false; return true; }
        native_process_run(context, function, instruction, result); return true;
    }
    if native_runtime_name(
        call_span, "cli_process_run_measured", "cli_process_run_measured"
    ) {
        if d_operand_count(context, instruction) != 6 { function.code.ok = false; return true; }
        native_process_run(context, function, instruction, result); return true;
    }
    if native_runtime_name(call_span, "path.join", "system.path.join") {
        native_path_join(function, d_operand_value(context, instruction, 0),
        d_operand_value(context, instruction, 1), result); return true;
    }
    if native_runtime_name(call_span, "path.directory", "system.path.directory") {
        native_path_directory(function, d_operand_value(context, instruction, 0), result);
        return true;
    }
    if native_runtime_name(call_span, "process.monotonic_milliseconds",
        "system.process.monotonic_milliseconds") {
        native_import(function, 16); native_store(function, result, 0); return true;
    }
    if native_runtime_name(call_span, "process.argument_count",
        "system.process.argument_count") {
        native_process_argument_count(function, result); return true;
    }
    if native_runtime_name(call_span, "process.argument", "system.process.argument") {
        native_process_argument(function, d_operand_value(context, instruction, 0), result);
        return true;
    }
    if native_runtime_name(call_span, "process.executable_directory",
        "system.process.executable_directory") {
        native_process_executable_directory(function, result); return true;
    }
    if native_runtime_name(call_span, "process.executable_path",
            "system.process.executable_path") || native_runtime_name(
            call_span, "runtime_executable_path",
            "oc_process_executable_path"
        ) {
        native_process_executable_path(function, result); return true;
    }
    if native_runtime_name(call_span, "lsp_read_frame", "ocb_lsp_read_frame") {
        if d_operand_count(context, instruction) != 1 {
            function.code.ok = false; return true;
        }
        native_lsp_read_frame(context, function, instruction, result);
        return true;
    }
    if native_runtime_name(call_span, "file.read_text_cached", "system.file.read_text_cached") {
        native_file_read_cached(context, function, instruction, result); return true;
    }
    if native_runtime_name(call_span, "file.read_text", "system.file.read_text") ||
        native_runtime_name(call_span, "file.read_bytes", "system.file.read_bytes") {
        native_file_read(context, function, instruction, result, false); return true;
    }
    if native_runtime_name(call_span, "file.read_bytes_raw", "system.file.read_bytes_raw") {
        native_file_read(context, function, instruction, result, true); return true;
    }
    if native_runtime_name(call_span, "file.write_text", "system.file.write_text") {
        if d_operand_count(context, instruction) != 2 { function.code.ok = false; return true; }
        native_file_write(context, function, instruction, result, false, false); return true;
    }
    if native_runtime_name(call_span, "file.write_bytes", "system.file.write_bytes") {
        if d_operand_count(context, instruction) != 3 { function.code.ok = false; return true; }
        native_file_write(context, function, instruction, result, true, false); return true;
    }
    if native_runtime_name(call_span, "cli_file_append_bytes", "cli_file_append_bytes") {
        if d_operand_count(context, instruction) != 3 { function.code.ok = false; return true; }
        native_file_write(context, function, instruction, result, true, true); return true;
    }
    if native_runtime_name(call_span, "cli_file_create_directory", "cli_file_create_directory") {
        if d_operand_count(context, instruction) != 1 { function.code.ok = false; return true; }
        native_create_directory(context, function, instruction, result); return true;
    }
    bool println = native_runtime_name(call_span, "io.println", "system.io.println");
    bool print = native_runtime_name(call_span, "io.print", "system.io.print");
    bool error_stream = native_runtime_name(call_span, "io.error", "system.io.error");
    if println || print || error_stream {
        usize value = d_operand_value(context, instruction, 0);
        usize type_id = native_value_read(function, function.value_types, value);
        if c_type_is_text(context, type_id) {
            native_load(function, value, 2);
            x64_mov_r64_memory(function.code, 8, 4, native_slot(function, value) + 8);
            native_write_console(function, error_stream);
        } else {
            usize kind = read_record_field(context.type_data, type_id, 0);
            if error_stream || (kind != 2 && kind != 3 && kind != 5 && kind != 6) {
                function.code.ok = false; return true;
            }
            native_load(function, value, 0);
            if kind == 5 { native_write_bool(function); }
            else { native_write_integer(function, kind == 2); }
        }
        if println {
            x64_mov_r64_imm64(function.code, 0, cast(u64, 10));
            x64_mov_memory_r64(function.code, 4, 192, 0);
            x64_emit_rex(function.code, true, 2, 0, 4); x64_emit_u8(function.code, 141);
            x64_emit_memory_modrm(function.code, 2, 4, 192);
            x64_mov_r64_imm64(function.code, 8, cast(u64, 1));
            native_write_console(function, error_stream);
        }
        return true;
    }
    return false;
}
