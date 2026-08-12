import system.memory;

unsafe X64UnwindBuilder x64_unwind_create(usize operation_capacity) {
    return X64UnwindBuilder{
        operation_data = memory.alloc(
            operation_capacity * record_stride()
        ),
        operations = PackedBuffer{
            length = 0,
            capacity = operation_capacity
        },
        prolog_size = 0,
        frame_register = 0,
        frame_offset = 0,
        ok = true
    };
}

unsafe void x64_unwind_destroy(ref X64UnwindBuilder builder) {
    memory.free(builder.operation_data);
    builder.operations.length = 0;
    builder.operations.capacity = 0;
    builder.ok = false;
}

unsafe void x64_unwind_operation(
    ref X64UnwindBuilder builder,
    usize code_offset,
    usize opcode,
    usize info,
    usize extra_slots,
    usize value
) {
    if builder.operations.length >= builder.operations.capacity ||
        code_offset > 255 || opcode > 15 || info > 15 ||
        extra_slots > 2 {
        builder.ok = false;
        return;
    }
    usize record = builder.operations.length;
    write_record_field(builder.operation_data, record, 0, code_offset);
    write_record_field(builder.operation_data, record, 1, opcode);
    write_record_field(builder.operation_data, record, 2, info);
    write_record_field(builder.operation_data, record, 3, extra_slots);
    write_record_field(builder.operation_data, record, 4, value);
    builder.operations.length = builder.operations.length + 1;
    builder.prolog_size = x64_max(builder.prolog_size, code_offset);
}

unsafe void x64_unwind_add_push_nonvolatile(
    ref X64UnwindBuilder builder,
    usize code_offset,
    usize register_code
) {
    if !win64_abi_integer_register_nonvolatile(register_code) {
        builder.ok = false;
        return;
    }
    x64_unwind_operation(
        builder, code_offset, x64_unwind_push_nonvolatile(),
        register_code, 0, 0
    );
}

unsafe void x64_unwind_add_allocation(
    ref X64UnwindBuilder builder,
    usize code_offset,
    usize size
) {
    if size < 8 || size % 8 != 0 || size > cast(usize, 4294967288) {
        builder.ok = false;
        return;
    }
    if size <= 128 {
        x64_unwind_operation(
            builder, code_offset, x64_unwind_allocate_small(),
            size / 8 - 1, 0, 0
        );
    } else if size < 524288 {
        x64_unwind_operation(
            builder, code_offset, x64_unwind_allocate_large(),
            0, 1, size / 8
        );
    } else {
        x64_unwind_operation(
            builder, code_offset, x64_unwind_allocate_large(),
            1, 2, size
        );
    }
}

unsafe void x64_unwind_add_frame_pointer(
    ref X64UnwindBuilder builder,
    usize code_offset,
    usize register_code,
    usize frame_offset
) {
    if !win64_abi_integer_register_nonvolatile(register_code) ||
        register_code == win64_abi_register_rsp() ||
        frame_offset > 240 || frame_offset % 16 != 0 {
        builder.ok = false;
        return;
    }
    builder.frame_register = register_code;
    builder.frame_offset = frame_offset / 16;
    x64_unwind_operation(
        builder, code_offset, x64_unwind_set_frame_pointer(), 0, 0, 0
    );
}

unsafe void x64_unwind_add_saved_integer(
    ref X64UnwindBuilder builder,
    usize code_offset,
    usize register_code,
    usize stack_offset
) {
    if !win64_abi_integer_register_nonvolatile(register_code) ||
        register_code == win64_abi_register_rsp() ||
        stack_offset % 8 != 0 {
        builder.ok = false;
        return;
    }
    if stack_offset / 8 <= 65535 {
        x64_unwind_operation(
            builder, code_offset, x64_unwind_save_nonvolatile(),
            register_code, 1, stack_offset / 8
        );
    } else {
        x64_unwind_operation(
            builder, code_offset, x64_unwind_save_nonvolatile_far(),
            register_code, 2, stack_offset
        );
    }
}

unsafe void x64_unwind_add_saved_vector(
    ref X64UnwindBuilder builder,
    usize code_offset,
    usize register_code,
    usize stack_offset
) {
    if !win64_abi_vector_register_nonvolatile(register_code) ||
        stack_offset % 16 != 0 {
        builder.ok = false;
        return;
    }
    if stack_offset / 16 <= 65535 {
        x64_unwind_operation(
            builder, code_offset, x64_unwind_save_xmm128(),
            register_code, 1, stack_offset / 16
        );
    } else {
        x64_unwind_operation(
            builder, code_offset, x64_unwind_save_xmm128_far(),
            register_code, 2, stack_offset
        );
    }
}

unsafe usize x64_unwind_slot_count(ref X64UnwindBuilder builder) {
    usize count = 0;
    usize operation = 0;
    while operation < builder.operations.length {
        count = count + 1 + read_record_field(
            builder.operation_data, operation, 3
        );
        operation = operation + 1;
    }
    return count;
}

unsafe DBuffer x64_unwind_encode(ref X64UnwindBuilder builder) {
    usize slots = x64_unwind_slot_count(builder);
    DBuffer output = d_buffer_create(4 + x64_align_up(slots, 2) * 2);
    if !builder.ok || slots > 255 || builder.prolog_size > 255 {
        output.ok = false;
        return output;
    }
    d_put_byte(output, 1);
    d_put_byte(output, cast(u8, builder.prolog_size));
    d_put_byte(output, cast(u8, slots));
    d_put_byte(output, cast(u8,
        builder.frame_register + builder.frame_offset * 16
    ));
    usize operation = builder.operations.length;
    while operation != 0 {
        operation = operation - 1;
        usize code_offset = read_record_field(
            builder.operation_data, operation, 0
        );
        usize opcode = read_record_field(
            builder.operation_data, operation, 1
        );
        usize info = read_record_field(
            builder.operation_data, operation, 2
        );
        usize extra_slots = read_record_field(
            builder.operation_data, operation, 3
        );
        usize value = read_record_field(
            builder.operation_data, operation, 4
        );
        d_put_byte(output, cast(u8, code_offset));
        d_put_byte(output, cast(u8, opcode + info * 16));
        if extra_slots >= 1 {
            d_put_byte(output, cast(u8, value & 255));
            d_put_byte(output, cast(u8, (value >> 8) & 255));
        }
        if extra_slots == 2 {
            d_put_byte(output, cast(u8, (value >> 16) & 255));
            d_put_byte(output, cast(u8, (value >> 24) & 255));
        }
    }
    if slots % 2 != 0 {
        d_put_byte(output, 0);
        d_put_byte(output, 0);
    }
    return output;
}

unsafe DBuffer x64_runtime_function_record(
    usize begin_rva,
    usize end_rva,
    usize unwind_rva
) {
    X64Code record = x64_code_create(12, 1);
    x64_emit_u32(record, begin_rva);
    x64_emit_u32(record, end_rva);
    x64_emit_u32(record, unwind_rva);
    DBuffer result = record.bytes;
    memory.free(record.relocation_data);
    record.ok = false;
    return result;
}

unsafe bool x64_runtime_function_ordered(
    usize previous_begin,
    usize previous_end,
    usize next_begin,
    usize next_end
) {
    return previous_begin < previous_end &&
        previous_end <= next_begin && next_begin < next_end;
}
