import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe void native_process_executable_directory(ref NativeFunction function,
    usize result) {
    x64_mov_r64_imm64(function.code, 8, cast(u64, 65544));
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB in process.executable_directory\n");
    x64_mov_memory_r64(function.code, 4, 480, 0);
    x64_mov_r64_imm64(function.code, 1, cast(u64, 0));
    x64_mov_r64_r64(function.code, 2, 0);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 32768));
    native_import(function, 17); native_runtime_nonzero(function);
    x64_mov_memory_r64(function.code, 4, 488, 0);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 32768));
    x64_cmp_r64_r64(function.code, 0, 11); native_require(function.code, 2);

    x64_mov_r64_imm64(function.code, 1, cast(u64, 65001));
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_memory(function.code, 8, 4, 480);
    x64_mov_r64_memory(function.code, 9, 4, 488);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_memory_r64(function.code, 4, 48, 0);
    x64_mov_memory_r64(function.code, 4, 56, 0);
    native_import(function, 13); native_runtime_nonzero(function);
    x64_mov_memory_r64(function.code, 4, 496, 0);
    x64_mov_r64_r64(function.code, 8, 0); x64_add_r64_imm8(function.code, 8, 8);
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB in process.executable_directory UTF-8 conversion\n");
    x64_mov_memory_r64(function.code, 4, 504, 0);

    x64_mov_r64_imm64(function.code, 1, cast(u64, 65001));
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_memory(function.code, 8, 4, 480);
    x64_mov_r64_memory(function.code, 9, 4, 488);
    x64_mov_r64_memory(function.code, 0, 4, 504);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_r64_memory(function.code, 0, 4, 496);
    x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 48, 0);
    x64_mov_memory_r64(function.code, 4, 56, 0);
    native_import(function, 13); native_runtime_nonzero(function);
    x64_mov_r64_memory(function.code, 11, 4, 504);
    x64_mov_r64_memory(function.code, 10, 4, 496);
    x64_add_r64_r64(function.code, 11, 10);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 11, 0, 0);
    x64_mov_r64_memory(function.code, 0, 4, 504); native_store(function, result, 0);
    x64_mov_r64_memory(function.code, 0, 4, 496);
    x64_mov_memory_r64(function.code, 4, native_slot(function, result) + 8, 0);
    native_path_directory(function, result, result);
}

unsafe void native_process_executable_path(ref NativeFunction function,
    usize result) {
    x64_mov_r64_imm64(function.code, 8, cast(u64, 65544));
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB in process.executable_path\n");
    x64_mov_memory_r64(function.code, 4, 480, 0);
    x64_mov_r64_imm64(function.code, 1, cast(u64, 0));
    x64_mov_r64_r64(function.code, 2, 0);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 32768));
    native_import(function, 17); native_runtime_nonzero(function);
    x64_mov_memory_r64(function.code, 4, 488, 0);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 32768));
    x64_cmp_r64_r64(function.code, 0, 11); native_require(function.code, 2);

    x64_mov_r64_imm64(function.code, 1, cast(u64, 65001));
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_memory(function.code, 8, 4, 480);
    x64_mov_r64_memory(function.code, 9, 4, 488);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_memory_r64(function.code, 4, 48, 0);
    x64_mov_memory_r64(function.code, 4, 56, 0);
    native_import(function, 13); native_runtime_nonzero(function);
    x64_mov_memory_r64(function.code, 4, 496, 0);
    x64_mov_r64_r64(function.code, 8, 0); x64_add_r64_imm8(function.code, 8, 8);
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB in process.executable_path UTF-8 conversion\n");
    x64_mov_memory_r64(function.code, 4, 504, 0);

    x64_mov_r64_imm64(function.code, 1, cast(u64, 65001));
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_memory(function.code, 8, 4, 480);
    x64_mov_r64_memory(function.code, 9, 4, 488);
    x64_mov_r64_memory(function.code, 0, 4, 504);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_r64_memory(function.code, 0, 4, 496);
    x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 48, 0);
    x64_mov_memory_r64(function.code, 4, 56, 0);
    native_import(function, 13); native_runtime_nonzero(function);
    x64_mov_r64_memory(function.code, 11, 4, 504);
    x64_mov_r64_memory(function.code, 10, 4, 496);
    x64_add_r64_r64(function.code, 11, 10);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 11, 0, 0);
    x64_mov_r64_memory(function.code, 0, 4, 504); native_store(function, result, 0);
    x64_mov_r64_memory(function.code, 0, 4, 496);
    x64_mov_memory_r64(function.code, 4, native_slot(function, result) + 8, 0);
}

unsafe void native_command_arguments(ref NativeFunction function) {
    native_constant_ascii(function, "shell32.dll", true, 1);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 8, cast(u64, 2048));
    native_import(function, 19); native_runtime_nonzero(function);
    x64_mov_memory_r64(function.code, 4, 480, 0);
    x64_mov_r64_r64(function.code, 1, 0);
    native_constant_ascii(function, "CommandLineToArgvW", false, 2);
    native_import(function, 20); native_runtime_nonzero(function);
    x64_mov_memory_r64(function.code, 4, 488, 0);
    native_import(function, 4); x64_mov_r64_r64(function.code, 1, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 496, 0);
    x64_emit_rex(function.code, true, 2, 0, 4); x64_emit_u8(function.code, 141);
    x64_emit_memory_modrm(function.code, 2, 4, 496);
    x64_mov_r64_memory(function.code, 11, 4, 488); x64_call_r64(function.code, 11);
    native_runtime_nonzero(function); x64_mov_memory_r64(function.code, 4, 504, 0);
}

unsafe void native_release_command_arguments(ref NativeFunction function) {
    x64_mov_r64_memory(function.code, 1, 4, 504); native_import(function, 21);
    x64_mov_r64_memory(function.code, 1, 4, 480); native_import(function, 22);
}

unsafe void native_process_argument_count(ref NativeFunction function, usize result) {
    native_command_arguments(function);
    x64_mov_r64_memory(function.code, 0, 4, 496); native_runtime_nonzero(function);
    x64_alu_r64_imm8(function.code, 5, 0, 1);
    native_store(function, result, 0);
    native_release_command_arguments(function);
}

unsafe void native_process_argument(ref NativeFunction function, usize value,
    usize result) {
    native_load(function, value, 0); x64_mov_memory_r64(function.code, 4, 472, 0);
    native_command_arguments(function);
    x64_mov_r64_memory(function.code, 10, 4, 472); x64_add_r64_imm8(function.code, 10, 1);
    x64_mov_r64_memory(function.code, 11, 4, 496);
    x64_cmp_r64_r64(function.code, 10, 11); native_require(function.code, 2);
    x64_mov_r64_r64(function.code, 11, 10);
    x64_add_r64_r64(function.code, 11, 11);
    x64_add_r64_r64(function.code, 11, 11);
    x64_add_r64_r64(function.code, 11, 11);
    x64_add_r64_memory(function.code, 11, 4, 504);
    x64_mov_r64_memory(function.code, 8, 11, 0);
    x64_mov_memory_r64(function.code, 4, 512, 8);
    x64_mov_r64_r64(function.code, 10, 8);
    x64_mov_r64_imm64(function.code, 9, cast(u64, 0));
    usize length_loop = function.code.bytes.length;
    x64_emit_rex(function.code, false, 0, 0, 10); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 183); x64_emit_memory_modrm(function.code, 0, 10, 0);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192); usize length_done = native_skip(function.code, 4);
    x64_add_r64_imm8(function.code, 10, 2); x64_add_r64_imm8(function.code, 9, 1);
    usize repeat_length = native_jump(function.code);
    x64_patch_u32(function.code, repeat_length,
        cast(u32, cast(u64, 4294967296) - cast(u64, repeat_length + 4 - length_loop)));
    native_skip_end(function.code, length_done);
    x64_mov_memory_r64(function.code, 4, 520, 9);

    x64_mov_r64_imm64(function.code, 1, cast(u64, 65001));
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_memory(function.code, 8, 4, 512);
    x64_mov_r64_memory(function.code, 9, 4, 520);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_memory_r64(function.code, 4, 48, 0);
    x64_mov_memory_r64(function.code, 4, 56, 0);
    native_import(function, 13); native_runtime_nonzero(function);
    x64_mov_memory_r64(function.code, 4, 528, 0);
    x64_mov_r64_r64(function.code, 8, 0); x64_add_r64_imm8(function.code, 8, 8);
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB in process.argument\n");
    x64_mov_memory_r64(function.code, 4, 536, 0);
    x64_mov_r64_imm64(function.code, 1, cast(u64, 65001));
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_memory(function.code, 8, 4, 512);
    x64_mov_r64_memory(function.code, 9, 4, 520);
    x64_mov_r64_memory(function.code, 0, 4, 536); x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_r64_memory(function.code, 0, 4, 528); x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 48, 0);
    x64_mov_memory_r64(function.code, 4, 56, 0);
    native_import(function, 13); native_runtime_nonzero(function);
    x64_mov_r64_memory(function.code, 11, 4, 536);
    x64_mov_r64_memory(function.code, 10, 4, 528); x64_add_r64_r64(function.code, 11, 10);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0)); x64_mov_memory_r64(function.code, 11, 0, 0);
    native_release_command_arguments(function);
    x64_mov_r64_memory(function.code, 0, 4, 536); native_store(function, result, 0);
    x64_mov_r64_memory(function.code, 0, 4, 528);
    x64_mov_memory_r64(function.code, 4, native_slot(function, result) + 8, 0);
}

unsafe void native_utf8_path(ref NativeFunction function, usize value) {
    native_load(function, value, 0); x64_mov_memory_r64(function.code, 4, 480, 0);
    x64_mov_r64_memory(function.code, 0, 4, native_slot(function, value) + 8);
    x64_mov_memory_r64(function.code, 4, 488, 0);
    x64_mov_r64_imm64(function.code, 1, cast(u64, 65001));
    x64_mov_r64_imm64(function.code, 2, cast(u64, 8));
    x64_mov_r64_memory(function.code, 8, 4, 480);
    x64_mov_r64_memory(function.code, 9, 4, 488);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 32, 0); x64_mov_memory_r64(function.code, 4, 40, 0);
    native_import(function, 15); native_runtime_nonzero(function);
    x64_mov_memory_r64(function.code, 4, 496, 0);
    x64_mov_r64_r64(function.code, 8, 0); x64_add_r64_r64(function.code, 8, 8);
    x64_add_r64_imm8(function.code, 8, 8);
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB in UTF-8 path conversion\n");
    x64_mov_memory_r64(function.code, 4, 504, 0);
    x64_mov_r64_imm64(function.code, 1, cast(u64, 65001));
    x64_mov_r64_imm64(function.code, 2, cast(u64, 8));
    x64_mov_r64_memory(function.code, 8, 4, 480);
    x64_mov_r64_memory(function.code, 9, 4, 488);
    x64_mov_r64_memory(function.code, 0, 4, 504); x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_r64_memory(function.code, 0, 4, 496); x64_mov_memory_r64(function.code, 4, 40, 0);
    native_import(function, 15); native_runtime_nonzero(function);
    x64_mov_r64_memory(function.code, 11, 4, 504);
    x64_mov_r64_memory(function.code, 10, 4, 496); x64_add_r64_r64(function.code, 10, 10);
    x64_add_r64_r64(function.code, 11, 10);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0)); x64_mov_memory_r64(function.code, 11, 0, 0);
}

// Read one Content-Length-framed JSON-RPC request from standard input. The
// hosted C runtime used this internal file name as a transport hook; the native
// compiler owns the equivalent pipe reader so `openc lsp --stdio` has no CRT.
