import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe void native_text_scalar_slice(ref IrContext context, ref NativeFunction function,
    usize instruction, usize result) {
    usize value = d_operand_value(context, instruction, 0);
    native_load(function, value, 8);
    x64_mov_r64_memory(function.code, 9, 4, native_slot(function, value) + 8);
    native_load(function, d_operand_value(context, instruction, 1), 0);
    x64_mov_memory_r64(function.code, 4, 360, 0);
    native_load(function, d_operand_value(context, instruction, 2), 11);
    x64_mov_memory_r64(function.code, 4, 368, 11);
    x64_cmp_r64_r64(function.code, 0, 11); native_require(function.code, 6);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 376, 0);
    x64_mov_memory_r64(function.code, 4, 384, 0);
    x64_mov_r64_imm64(function.code, 10, cast(u64, 0));
    usize loop_start = function.code.bytes.length;
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 201); usize at_end = native_skip(function.code, 4);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 0);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 37);
    x64_emit_u32(function.code, 192);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 128));
    x64_cmp_r64_r64(function.code, 0, 11); usize continuation = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 11, 4, 360);
    x64_cmp_r64_r64(function.code, 10, 11); usize not_lower = native_skip(function.code, 5);
    x64_mov_memory_r64(function.code, 4, 376, 8); native_skip_end(function.code, not_lower);
    x64_mov_r64_memory(function.code, 11, 4, 368);
    x64_cmp_r64_r64(function.code, 10, 11); usize not_upper = native_skip(function.code, 5);
    x64_mov_memory_r64(function.code, 4, 384, 8); native_skip_end(function.code, not_upper);
    x64_add_r64_imm8(function.code, 10, 1); native_skip_end(function.code, continuation);
    x64_add_r64_imm8(function.code, 8, 1);
    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 255); x64_emit_u8(function.code, 201);
    usize repeat = native_jump(function.code);
    x64_patch_u32(function.code, repeat, cast(u32, cast(u64, 4294967296) -
        cast(u64, repeat + 4 - loop_start)));
    native_skip_end(function.code, at_end);
    x64_mov_r64_memory(function.code, 11, 4, 360);
    x64_cmp_r64_r64(function.code, 10, 11); usize end_not_lower = native_skip(function.code, 5);
    x64_mov_memory_r64(function.code, 4, 376, 8); native_skip_end(function.code, end_not_lower);
    x64_mov_r64_memory(function.code, 11, 4, 368);
    x64_cmp_r64_r64(function.code, 10, 11); usize end_not_upper = native_skip(function.code, 5);
    x64_mov_memory_r64(function.code, 4, 384, 8); native_skip_end(function.code, end_not_upper);
    x64_cmp_r64_r64(function.code, 11, 10); native_require(function.code, 6);
    usize out_value = d_operand_value(context, instruction, 3);
    native_output_address(function, out_value, 11);
    x64_mov_r64_memory(function.code, 0, 4, 376);
    x64_mov_memory_r64(function.code, 11, 0, 0);
    x64_mov_r64_memory(function.code, 10, 4, 384);
    x64_binary_r64_r64(function.code, 41, 10, 0);
    x64_mov_memory_r64(function.code, 11, 8, 10);
    native_status_success(function, result);
}
