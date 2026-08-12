Win64AbiType win64_abi_type(
    usize kind,
    usize size,
    usize alignment,
    bool trivial
) {
    return Win64AbiType{
        kind = kind,
        size = size,
        alignment = alignment,
        trivial = trivial
    };
}

Win64AbiType win64_abi_integer(usize size) {
    return win64_abi_type(
        win64_abi_type_integer(), size, x64_min(size, 8), true
    );
}

Win64AbiType win64_abi_pointer() {
    return win64_abi_type(win64_abi_type_pointer(), 8, 8, true);
}

Win64AbiType win64_abi_float32() {
    return win64_abi_type(win64_abi_type_f32(), 4, 4, true);
}

Win64AbiType win64_abi_float64() {
    return win64_abi_type(win64_abi_type_f64(), 8, 8, true);
}

Win64AbiType win64_abi_aggregate(
    usize size,
    usize alignment,
    bool trivial
) {
    return win64_abi_type(
        win64_abi_type_aggregate(), size, alignment, trivial
    );
}

Win64AbiType win64_abi_vector128() {
    return win64_abi_type(win64_abi_type_vector128(), 16, 16, true);
}

bool win64_abi_is_float(ref Win64AbiType value) {
    return value.kind == win64_abi_type_f32() ||
        value.kind == win64_abi_type_f64();
}

bool win64_abi_direct_aggregate(ref Win64AbiType value) {
    if value.kind != win64_abi_type_aggregate() || !value.trivial {
        return false;
    }
    return value.size == 1 || value.size == 2 ||
        value.size == 4 || value.size == 8;
}

usize win64_abi_integer_argument_register(usize slot) {
    if slot == 0 { return win64_abi_register_rcx(); }
    if slot == 1 { return win64_abi_register_rdx(); }
    if slot == 2 { return win64_abi_register_r8(); }
    return win64_abi_register_r9();
}

Win64AbiLocation win64_abi_argument(
    ref Win64AbiType value,
    usize logical_index,
    bool hidden_return,
    bool variadic
) {
    usize slot = logical_index;
    if hidden_return { slot = slot + 1; }
    bool indirect = value.kind == win64_abi_type_vector128() ||
        (value.kind == win64_abi_type_aggregate() &&
         !win64_abi_direct_aggregate(value));
    bool floating = win64_abi_is_float(value) && !indirect;
    if slot < 4 {
        if floating {
            return Win64AbiLocation{
                kind = win64_abi_location_vector_register(),
                register_code = slot,
                stack_offset = slot * 8,
                indirect = false,
                duplicate_float_to_integer = variadic
            };
        }
        return Win64AbiLocation{
            kind = win64_abi_location_integer_register(),
            register_code = win64_abi_integer_argument_register(slot),
            stack_offset = slot * 8,
            indirect = indirect,
            duplicate_float_to_integer = false
        };
    }
    return Win64AbiLocation{
        kind = win64_abi_location_stack(),
        register_code = 0,
        stack_offset = 32 + (slot - 4) * 8,
        indirect = indirect,
        duplicate_float_to_integer = false
    };
}

Win64ReturnLocation win64_abi_return(ref Win64AbiType value) {
    if value.kind == win64_abi_type_void() || value.size == 0 {
        return Win64ReturnLocation{
            kind = win64_abi_location_none(),
            register_code = 0,
            hidden_pointer = false,
            shifts_arguments = false
        };
    }
    if win64_abi_is_float(value) ||
        value.kind == win64_abi_type_vector128() {
        return Win64ReturnLocation{
            kind = win64_abi_location_vector_register(),
            register_code = 0,
            hidden_pointer = false,
            shifts_arguments = false
        };
    }
    if value.kind == win64_abi_type_integer() ||
        value.kind == win64_abi_type_pointer() ||
        win64_abi_direct_aggregate(value) {
        return Win64ReturnLocation{
            kind = win64_abi_location_integer_register(),
            register_code = win64_abi_register_rax(),
            hidden_pointer = false,
            shifts_arguments = false
        };
    }
    return Win64ReturnLocation{
        kind = win64_abi_location_hidden_return(),
        register_code = win64_abi_register_rcx(),
        hidden_pointer = true,
        shifts_arguments = true
    };
}

bool win64_abi_integer_register_volatile(usize code) {
    return code == win64_abi_register_rax() ||
        code == win64_abi_register_rcx() ||
        code == win64_abi_register_rdx() ||
        code == win64_abi_register_r8() ||
        code == win64_abi_register_r9() ||
        code == win64_abi_register_r10() ||
        code == win64_abi_register_r11();
}

bool win64_abi_integer_register_nonvolatile(usize code) {
    return code == win64_abi_register_rbx() ||
        code == win64_abi_register_rsp() ||
        code == win64_abi_register_rbp() ||
        code == win64_abi_register_rsi() ||
        code == win64_abi_register_rdi() ||
        code == win64_abi_register_r12() ||
        code == win64_abi_register_r13() ||
        code == win64_abi_register_r14() ||
        code == win64_abi_register_r15();
}

bool win64_abi_vector_register_volatile(usize code) {
    return code < 6;
}

bool win64_abi_vector_register_nonvolatile(usize code) {
    return code >= 6 && code < 16;
}

Win64FrameLayout win64_abi_frame(
    usize local_bytes,
    usize outgoing_argument_count,
    usize saved_integer_registers,
    usize saved_vector_registers,
    bool makes_calls
) {
    usize stack_argument_bytes = 0;
    usize shadow_bytes = 0;
    if makes_calls {
        shadow_bytes = 32;
        if outgoing_argument_count > 4 {
            stack_argument_bytes = (outgoing_argument_count - 4) * 8;
        }
    }
    usize vector_save_bytes = saved_vector_registers * 16;
    usize required = local_bytes + vector_save_bytes +
        shadow_bytes + stack_argument_bytes;
    usize fixed = required;
    if required != 0 || saved_integer_registers != 0 || makes_calls {
        usize desired_modulo = 0;
        if saved_integer_registers % 2 == 0 { desired_modulo = 8; }
        usize remainder = fixed % 16;
        if remainder < desired_modulo {
            fixed = fixed + desired_modulo - remainder;
        } else if remainder > desired_modulo {
            fixed = fixed + 16 - remainder + desired_modulo;
        }
    }
    return Win64FrameLayout{
        shadow_bytes = shadow_bytes,
        stack_argument_bytes = stack_argument_bytes,
        local_bytes = local_bytes,
        vector_save_bytes = vector_save_bytes,
        fixed_allocation_bytes = fixed,
        saved_integer_registers = saved_integer_registers,
        saved_vector_registers = saved_vector_registers,
        body_stack_alignment = 16,
        makes_calls = makes_calls,
        requires_unwind = makes_calls || fixed != 0 ||
            saved_integer_registers != 0 || saved_vector_registers != 0
    };
}

usize win64_layout_alignment(usize requested, usize pack) {
    usize alignment = requested;
    if alignment == 0 { alignment = 1; }
    if alignment > 16 { alignment = 16; }
    if pack != 0 && alignment > pack { alignment = pack; }
    return alignment;
}

Win64LayoutCursor win64_layout_create(bool union_layout, usize pack) {
    return Win64LayoutCursor{
        size = 0,
        alignment = 1,
        pack = pack,
        union_layout = union_layout,
        bit_unit_offset = 0,
        bit_unit_size = 0,
        bit_used = 0,
        bit_unit_active = false,
        ok = pack == 0 || pack == 1 || pack == 2 ||
            pack == 4 || pack == 8 || pack == 16
    };
}

void win64_layout_end_bit_unit(ref Win64LayoutCursor layout) {
    layout.bit_unit_active = false;
    layout.bit_unit_offset = 0;
    layout.bit_unit_size = 0;
    layout.bit_used = 0;
}

Win64FieldLayout win64_layout_add_field(
    ref Win64LayoutCursor layout,
    usize size,
    usize requested_alignment
) {
    win64_layout_end_bit_unit(layout);
    usize alignment = win64_layout_alignment(
        requested_alignment, layout.pack
    );
    usize offset = 0;
    if !layout.union_layout {
        offset = x64_align_up(layout.size, alignment);
        layout.size = offset + size;
    } else {
        layout.size = x64_max(layout.size, size);
    }
    layout.alignment = x64_max(layout.alignment, alignment);
    return Win64FieldLayout{
        byte_offset = offset,
        bit_offset = 0,
        size = size,
        alignment = alignment,
        bit_width = 0,
        ok = layout.ok
    };
}

Win64FieldLayout win64_layout_add_explicit_field(
    ref Win64LayoutCursor layout,
    usize offset,
    usize size,
    usize requested_alignment
) {
    win64_layout_end_bit_unit(layout);
    usize alignment = win64_layout_alignment(
        requested_alignment, layout.pack
    );
    layout.size = x64_max(layout.size, offset + size);
    layout.alignment = x64_max(layout.alignment, alignment);
    return Win64FieldLayout{
        byte_offset = offset,
        bit_offset = 0,
        size = size,
        alignment = alignment,
        bit_width = 0,
        ok = layout.ok && offset % alignment == 0
    };
}

Win64FieldLayout win64_layout_add_bitfield(
    ref Win64LayoutCursor layout,
    usize storage_size,
    usize bit_width
) {
    usize storage_bits = storage_size * 8;
    usize alignment = win64_layout_alignment(storage_size, layout.pack);
    if storage_size != 1 && storage_size != 2 &&
        storage_size != 4 && storage_size != 8 {
        layout.ok = false;
    }
    if bit_width > storage_bits { layout.ok = false; }
    if bit_width == 0 {
        win64_layout_end_bit_unit(layout);
        if !layout.union_layout {
            layout.size = x64_align_up(layout.size, alignment);
        }
        return Win64FieldLayout{
            byte_offset = layout.size,
            bit_offset = 0,
            size = storage_size,
            alignment = alignment,
            bit_width = 0,
            ok = layout.ok
        };
    }
    if layout.union_layout {
        layout.size = x64_max(layout.size, storage_size);
        layout.alignment = x64_max(layout.alignment, alignment);
        return Win64FieldLayout{
            byte_offset = 0,
            bit_offset = 0,
            size = storage_size,
            alignment = alignment,
            bit_width = bit_width,
            ok = layout.ok
        };
    }
    if !layout.bit_unit_active || layout.bit_unit_size != storage_size ||
        layout.bit_used + bit_width > storage_bits {
        usize offset = x64_align_up(layout.size, alignment);
        layout.bit_unit_offset = offset;
        layout.bit_unit_size = storage_size;
        layout.bit_used = 0;
        layout.bit_unit_active = true;
        layout.size = offset + storage_size;
    }
    Win64FieldLayout result = Win64FieldLayout{
        byte_offset = layout.bit_unit_offset,
        bit_offset = layout.bit_used,
        size = storage_size,
        alignment = alignment,
        bit_width = bit_width,
        ok = layout.ok
    };
    layout.bit_used = layout.bit_used + bit_width;
    layout.alignment = x64_max(layout.alignment, alignment);
    if layout.bit_used == storage_bits { win64_layout_end_bit_unit(layout); }
    return result;
}

usize win64_layout_finish(ref Win64LayoutCursor layout) {
    win64_layout_end_bit_unit(layout);
    layout.size = x64_align_up(layout.size, layout.alignment);
    return layout.size;
}
