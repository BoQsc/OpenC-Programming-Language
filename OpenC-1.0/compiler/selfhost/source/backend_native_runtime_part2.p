import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe void native_file_write(ref IrContext context, ref NativeFunction function,
    usize instruction, usize result, bool raw_bytes, bool append,
    bool exclusive) {
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
    if exclusive { disposition = 1; }
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
// pipe loop enforces a configured working-set ceiling (64 MiB for compiler
// work, explicitly bounded higher for artifact tools) and a bounded wall clock.
// Descendants inherit the Job boundary and are terminated when supervision ends.
