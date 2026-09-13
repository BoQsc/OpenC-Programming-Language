import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

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
    // body=648, body-read=656, header-bytes=664.
    x64_mov_memory_r64(function.code, 4, 608, 0);
    x64_mov_memory_r64(function.code, 4, 624, 0);
    x64_mov_memory_r64(function.code, 4, 648, 0);
    x64_mov_memory_r64(function.code, 4, 656, 0);
    x64_mov_memory_r64(function.code, 4, 664, 0);
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
    x64_mov_r64_memory(function.code, 10, 4, 664);
    x64_add_r64_imm8(function.code, 10, 1);
    x64_mov_memory_r64(function.code, 4, 664, 10);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 8192));
    x64_cmp_r64_r64(function.code, 10, 11);
    usize header_too_large = native_skip(function.code, 7);

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
    // Match the public LSP document/message ceiling. Oversized editor input is
    // rejected before allocating a body buffer.
    x64_mov_r64_imm64(function.code, 11, cast(u64, 4194304));
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
    native_skip_end(function.code, header_too_large);
    native_skip_end(function.code, missing_length);
    native_skip_end(function.code, length_too_large);
    native_skip_end(function.code, body_read_failed);
    native_skip_end(function.code, body_empty);
    x64_mov_r64_memory(function.code, 8, 4, 648);
    native_heap_free_r8(function);
    native_status_failure(function, result, 1);
    native_skip_end(function.code, lsp_finished);
}
