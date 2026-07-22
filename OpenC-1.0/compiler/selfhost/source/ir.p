import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

struct IrContext {
    text project_source;
    text project_root;
    text source;
    ptr byte module_data;
    PackedBuffer modules;
    ptr byte source_data;
    ptr byte type_data;
    PackedBuffer types;
    ptr byte symbol_data;
    ptr byte detail_data;
    PackedBuffer symbols;
    ptr byte token_data;
    PackedBuffer tokens;
    ptr byte syntax_data;
    PackedBuffer syntax;
    usize module_index;
    usize source_record;
    usize function_node;
    usize function_symbol;
    usize function_result;
    usize function_local_first;
    usize function_local_end;
    ptr byte name_cache;
    ptr byte call_cache;
    ptr byte local_values;
    ptr byte block_data;
    PackedBuffer blocks;
    ptr byte instruction_data;
    ptr byte instruction_detail;
    PackedBuffer instructions;
    ptr byte operand_data;
    PackedBuffer operands;
    ptr byte break_data;
    usize break_depth;
    ptr byte continue_data;
    usize continue_depth;
    usize current_block;
    usize next_value;
}

struct IrBounds {
    bool valid;
    usize start;
    usize end;
}

struct IrMemberBase {
    usize symbol;
    usize start;
    usize length;
}

usize ir_op_nop() { return 1; }
usize ir_op_const_integer() { return 2; }
usize ir_op_const_float() { return 3; }
usize ir_op_const_text() { return 4; }
usize ir_op_const_bool() { return 5; }
usize ir_op_local_alloc() { return 6; }
usize ir_op_load() { return 7; }
usize ir_op_store() { return 8; }
usize ir_op_unary() { return 9; }
usize ir_op_binary() { return 10; }
usize ir_op_short_begin() { return 11; }
usize ir_op_short_end() { return 12; }
usize ir_op_compare() { return 13; }
usize ir_op_cast() { return 14; }
usize ir_op_reinterpret() { return 15; }
usize ir_op_address() { return 16; }
usize ir_op_bounds() { return 17; }
usize ir_op_call() { return 18; }
usize ir_op_branch() { return 19; }
usize ir_op_branch_conditional() { return 20; }
usize ir_op_return() { return 21; }
usize ir_op_return_void() { return 22; }
usize ir_op_aggregate_create() { return 23; }
usize ir_op_aggregate_field() { return 24; }
usize ir_op_array_create() { return 25; }
usize ir_op_slice_create() { return 26; }
usize ir_op_optional_none() { return 27; }
usize ir_op_optional_some() { return 28; }
usize ir_op_status_create() { return 29; }
usize ir_op_scope_register() { return 30; }
usize ir_op_object_construct() { return 31; }
usize ir_op_object_destroy() { return 32; }
usize ir_op_target_fault() { return 33; }

text ir_opcode_text(usize opcode) {
    if opcode == ir_op_nop() { return "nop"; }
    if opcode == ir_op_const_integer() { return "const.integer"; }
    if opcode == ir_op_const_float() { return "const.float"; }
    if opcode == ir_op_const_text() { return "const.text"; }
    if opcode == ir_op_const_bool() { return "const.bool"; }
    if opcode == ir_op_local_alloc() { return "local.alloc"; }
    if opcode == ir_op_load() { return "load"; }
    if opcode == ir_op_store() { return "store"; }
    if opcode == ir_op_unary() { return "unary"; }
    if opcode == ir_op_binary() { return "binary"; }
    if opcode == ir_op_short_begin() { return "short_circuit.begin"; }
    if opcode == ir_op_short_end() { return "short_circuit.end"; }
    if opcode == ir_op_compare() { return "compare"; }
    if opcode == ir_op_cast() { return "cast"; }
    if opcode == ir_op_reinterpret() { return "reinterpret"; }
    if opcode == ir_op_address() { return "address_of"; }
    if opcode == ir_op_bounds() { return "bounds.check"; }
    if opcode == ir_op_call() { return "call"; }
    if opcode == ir_op_branch() { return "branch"; }
    if opcode == ir_op_branch_conditional() { return "branch.conditional"; }
    if opcode == ir_op_return() { return "return"; }
    if opcode == ir_op_return_void() { return "return.void"; }
    if opcode == ir_op_aggregate_create() { return "aggregate.create"; }
    if opcode == ir_op_aggregate_field() { return "aggregate.field"; }
    if opcode == ir_op_array_create() { return "array.create"; }
    if opcode == ir_op_slice_create() { return "slice.create"; }
    if opcode == ir_op_optional_none() { return "optional.none"; }
    if opcode == ir_op_optional_some() { return "optional.some"; }
    if opcode == ir_op_status_create() { return "status.create"; }
    if opcode == ir_op_scope_register() { return "scope.register"; }
    if opcode == ir_op_object_construct() { return "object.construct"; }
    if opcode == ir_op_object_destroy() { return "object.destroy"; }
    return "target.fault";
}

text ir_block_name(usize code) {
    if code == 1 { return "entry"; }
    if code == 2 { return "if.then"; }
    if code == 3 { return "if.else"; }
    if code == 4 { return "if.merge"; }
    if code == 5 { return "while.header"; }
    if code == 6 { return "while.body"; }
    if code == 7 { return "while.after"; }
    if code == 8 { return "for.header"; }
    if code == 9 { return "for.body"; }
    if code == 10 { return "for.step"; }
    if code == 11 { return "for.after"; }
    if code == 12 { return "switch.after"; }
    if code == 13 { return "switch.case"; }
    if code == 14 { return "switch.default"; }
    return "switch.next";
}

text ir_static_text(usize code) {
    if code == 1 { return "null"; }
    if code == 2 { return "&"; }
    if code == 3 { return "index"; }
    if code == 4 { return "index:address"; }
    if code == 5 { return "range"; }
    if code == 6 { return "status"; }
    if code == 7 { return "some"; }
    if code == 8 { return "destroy"; }
    if code == 9 { return "unsupported"; }
    if code == 10 { return "target-fault"; }
    if code == 11 { return "invalid pointer operation"; }
    if code == 12 { return "invalid pointer dereference"; }
    return "==";
}

unsafe usize ir_add_block(ref IrContext context, usize name_code) {
    usize block = context.blocks.length;
    write_record_field(context.block_data, block, 0, block);
    write_record_field(context.block_data, block, 1, name_code);
    context.blocks.length = context.blocks.length + 1;
    return block;
}

unsafe void ir_add_operand(
    ref IrContext context,
    usize value,
    usize immediate_kind,
    usize immediate_one,
    usize immediate_two
) {
    usize operand = context.operands.length;
    write_record_field(context.operand_data, operand, 0, value);
    write_record_field(context.operand_data, operand, 1, immediate_kind);
    write_record_field(context.operand_data, operand, 2, immediate_one);
    write_record_field(context.operand_data, operand, 3, immediate_two);
    context.operands.length = context.operands.length + 1;
}

unsafe usize ir_emit_instruction(
    ref IrContext context,
    usize opcode,
    usize type_id,
    usize start,
    usize length,
    usize text_kind,
    usize text_one,
    usize text_two,
    usize operand_first,
    usize operand_count,
    bool has_result
) {
    usize result = 0;
    if has_result {
        result = context.next_value;
        context.next_value = context.next_value + 1;
    }
    usize record = context.instructions.length;
    write_record_field(context.instruction_data, record, 0, context.current_block);
    write_record_field(context.instruction_data, record, 1, result);
    write_record_field(context.instruction_data, record, 2, opcode);
    write_record_field(context.instruction_data, record, 3, type_id);
    write_record_field(
        context.instruction_data, record, 4,
        resolution_pack_span(start, length)
    );
    write_record_field(context.instruction_detail, record, 0, text_kind);
    write_record_field(context.instruction_detail, record, 1, text_one);
    write_record_field(context.instruction_detail, record, 2, text_two);
    write_record_field(context.instruction_detail, record, 3, operand_first);
    write_record_field(context.instruction_detail, record, 4, operand_count);
    context.instructions.length = context.instructions.length + 1;
    return result;
}
