import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe void native_compiler_record_address(ref IrContext context,
    ref NativeFunction function, usize instruction) {
    native_load(function, d_operand_value(context, instruction, 0), 11);
    native_load(function, d_operand_value(context, instruction, 1), 0);
    x64_mov_r64_imm64(function.code, 10, cast(u64, 40));
    x64_emit_rex(function.code, true, 0, 0, 10);
    x64_emit_u8(function.code, 15); x64_emit_u8(function.code, 175);
    x64_emit_register_modrm(function.code, 0, 10);
    x64_add_r64_r64(function.code, 11, 0);
    native_load(function, d_operand_value(context, instruction, 2), 0);
    x64_shift_r64_imm8(function.code, 4, 0, 3);
    x64_add_r64_r64(function.code, 11, 0);
}

unsafe void native_compiler_text_match(ref IrContext context,
    ref NativeFunction function, usize instruction, usize result,
    bool exact_length) {
    usize expected_operand = 2;
    if exact_length { expected_operand = 3; }
    usize source = d_operand_value(context, instruction, 0);
    usize expected = d_operand_value(context, instruction, expected_operand);
    native_load(function, source, 10);
    native_load(function, expected, 11);
    x64_mov_r64_memory(function.code, 9, 4,
        native_slot(function, expected) + 8);
    usize bad_length = 0;
    if exact_length {
        native_load(function, d_operand_value(context, instruction, 2), 0);
        x64_cmp_r64_r64(function.code, 0, 9);
        bad_length = native_skip(function.code, 5);
    }
    native_load(function, d_operand_value(context, instruction, 1), 0);
    x64_mov_r64_memory(function.code, 8, 4,
        native_slot(function, source) + 8);
    x64_cmp_r64_r64(function.code, 0, 8);
    usize bad_start = native_skip(function.code, 7);
    x64_binary_r64_r64(function.code, 41, 8, 0);
    x64_cmp_r64_r64(function.code, 9, 8);
    usize bad_count = native_skip(function.code, 7);
    x64_add_r64_r64(function.code, 10, 0);

    usize word_loop = function.code.bytes.length;
    x64_alu_r64_imm8(function.code, 7, 9, 8);
    usize byte_tail = native_skip(function.code, 2);
    x64_mov_r64_memory(function.code, 0, 10, 0);
    x64_mov_r64_memory(function.code, 8, 11, 0);
    x64_cmp_r64_r64(function.code, 0, 8);
    usize bad_word = native_skip(function.code, 5);
    x64_add_r64_imm8(function.code, 10, 8);
    x64_add_r64_imm8(function.code, 11, 8);
    x64_alu_r64_imm8(function.code, 5, 9, 8);
    usize repeat_words = native_jump(function.code);
    x64_patch_u32(function.code, repeat_words,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_words + 4 - word_loop)));
    native_skip_end(function.code, byte_tail);

    usize byte_loop = function.code.bytes.length;
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 201);
    usize equal = native_skip(function.code, 4);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 2);
    x64_emit_u8(function.code, 69); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 3);
    x64_cmp_r64_r64(function.code, 0, 8);
    usize bad_byte = native_skip(function.code, 5);
    x64_add_r64_imm8(function.code, 10, 1);
    x64_add_r64_imm8(function.code, 11, 1);
    x64_alu_r64_imm8(function.code, 5, 9, 1);
    usize repeat_bytes = native_jump(function.code);
    x64_patch_u32(function.code, repeat_bytes,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_bytes + 4 - byte_loop)));
    native_skip_end(function.code, equal);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    usize completed = native_jump(function.code);
    if exact_length { native_skip_end(function.code, bad_length); }
    native_skip_end(function.code, bad_start);
    native_skip_end(function.code, bad_count);
    native_skip_end(function.code, bad_word);
    native_skip_end(function.code, bad_byte);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    native_skip_end(function.code, completed);
    native_store(function, result, 0);
}
