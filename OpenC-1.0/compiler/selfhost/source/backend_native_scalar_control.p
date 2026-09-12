import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe void native_check_result(
    ref IrContext context, ref NativeFunction function, usize type_id
) {
    usize kind = read_record_field(context.type_data, type_id, 0);
    usize bits = read_record_field(context.type_data, type_id, 3);
    if kind == 6 { bits = 8; }
    if bits == 0 || bits >= 64 { return; }
    if kind == 2 {
        u64 limit = (cast(u64, 1) << (bits - 1)) - cast(u64, 1);
        x64_mov_r64_imm64(function.code, 10, limit);
        x64_cmp_r64_r64(function.code, 0, 10);
        native_require(function.code, 14);
        x64_mov_r64_imm64(function.code, 10, ~limit);
        x64_cmp_r64_r64(function.code, 0, 10);
        native_require(function.code, 13);
    } else if kind == 3 || kind == 6 {
        x64_mov_r64_imm64(function.code, 10,
            (cast(u64, 1) << bits) - cast(u64, 1));
        x64_cmp_r64_r64(function.code, 0, 10);
        native_require(function.code, 6);
    }
}

unsafe void native_branch(
    ref NativeFunction function, usize target, usize condition
) {
    if condition == 16 { x64_emit_u8(function.code, 233); }
    else { x64_emit_u8(function.code, 15); x64_emit_u8(function.code, 128 + condition); }
    usize patch = function.code.bytes.length;
    x64_emit_u32(function.code, 0);
    write_record_field(function.branch_patches, function.branch_count, 0, patch);
    write_record_field(function.branch_patches, function.branch_count, 1, target);
    function.branch_count = function.branch_count + 1;
}

unsafe usize native_scope_ordinal(ref IrContext context, usize instruction) {
    usize ordinal = 0; usize index = 0;
    while index < instruction {
        if read_record_field(context.instruction_data, index, 2) == ir_op_scope_register() {
            ordinal = ordinal + 1;
        }
        index = index + 1;
    }
    return ordinal;
}

unsafe void native_scope_call(ref IrContext context, ref NativeFunction function,
    usize instruction) {
    if d_instruction_text_is(context, instruction, "destroy") { return; }
    usize kind = read_record_field(context.instruction_detail, instruction, 0);
    usize target = read_record_field(context.instruction_detail, instruction, 1);
    usize count = d_operand_count(context, instruction);
    if kind == 7 && c_builtin_is(context, instruction,
        "memory.free", "system.memory.free") {
        native_load(function, d_operand_value(context, instruction, 0), 8);
        native_heap_free_r8(function); return;
    }
    if kind != 3 || target >= context.symbols.length || count > 30 {
        function.code.ok = false; return;
    }
    usize argument = 0;
    while argument < count {
        usize value = d_operand_value(context, instruction, argument);
        usize type_id = native_value_read(function, function.value_types, value);
        usize parameter = c_call_parameter(context, instruction, argument);
        bool owned_address = parameter < context.symbols.length &&
            d_parameter_owned(context, parameter) && !c_type_is_pointer_like(context,
                read_record_field(context.symbol_data, parameter, 4));
        if native_indirect_aggregate(context, type_id) || owned_address {
            native_address(function, value, 0);
        }
        else { native_load(function, value, 0); }
        x64_mov_memory_r64(function.code, 4, argument * 8, 0);
        argument = argument + 1;
    }
    x64_mov_r64_memory(function.code, 1, 4, 0);
    x64_mov_r64_memory(function.code, 2, 4, 8);
    x64_mov_r64_memory(function.code, 8, 4, 16);
    x64_mov_r64_memory(function.code, 9, 4, 24);
    x64_call_symbol(function.code, target, 0);
}

unsafe void native_scope_cleanup(ref IrContext context, ref NativeFunction function,
    usize before_instruction) {
    usize index = before_instruction;
    while index != 0 {
        index = index - 1;
        if read_record_field(context.instruction_data, index, 2) == ir_op_scope_register() {
            usize ordinal = native_scope_ordinal(context, index);
            x64_mov_r64_memory(function.code, 0, 4, 1024 + ordinal * 8);
            x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
            x64_emit_u8(function.code, 192); usize inactive = native_skip(function.code, 4);
            x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
            x64_mov_memory_r64(function.code, 4, 1024 + ordinal * 8, 0);
            native_scope_call(context, function, index);
            native_skip_end(function.code, inactive);
        }
    }
}

unsafe void native_checked_require(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize condition
) {
    usize satisfied = native_skip(function.code, condition);
    native_scope_cleanup(context, function, instruction);
    x64_call_symbol(function.code, cast(usize, 4294967295), 0);
    native_skip_end(function.code, satisfied);
}

struct NativeInteger {
    u64 value;
    bool valid;
}

struct NativeFloat {
    u64 value;
    bool valid;
}
