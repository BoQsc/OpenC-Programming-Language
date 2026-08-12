import system.memory;

unsafe X64Code x64_code_create(usize byte_capacity, usize relocation_capacity) {
    PackedBuffer relocations = PackedBuffer{
        length = 0,
        capacity = relocation_capacity
    };
    return X64Code{
        bytes = d_buffer_create(byte_capacity),
        relocation_data = memory.alloc(
            relocation_capacity * record_stride()
        ),
        relocations = relocations,
        ok = true
    };
}

unsafe void x64_code_destroy(ref X64Code code) {
    memory.free(code.relocation_data);
    d_buffer_destroy(code.bytes);
    code.relocations.length = 0;
    code.relocations.capacity = 0;
    code.ok = false;
}

unsafe void x64_emit_u8(ref X64Code code, usize value) {
    if value > 255 || !code.ok { code.ok = false; return; }
    d_put_byte(code.bytes, cast(u8, value));
    if !code.bytes.ok { code.ok = false; }
}

unsafe void x64_emit_u16(ref X64Code code, usize value) {
    x64_emit_u8(code, value & 255);
    x64_emit_u8(code, (value >> 8) & 255);
}

unsafe void x64_emit_u32(ref X64Code code, usize value) {
    usize shift = 0;
    while shift < 32 {
        x64_emit_u8(code, (value >> shift) & 255);
        shift = shift + 8;
    }
}

unsafe void x64_emit_u64(ref X64Code code, u64 value) {
    usize shift = 0;
    while shift < 64 {
        x64_emit_u8(code, cast(usize, (value >> shift) & 255));
        shift = shift + 8;
    }
}

unsafe void x64_patch_u32(ref X64Code code, usize offset, u32 value) {
    if offset > code.bytes.length || code.bytes.length - offset < 4 {
        code.ok = false;
        return;
    }
    usize shift = 0;
    while shift < 32 {
        *(code.bytes.data + offset + shift / 8) = cast_unchecked(
            byte, cast(u8, (value >> shift) & 255)
        );
        shift = shift + 8;
    }
}

unsafe void x64_patch_u64(ref X64Code code, usize offset, u64 value) {
    if offset > code.bytes.length || code.bytes.length - offset < 8 {
        code.ok = false;
        return;
    }
    usize shift = 0;
    while shift < 64 {
        *(code.bytes.data + offset + shift / 8) = cast_unchecked(
            byte, cast(u8, (value >> shift) & 255)
        );
        shift = shift + 8;
    }
}

unsafe void x64_add_relocation(
    ref X64Code code,
    usize offset,
    usize kind,
    usize symbol,
    i64 addend,
    usize width
) {
    if code.relocations.length >= code.relocations.capacity {
        code.ok = false;
        return;
    }
    usize record = code.relocations.length;
    write_record_field(code.relocation_data, record, 0, offset);
    write_record_field(code.relocation_data, record, 1, kind);
    write_record_field(code.relocation_data, record, 2, symbol);
    usize encoded_addend = 0;
    if addend < 0 {
        encoded_addend = (cast(usize, 1) << cast(usize, 63)) |
            cast(usize, 0 - addend);
    } else {
        encoded_addend = cast(usize, addend);
    }
    write_record_field(code.relocation_data, record, 3, encoded_addend);
    write_record_field(code.relocation_data, record, 4, width);
    code.relocations.length = code.relocations.length + 1;
}

unsafe void x64_emit_rex(
    ref X64Code code,
    bool wide,
    usize register_field,
    usize index_field,
    usize base_field
) {
    if register_field > 15 || index_field > 15 || base_field > 15 {
        code.ok = false;
        return;
    }
    usize rex = 64;
    if wide { rex = rex + 8; }
    if register_field >= 8 { rex = rex + 4; }
    if index_field >= 8 { rex = rex + 2; }
    if base_field >= 8 { rex = rex + 1; }
    if rex != 64 { x64_emit_u8(code, rex); }
}

unsafe void x64_emit_register_modrm(
    ref X64Code code,
    usize register_field,
    usize operand_register
) {
    if register_field > 15 || operand_register > 15 {
        code.ok = false;
        return;
    }
    x64_emit_u8(
        code,
        192 + (register_field & 7) * 8 + (operand_register & 7)
    );
}

unsafe void x64_emit_memory_modrm(
    ref X64Code code,
    usize register_field,
    usize base_register,
    usize displacement
) {
    if register_field > 15 || base_register > 15 ||
        displacement > cast(usize, 2147483647) {
        code.ok = false;
        return;
    }
    usize base = base_register & 7;
    usize mode = 0;
    if displacement == 0 && base != 5 {
        mode = 0;
    } else if displacement <= 127 {
        mode = 1;
    } else {
        mode = 2;
    }
    x64_emit_u8(code, mode * 64 + (register_field & 7) * 8 + base);
    if base == 4 { x64_emit_u8(code, 36); }
    if mode == 1 { x64_emit_u8(code, displacement); }
    if mode == 2 || (mode == 0 && base == 5) {
        x64_emit_u32(code, displacement);
    }
}

unsafe void x64_nop(ref X64Code code) { x64_emit_u8(code, 144); }
unsafe void x64_ret(ref X64Code code) { x64_emit_u8(code, 195); }

unsafe void x64_push_r64(ref X64Code code, usize register_code) {
    if register_code > 15 { code.ok = false; return; }
    if register_code >= 8 { x64_emit_u8(code, 65); }
    x64_emit_u8(code, 80 + (register_code & 7));
}

unsafe void x64_pop_r64(ref X64Code code, usize register_code) {
    if register_code > 15 { code.ok = false; return; }
    if register_code >= 8 { x64_emit_u8(code, 65); }
    x64_emit_u8(code, 88 + (register_code & 7));
}

unsafe void x64_mov_r64_r64(
    ref X64Code code,
    usize destination,
    usize source
) {
    x64_emit_rex(code, true, source, 0, destination);
    x64_emit_u8(code, 137);
    x64_emit_register_modrm(code, source, destination);
}

unsafe void x64_mov_r64_memory(
    ref X64Code code,
    usize destination,
    usize base,
    usize displacement
) {
    x64_emit_rex(code, true, destination, 0, base);
    x64_emit_u8(code, 139);
    x64_emit_memory_modrm(code, destination, base, displacement);
}

unsafe void x64_mov_memory_r64(
    ref X64Code code,
    usize base,
    usize displacement,
    usize source
) {
    x64_emit_rex(code, true, source, 0, base);
    x64_emit_u8(code, 137);
    x64_emit_memory_modrm(code, source, base, displacement);
}

unsafe void x64_mov_r64_imm64(
    ref X64Code code,
    usize destination,
    u64 value
) {
    x64_emit_rex(code, true, 0, 0, destination);
    x64_emit_u8(code, 184 + (destination & 7));
    x64_emit_u64(code, value);
}

unsafe void x64_mov_r64_symbol(
    ref X64Code code,
    usize destination,
    usize symbol,
    i64 addend
) {
    x64_emit_rex(code, true, 0, 0, destination);
    x64_emit_u8(code, 184 + (destination & 7));
    usize offset = code.bytes.length;
    x64_emit_u64(code, cast(u64, 0));
    x64_add_relocation(
        code, offset, x64_relocation_absolute64(), symbol, addend, 8
    );
}

unsafe void x64_binary_r64_r64(
    ref X64Code code,
    usize opcode,
    usize destination,
    usize source
) {
    x64_emit_rex(code, true, source, 0, destination);
    x64_emit_u8(code, opcode);
    x64_emit_register_modrm(code, source, destination);
}

unsafe void x64_add_r64_r64(
    ref X64Code code,
    usize destination,
    usize source
) {
    x64_binary_r64_r64(code, 1, destination, source);
}

unsafe void x64_xor_r64_r64(
    ref X64Code code,
    usize destination,
    usize source
) {
    x64_binary_r64_r64(code, 49, destination, source);
}

unsafe void x64_cmp_r64_r64(
    ref X64Code code,
    usize left,
    usize right
) {
    x64_binary_r64_r64(code, 57, left, right);
}

unsafe void x64_add_r64_memory(
    ref X64Code code,
    usize destination,
    usize base,
    usize displacement
) {
    x64_emit_rex(code, true, destination, 0, base);
    x64_emit_u8(code, 3);
    x64_emit_memory_modrm(code, destination, base, displacement);
}

unsafe void x64_alu_r64_imm8(
    ref X64Code code,
    usize operation,
    usize destination,
    usize immediate
) {
    if operation > 7 || immediate > 127 {
        code.ok = false;
        return;
    }
    x64_emit_rex(code, true, 0, 0, destination);
    x64_emit_u8(code, 131);
    x64_emit_register_modrm(code, operation, destination);
    x64_emit_u8(code, immediate);
}

unsafe void x64_add_r64_imm8(
    ref X64Code code,
    usize destination,
    usize immediate
) {
    x64_alu_r64_imm8(code, 0, destination, immediate);
}

unsafe void x64_and_r64_imm8(
    ref X64Code code,
    usize destination,
    usize immediate
) {
    x64_alu_r64_imm8(code, 4, destination, immediate);
}

unsafe void x64_sub_rsp(ref X64Code code, usize amount) {
    if amount <= 127 {
        x64_alu_r64_imm8(code, 5, win64_abi_register_rsp(), amount);
        return;
    }
    x64_emit_u8(code, 72);
    x64_emit_u8(code, 129);
    x64_emit_u8(code, 236);
    x64_emit_u32(code, amount);
}

unsafe void x64_add_rsp(ref X64Code code, usize amount) {
    if amount <= 127 {
        x64_alu_r64_imm8(code, 0, win64_abi_register_rsp(), amount);
        return;
    }
    x64_emit_u8(code, 72);
    x64_emit_u8(code, 129);
    x64_emit_u8(code, 196);
    x64_emit_u32(code, amount);
}

unsafe void x64_call_r64(ref X64Code code, usize register_code) {
    x64_emit_rex(code, false, 0, 0, register_code);
    x64_emit_u8(code, 255);
    x64_emit_register_modrm(code, 2, register_code);
}

unsafe void x64_call_symbol(
    ref X64Code code,
    usize symbol,
    i64 addend
) {
    x64_emit_u8(code, 232);
    usize offset = code.bytes.length;
    x64_emit_u32(code, 0);
    x64_add_relocation(
        code, offset, x64_relocation_relative32(), symbol, addend, 4
    );
}

unsafe void x64_jump_symbol(
    ref X64Code code,
    usize symbol,
    i64 addend
) {
    x64_emit_u8(code, 233);
    usize offset = code.bytes.length;
    x64_emit_u32(code, 0);
    x64_add_relocation(
        code, offset, x64_relocation_relative32(), symbol, addend, 4
    );
}

unsafe bool x64_apply_relative32(
    ref X64Code code,
    usize relocation,
    usize target_offset
) {
    if relocation >= code.relocations.length ||
        read_record_field(code.relocation_data, relocation, 1) !=
            x64_relocation_relative32() {
        code.ok = false;
        return false;
    }
    usize offset = read_record_field(
        code.relocation_data, relocation, 0
    );
    i64 displacement = cast(i64, target_offset) - cast(i64, offset + 4);
    if displacement < cast(i64, -2147483647) - 1 ||
        displacement > cast(i64, 2147483647) {
        code.ok = false;
        return false;
    }
    u32 encoded = 0;
    if displacement < 0 {
        u64 magnitude = cast(u64, 0 - displacement);
        encoded = cast(u32, cast(u64, 4294967296) - magnitude);
    } else {
        encoded = cast(u32, displacement);
    }
    x64_patch_u32(code, offset, encoded);
    return code.ok;
}

unsafe bool x64_apply_absolute64(
    ref X64Code code,
    usize relocation,
    u64 value
) {
    if relocation >= code.relocations.length ||
        read_record_field(code.relocation_data, relocation, 1) !=
            x64_relocation_absolute64() {
        code.ok = false;
        return false;
    }
    x64_patch_u64(
        code,
        read_record_field(code.relocation_data, relocation, 0),
        value
    );
    return code.ok;
}

unsafe void x64_addsd_xmm_xmm(
    ref X64Code code,
    usize destination,
    usize source
) {
    x64_emit_u8(code, 242);
    x64_emit_rex(code, false, destination, 0, source);
    x64_emit_u8(code, 15);
    x64_emit_u8(code, 88);
    x64_emit_register_modrm(code, destination, source);
}

unsafe void x64_movq_r64_xmm(
    ref X64Code code,
    usize destination,
    usize source
) {
    x64_emit_u8(code, 102);
    x64_emit_rex(code, true, source, 0, destination);
    x64_emit_u8(code, 15);
    x64_emit_u8(code, 126);
    x64_emit_register_modrm(code, source, destination);
}

unsafe void x64_movq_xmm_r64(
    ref X64Code code,
    usize destination,
    usize source
) {
    x64_emit_u8(code, 102);
    x64_emit_rex(code, true, destination, 0, source);
    x64_emit_u8(code, 15);
    x64_emit_u8(code, 110);
    x64_emit_register_modrm(code, destination, source);
}

unsafe void x64_movdqu_memory_xmm(
    ref X64Code code,
    usize base,
    usize displacement,
    usize source
) {
    x64_emit_u8(code, 243);
    x64_emit_rex(code, false, source, 0, base);
    x64_emit_u8(code, 15);
    x64_emit_u8(code, 127);
    x64_emit_memory_modrm(code, source, base, displacement);
}

unsafe void x64_movdqu_xmm_memory(
    ref X64Code code,
    usize destination,
    usize base,
    usize displacement
) {
    x64_emit_u8(code, 243);
    x64_emit_rex(code, false, destination, 0, base);
    x64_emit_u8(code, 15);
    x64_emit_u8(code, 111);
    x64_emit_memory_modrm(code, destination, base, displacement);
}

unsafe void x64_set_equal_al(ref X64Code code) {
    x64_emit_u8(code, 15);
    x64_emit_u8(code, 148);
    x64_emit_u8(code, 192);
}

unsafe void x64_zero_extend_al_eax(ref X64Code code) {
    x64_emit_u8(code, 15);
    x64_emit_u8(code, 182);
    x64_emit_u8(code, 192);
}

unsafe void x64_put_hex(ref DBuffer output, ref DBuffer bytes) {
    usize index = 0;
    while index < bytes.length {
        usize value = cast(
            usize, cast_unchecked(u8, *(bytes.data + index))
        );
        d_put(output, project_hex_digit(value >> 4));
        d_put(output, project_hex_digit(value & 15));
        index = index + 1;
    }
}

unsafe void x64_copy_bytes(ref DBuffer output, ref DBuffer bytes) {
    usize index = 0;
    while index < bytes.length {
        d_put_byte(output, cast_unchecked(u8, *(bytes.data + index)));
        index = index + 1;
    }
}
