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
unsafe void native_lsp_read_frame(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize result
) {
    usize output_value = d_operand_value(context, instruction, 0);
    native_output_address(function, output_value, 11);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 11, 0, 0);
    x64_mov_memory_r64(function.code, 11, 8, 0);
    // Scratch: handle=600, length=608, parse-first-line=616,
    // consecutive-linefeeds=624, bytes-read=632, byte=640,
    // body=648, body-read=656.
    x64_mov_memory_r64(function.code, 4, 608, 0);
    x64_mov_memory_r64(function.code, 4, 624, 0);
    x64_mov_memory_r64(function.code, 4, 648, 0);
    x64_mov_memory_r64(function.code, 4, 656, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    x64_mov_memory_r64(function.code, 4, 616, 0);
    x64_mov_r64_imm64(
        function.code, 1, pe32_u64_minus_eleven() + cast(u64, 1)
    );
    native_import(function, 8);
    x64_mov_memory_r64(function.code, 4, 600, 0);

    usize header_loop = function.code.bytes.length;
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 632, 0);
    x64_mov_memory_r64(function.code, 4, 640, 0);
    x64_mov_r64_memory(function.code, 1, 4, 600);
    native_stack_address(function, 640, 2);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 1));
    native_stack_address(function, 632, 9);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    native_import(function, 12);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize header_read_failed = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 0, 4, 632);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize header_empty = native_skip(function.code, 4);

    // Only the first header line contributes decimal digits. This accepts the
    // case-insensitive Content-Length spelling already enforced by the public
    // LSP client contract while ignoring digits in optional later headers.
    x64_mov_r64_memory(function.code, 10, 4, 616);
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 210);
    usize skip_digit = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 0, 4, 640);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 48));
    x64_cmp_r64_r64(function.code, 0, 11);
    usize below_digit = native_skip(function.code, 2);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 57));
    x64_cmp_r64_r64(function.code, 0, 11);
    usize above_digit = native_skip(function.code, 7);
    x64_alu_r64_imm8(function.code, 5, 0, 48);
    x64_mov_r64_memory(function.code, 10, 4, 608);
    x64_mov_r64_r64(function.code, 11, 10);
    x64_shift_r64_imm8(function.code, 4, 10, 3);
    x64_shift_r64_imm8(function.code, 4, 11, 1);
    x64_add_r64_r64(function.code, 10, 11);
    x64_add_r64_r64(function.code, 10, 0);
    x64_mov_memory_r64(function.code, 4, 608, 10);
    native_skip_end(function.code, below_digit);
    native_skip_end(function.code, above_digit);
    x64_mov_r64_memory(function.code, 0, 4, 640);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 13));
    x64_cmp_r64_r64(function.code, 0, 11);
    usize not_first_cr = native_skip(function.code, 5);
    x64_mov_r64_imm64(function.code, 10, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 616, 10);
    native_skip_end(function.code, not_first_cr);
    native_skip_end(function.code, skip_digit);

    // Two linefeeds with only the separating carriage return terminate the
    // header block. Any other byte resets the small state machine.
    x64_mov_r64_memory(function.code, 0, 4, 640);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 10));
    x64_cmp_r64_r64(function.code, 0, 11);
    usize not_linefeed = native_skip(function.code, 5);
    x64_mov_r64_memory(function.code, 10, 4, 624);
    x64_add_r64_imm8(function.code, 10, 1);
    x64_mov_memory_r64(function.code, 4, 624, 10);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 2));
    x64_cmp_r64_r64(function.code, 10, 11);
    usize header_not_done = native_skip(function.code, 5);
    usize header_done = native_jump(function.code);
    native_skip_end(function.code, header_not_done);
    usize repeat_header_after_lf = native_jump(function.code);
    x64_patch_u32(function.code, repeat_header_after_lf,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_header_after_lf + 4 - header_loop)));
    native_skip_end(function.code, not_linefeed);
    x64_mov_r64_memory(function.code, 0, 4, 640);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 13));
    x64_cmp_r64_r64(function.code, 0, 11);
    usize not_carriage_return = native_skip(function.code, 5);
    usize repeat_header_after_cr = native_jump(function.code);
    x64_patch_u32(function.code, repeat_header_after_cr,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_header_after_cr + 4 - header_loop)));
    native_skip_end(function.code, not_carriage_return);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 624, 0);
    usize repeat_header = native_jump(function.code);
    x64_patch_u32(function.code, repeat_header,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_header + 4 - header_loop)));

    native_skip_end(function.code, header_done);
    x64_mov_r64_memory(function.code, 10, 4, 608);
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 210);
    usize missing_length = native_skip(function.code, 4);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 16777216));
    x64_cmp_r64_r64(function.code, 10, 11);
    usize length_too_large = native_skip(function.code, 7);
    x64_mov_r64_r64(function.code, 8, 10);
    x64_add_r64_imm8(function.code, 8, 1);
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB reading LSP frame\n");
    x64_mov_memory_r64(function.code, 4, 648, 0);

    usize body_loop = function.code.bytes.length;
    x64_mov_r64_memory(function.code, 10, 4, 656);
    x64_mov_r64_memory(function.code, 11, 4, 608);
    x64_cmp_r64_r64(function.code, 10, 11);
    usize body_done = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 1, 4, 600);
    x64_mov_r64_memory(function.code, 2, 4, 648);
    x64_add_r64_r64(function.code, 2, 10);
    x64_mov_r64_r64(function.code, 8, 11);
    x64_binary_r64_r64(function.code, 41, 8, 10);
    native_stack_address(function, 632, 9);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 632, 0);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    native_import(function, 12);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize body_read_failed = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 0, 4, 632);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize body_empty = native_skip(function.code, 4);
    x64_add_r64_memory(function.code, 0, 4, 656);
    x64_mov_memory_r64(function.code, 4, 656, 0);
    usize repeat_body = native_jump(function.code);
    x64_patch_u32(function.code, repeat_body,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_body + 4 - body_loop)));

    native_skip_end(function.code, body_done);
    x64_mov_r64_memory(function.code, 11, 4, 648);
    x64_add_r64_memory(function.code, 11, 4, 608);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    native_runtime_store_byte(function, 11, 0);
    native_output_address(function, output_value, 11);
    x64_mov_r64_memory(function.code, 0, 4, 648);
    x64_mov_memory_r64(function.code, 11, 0, 0);
    x64_mov_r64_memory(function.code, 0, 4, 608);
    x64_mov_memory_r64(function.code, 11, 8, 0);
    native_status_success(function, result);
    usize lsp_finished = native_jump(function.code);

    native_skip_end(function.code, header_read_failed);
    native_skip_end(function.code, header_empty);
    native_skip_end(function.code, missing_length);
    native_skip_end(function.code, length_too_large);
    native_skip_end(function.code, body_read_failed);
    native_skip_end(function.code, body_empty);
    x64_mov_r64_memory(function.code, 8, 4, 648);
    native_heap_free_r8(function);
    native_status_failure(function, result, 1);
    native_skip_end(function.code, lsp_finished);
}

unsafe void native_file_read(ref IrContext context, ref NativeFunction function,
    usize instruction, usize result, bool raw_outputs) {
    native_utf8_path(function, d_operand_value(context, instruction, 0));
    x64_mov_r64_memory(function.code, 1, 4, 504);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 2147483648));
    x64_mov_r64_imm64(function.code, 8, cast(u64, 7));
    x64_mov_r64_imm64(function.code, 9, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 0, cast(u64, 3)); x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 128)); x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0)); x64_mov_memory_r64(function.code, 4, 48, 0);
    native_import(function, 1);
    x64_mov_r64_imm64(function.code, 11, ~cast(u64, 0)); x64_cmp_r64_r64(function.code, 0, 11);
    usize valid_handle = native_skip(function.code, 5);
    x64_mov_r64_memory(function.code, 8, 4, 504); native_heap_free_r8(function);
    native_status_failure(function, result, 1);
    usize read_finished = native_jump(function.code);
    native_skip_end(function.code, valid_handle);
    x64_mov_memory_r64(function.code, 4, 512, 0);
    x64_mov_r64_memory(function.code, 8, 4, 504); native_heap_free_r8(function);
    x64_mov_r64_memory(function.code, 1, 4, 512);
    x64_emit_rex(function.code, true, 2, 0, 4); x64_emit_u8(function.code, 141);
    x64_emit_memory_modrm(function.code, 2, 4, 520);
    native_import(function, 18); native_runtime_nonzero(function);
    x64_mov_r64_memory(function.code, 8, 4, 520); x64_add_r64_imm8(function.code, 8, 8);
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB in file.read buffer\n");
    x64_mov_memory_r64(function.code, 4, 536, 0);
    x64_mov_r64_memory(function.code, 1, 4, 512);
    x64_mov_r64_memory(function.code, 2, 4, 536);
    x64_mov_r64_memory(function.code, 8, 4, 520);
    x64_emit_rex(function.code, true, 9, 0, 4); x64_emit_u8(function.code, 141);
    x64_emit_memory_modrm(function.code, 9, 4, 528);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0)); x64_mov_memory_r64(function.code, 4, 528, 0);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    native_import(function, 12); native_runtime_nonzero(function);
    x64_mov_r64_memory(function.code, 1, 4, 512); native_import(function, 0);
    x64_mov_r64_memory(function.code, 11, 4, 536);
    x64_mov_r64_memory(function.code, 10, 4, 528); x64_add_r64_r64(function.code, 11, 10);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0)); x64_mov_memory_r64(function.code, 11, 0, 0);
    if raw_outputs {
        usize data_value = d_operand_value(context, instruction, 1);
        native_output_address(function, data_value, 11);
        x64_mov_r64_memory(function.code, 0, 4, 536); x64_mov_memory_r64(function.code, 11, 0, 0);
        usize length_value = d_operand_value(context, instruction, 2);
        native_output_address(function, length_value, 11);
        x64_mov_r64_memory(function.code, 0, 4, 528); x64_mov_memory_r64(function.code, 11, 0, 0);
    } else {
        usize output_value = d_operand_value(context, instruction, 1);
        native_output_address(function, output_value, 11);
        x64_mov_r64_memory(function.code, 0, 4, 536); x64_mov_memory_r64(function.code, 11, 0, 0);
        x64_mov_r64_memory(function.code, 0, 4, 528); x64_mov_memory_r64(function.code, 11, 8, 0);
    }
    native_status_success(function, result);
    native_skip_end(function.code, read_finished);
}

// A direct-mapped cache keeps source texts process-owned for the compiler
// lifetime. The 262,144 entries are allocated lazily; collisions remain correct
// (they reread and replace the entry) and cannot create an unbounded table.
unsafe void native_file_read_cached(ref IrContext context, ref NativeFunction function,
    usize instruction, usize result) {
    usize path_value = d_operand_value(context, instruction, 0);
    native_data_address(function, 40, 11);
    x64_mov_r64_memory(function.code, 10, 11, 0);
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 210); usize table_ready = native_skip(function.code, 5);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 10485760));
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB in file text cache\n");
    x64_mov_r64_r64(function.code, 10, 0);
    native_data_address(function, 40, 11);
    x64_mov_memory_r64(function.code, 11, 0, 10);
    x64_mov_r64_r64(function.code, 8, 10);
    x64_mov_r64_imm64(function.code, 9, cast(u64, 10485760));
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    usize clear_loop = function.code.bytes.length;
    native_runtime_store_byte(function, 8, 0);
    x64_add_r64_imm8(function.code, 8, 1);
    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 255); x64_emit_u8(function.code, 201);
    x64_emit_u8(function.code, 15); x64_emit_u8(function.code, 133);
    usize repeat_clear = function.code.bytes.length; x64_emit_u32(function.code, 0);
    x64_patch_u32(function.code, repeat_clear, cast(u32, cast(u64, 4294967296) -
        cast(u64, repeat_clear + 4 - clear_loop)));
    native_skip_end(function.code, table_ready);

    native_load(function, path_value, 8);
    x64_mov_r64_memory(function.code, 9, 4, native_slot(function, path_value) + 8);
    x64_mov_r64_imm64(function.code, 10, cast(u64, 5381));
    usize hash_loop = function.code.bytes.length;
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 201); usize hash_done = native_skip(function.code, 4);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 0);
    x64_mov_r64_r64(function.code, 11, 10);
    x64_shift_r64_imm8(function.code, 4, 11, 5);
    x64_add_r64_r64(function.code, 10, 11);
    x64_binary_r64_r64(function.code, 49, 10, 0);
    x64_add_r64_imm8(function.code, 8, 1);
    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 255); x64_emit_u8(function.code, 201);
    usize repeat_hash = native_jump(function.code);
    x64_patch_u32(function.code, repeat_hash, cast(u32, cast(u64, 4294967296) -
        cast(u64, repeat_hash + 4 - hash_loop)));
    native_skip_end(function.code, hash_done);
    x64_mov_memory_r64(function.code, 4, 552, 10);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 262143));
    x64_binary_r64_r64(function.code, 33, 10, 11);
    x64_mov_r64_r64(function.code, 11, 10);
    x64_shift_r64_imm8(function.code, 4, 10, 5);
    x64_shift_r64_imm8(function.code, 4, 11, 3);
    x64_add_r64_r64(function.code, 10, 11);
    native_data_address(function, 40, 11);
    x64_mov_r64_memory(function.code, 11, 11, 0);
    x64_add_r64_r64(function.code, 10, 11);
    x64_mov_memory_r64(function.code, 4, 544, 10);

    x64_mov_r64_memory(function.code, 8, 10, 8);
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192); usize miss_empty = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 0, 10, 0);
    x64_mov_r64_memory(function.code, 11, 4, 552);
    x64_cmp_r64_r64(function.code, 0, 11); usize miss_hash = native_skip(function.code, 5);
    x64_mov_r64_memory(function.code, 0, 10, 16);
    x64_mov_r64_memory(function.code, 9, 4, native_slot(function, path_value) + 8);
    x64_cmp_r64_r64(function.code, 0, 9); usize miss_length = native_skip(function.code, 5);
    native_load(function, path_value, 11);
    usize compare_loop = function.code.bytes.length;
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 201); usize cache_hit = native_skip(function.code, 4);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 0);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 11);
    x64_cmp_r64_r64(function.code, 0, 1); usize miss_byte = native_skip(function.code, 5);
    x64_add_r64_imm8(function.code, 8, 1); x64_add_r64_imm8(function.code, 11, 1);
    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 255); x64_emit_u8(function.code, 201);
    usize repeat_compare = native_jump(function.code);
    x64_patch_u32(function.code, repeat_compare, cast(u32, cast(u64, 4294967296) -
        cast(u64, repeat_compare + 4 - compare_loop)));
    native_skip_end(function.code, cache_hit);
    native_counter_increment(function, 56);
    x64_mov_r64_memory(function.code, 10, 4, 544);
    usize output_value = d_operand_value(context, instruction, 1);
    native_output_address(function, output_value, 11);
    x64_mov_r64_memory(function.code, 0, 10, 24); x64_mov_memory_r64(function.code, 11, 0, 0);
    x64_mov_r64_memory(function.code, 0, 10, 32); x64_mov_memory_r64(function.code, 11, 8, 0);
    native_status_success(function, result);
    usize finished = native_jump(function.code);

    native_skip_end(function.code, miss_empty); native_skip_end(function.code, miss_hash);
    native_skip_end(function.code, miss_length); native_skip_end(function.code, miss_byte);
    native_counter_increment(function, 64);
    native_file_read(context, function, instruction, result, false);
    native_load(function, result, 0);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192); usize read_failed = native_skip(function.code, 5);
    x64_mov_r64_memory(function.code, 10, 4, 544);
    x64_mov_r64_memory(function.code, 0, 4, 552); x64_mov_memory_r64(function.code, 10, 0, 0);
    native_load(function, path_value, 0); x64_mov_memory_r64(function.code, 10, 8, 0);
    x64_mov_r64_memory(function.code, 0, 4, native_slot(function, path_value) + 8);
    x64_mov_memory_r64(function.code, 10, 16, 0);
    native_output_address(function, output_value, 11);
    x64_mov_r64_memory(function.code, 0, 11, 0); x64_mov_memory_r64(function.code, 10, 24, 0);
    x64_mov_r64_memory(function.code, 0, 11, 8); x64_mov_memory_r64(function.code, 10, 32, 0);
    native_skip_end(function.code, read_failed); native_skip_end(function.code, finished);
}
