import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe void native_value_address(ref IrContext context, ref NativeFunction function,
    usize value, usize reg) {
    usize type_id = native_value_read(function, function.value_types, value);
    if c_type_is_pointer_like(context, type_id) || native_value_read(
        function, function.address_values, value
    ) != 0 { native_load(function, value, reg); }
    else { native_address(function, value, reg); }
}

// An out operand needs the address of its storage even when the stored value
// is itself a pointer. Address-valued lvalues already carry their destination
// address; ordinary locals must use their frame slot. Treating every pointer
// as an address loaded an uninitialized `out ptr` value and made raw file reads
// write through address zero.
unsafe void native_output_address(
    ref NativeFunction function,
    usize value,
    usize reg
) {
    if native_value_read(
        function, function.address_values, value
    ) != 0 {
        native_load(function, value, reg);
    } else {
        native_address(function, value, reg);
    }
}

unsafe void native_sequence_length(ref IrContext context, ref NativeFunction function,
    usize value, usize type_id, usize reg) {
    if read_record_field(context.type_data, type_id, 0) == 10 {
        x64_mov_r64_imm64(function.code, reg,
            cast(u64, read_record_field(context.type_data, type_id, 2)));
    } else {
        native_value_address(context, function, value, reg);
        x64_mov_r64_memory(function.code, reg, reg, 8);
    }
}

unsafe void native_sequence_address(ref IrContext context, ref NativeFunction function,
    usize value, usize type_id, usize reg) {
    native_value_address(context, function, value, reg);
    if read_record_field(context.type_data, type_id, 0) != 10 {
        x64_mov_r64_memory(function.code, reg, reg, 0);
    }
}

// Exact-sized copy from R11 to R10. x64 permits unaligned integer moves, so
// transfer full words before the final byte tail instead of emitting eight
// load/store pairs for every eight-byte aggregate chunk.
unsafe void native_copy_value(ref NativeFunction function, usize size) {
    usize index = 0;
    while index + 8 <= size {
        x64_mov_r64_memory(function.code, 0, 11, index);
        x64_mov_memory_r64(function.code, 10, index, 0);
        index = index + 8;
    }
    while index < size {
        x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
        x64_emit_u8(function.code, 182);
        x64_emit_memory_modrm(function.code, 0, 11, index);
        x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 136);
        x64_emit_memory_modrm(function.code, 0, 10, index);
        index = index + 1;
    }
}

unsafe void native_analyze_values(ref IrContext context, usize first,
    ptr byte value_types, ptr byte reference_storage,
    ptr byte instruction_order, ptr byte use_counts, usize value_capacity) {
    usize ordered = 0;
    while ordered < context.instructions.length {
        usize instruction = read_usize(
            instruction_order, ordered * size_of(usize)
        );
        usize result = read_record_field(
            context.instruction_data, instruction, 1
        );
        usize opcode = read_record_field(
            context.instruction_data, instruction, 2
        );
        if use_counts != null {
            usize operand = 0;
            usize count = d_operand_count(context, instruction);
            while operand < count {
                usize value = d_operand_value(context, instruction, operand);
                if value >= first && value - first < value_capacity {
                    usize offset = (value - first) * size_of(usize);
                    write_usize(use_counts, offset,
                        read_usize(use_counts, offset) + 1);
                }
                operand = operand + 1;
            }
        }
        if result != 0 {
            write_usize(value_types, (result - first) * size_of(usize),
                read_record_field(context.instruction_data, instruction, 3));
            write_usize(reference_storage,
                (result - first) * size_of(usize), 0);
        }
        if opcode == ir_op_object_construct() && result != 0 {
            write_usize(reference_storage,
                (result - first) * size_of(usize),
                d_operand_value(context, instruction, 0) + 1);
        } else if opcode == ir_op_load() && result != 0 {
            usize source = d_operand_value(context, instruction, 0);
            write_usize(reference_storage,
                (result - first) * size_of(usize),
                read_usize(reference_storage,
                    (source - first) * size_of(usize)));
        } else if opcode == ir_op_store() {
            usize destination = d_operand_value(context, instruction, 0);
            usize source = d_operand_value(context, instruction, 1);
            write_usize(reference_storage,
                (destination - first) * size_of(usize),
                read_usize(reference_storage,
                    (source - first) * size_of(usize)));
        }
        ordered = ordered + 1;
    }
}
