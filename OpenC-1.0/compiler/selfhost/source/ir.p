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

unsafe usize ir_emit_value(
    ref IrContext context,
    usize opcode,
    usize type_id,
    usize node,
    usize text_kind,
    usize text_one,
    usize text_two,
    usize operand_first,
    usize operand_count
) {
    return ir_emit_instruction(
        context, opcode, type_id,
        read_record_field(context.syntax_data, node, 1),
        read_record_field(context.syntax_data, node, 2),
        text_kind, text_one, text_two,
        operand_first, operand_count, true
    );
}

unsafe void ir_emit_void(
    ref IrContext context,
    usize opcode,
    usize node,
    usize text_kind,
    usize text_one,
    usize text_two,
    usize operand_first,
    usize operand_count
) {
    ir_emit_instruction(
        context, opcode, semantic_type_void(),
        read_record_field(context.syntax_data, node, 1),
        read_record_field(context.syntax_data, node, 2),
        text_kind, text_one, text_two,
        operand_first, operand_count, false
    );
}

unsafe usize ir_resolve_name(ref IrContext context, usize node) {
    return flow_name_symbol(
        context.project_source, context.project_root,
        context.module_data, context.modules, context.source_data,
        context.symbol_data, context.detail_data, context.symbols,
        context.syntax_data, context.syntax,
        context.module_index, context.source_record,
        node, context.source
    );
}

unsafe usize ir_select_call(ref IrContext context, usize call) {
    usize selected = flow_call_selection(
        context.project_source, context.project_root,
        context.module_data, context.modules, context.source_data,
        context.type_data, context.symbol_data,
        context.detail_data, context.symbols,
        context.token_data, context.tokens,
        context.syntax_data, context.syntax,
        context.module_index, context.source_record,
        call, context.source
    );
    if selected >= context.symbols.length {
        selected = flow_call_declared_target(
            context.project_source, context.project_root,
            context.module_data, context.modules, context.source_data,
            context.symbol_data, context.detail_data, context.symbols,
            context.syntax_data, context.syntax,
            context.module_index, context.source_record,
            call, context.source
        );
    }
    return selected;
}

void ir_json_hex4(usize value) {
    io.print(project_hex_digit((value / 4096) % 16));
    io.print(project_hex_digit((value / 256) % 16));
    io.print(project_hex_digit((value / 16) % 16));
    io.print(project_hex_digit(value % 16));
}

void ir_json_slice(text value, usize start, usize length) {
    // Emit Unicode escapes from byte spans. This keeps byte-addressed source
    // spans exact even when text.slice would interpret offsets as code points.
    io.print("\"");
    usize cursor = 0;
    while cursor < length {
        usize first = cast(usize, byte_at_or_zero(value, start + cursor));
        usize codepoint = first;
        usize consumed = 1;
        if first >= 194 && first <= 223 && cursor + 1 < length {
            usize second = cast(usize, byte_at_or_zero(
                value, start + cursor + 1
            ));
            codepoint = (first % 32) * 64 + second % 64;
            consumed = 2;
        } else if first >= 224 && first <= 239 && cursor + 2 < length {
            usize second = cast(usize, byte_at_or_zero(
                value, start + cursor + 1
            ));
            usize third = cast(usize, byte_at_or_zero(
                value, start + cursor + 2
            ));
            codepoint = (first % 16) * 4096 +
                (second % 64) * 64 + third % 64;
            consumed = 3;
        } else if first >= 240 && first <= 244 && cursor + 3 < length {
            usize second = cast(usize, byte_at_or_zero(
                value, start + cursor + 1
            ));
            usize third = cast(usize, byte_at_or_zero(
                value, start + cursor + 2
            ));
            usize fourth = cast(usize, byte_at_or_zero(
                value, start + cursor + 3
            ));
            codepoint = (first % 8) * 262144 +
                (second % 64) * 4096 +
                (third % 64) * 64 + fourth % 64;
            consumed = 4;
        }
        if codepoint <= 65535 {
            io.print("\\u");
            ir_json_hex4(codepoint);
        } else {
            usize scalar = codepoint - 65536;
            io.print("\\u");
            ir_json_hex4(55296 + scalar / 1024);
            io.print("\\u");
            ir_json_hex4(56320 + scalar % 1024);
        }
        cursor = cursor + consumed;
    }
    io.print("\"");
}

void ir_json_text(text value) {
    ir_json_slice(value, 0, text.byte_length(value));
}

unsafe void ir_emit_symbol_name(ref IrContext context, usize symbol) {
    usize kind = read_record_field(context.symbol_data, symbol, 0);
    if read_record_field(context.detail_data, symbol, 2) == 0 &&
        kind != resolution_symbol_field() &&
        kind != resolution_symbol_enum_item() {
        usize module_index = read_record_field(
            context.detail_data, symbol, 0
        );
        ir_json_slice(
            context.project_source,
            read_record_field(context.module_data, module_index, 0),
            read_record_field(context.module_data, module_index, 1)
        );
        // Symbol identities need one JSON string. The caller uses the
        // dedicated combined form below instead of this helper.
    }
}

unsafe void ir_json_symbol_identity(ref IrContext context, usize symbol) {
    io.print("\"");
    usize kind = read_record_field(context.symbol_data, symbol, 0);
    if read_record_field(context.detail_data, symbol, 2) == 0 &&
        kind != resolution_symbol_field() &&
        kind != resolution_symbol_enum_item() {
        usize module_index = read_record_field(
            context.detail_data, symbol, 0
        );
        io.print(project_slice(
            context.project_source,
            read_record_field(context.module_data, module_index, 0),
            read_record_field(context.module_data, module_index, 1)
        ));
        io.print(".");
    }
    text symbol_source;
    status loaded = project_read_source_record(
        context.project_source, context.project_root, context.source_data,
        read_record_field(context.symbol_data, symbol, 1), out symbol_source
    );
    if loaded.ok {
        io.print(project_slice(
            symbol_source,
            read_record_field(context.symbol_data, symbol, 2),
            read_record_field(context.symbol_data, symbol, 3)
        ));
    }
    io.print("\"");
}

unsafe usize ir_type_ref_within(ref IrContext context, usize node) {
    usize selected = context.syntax.length;
    usize selected_start = cast(usize, 4294967295);
    usize record = 0;
    while record < context.syntax.length {
        if read_record_field(context.syntax_data, record, 0) == 26 &&
            semantic_node_contains(context.syntax_data, node, record) {
            usize start = read_record_field(context.syntax_data, record, 1);
            if start < selected_start {
                selected = record;
                selected_start = start;
            }
        }
        record = record + 1;
    }
    return selected;
}

unsafe usize ir_resolve_type_node(ref IrContext context, usize type_node) {
    if type_node >= context.syntax.length { return semantic_type_error(); }
    return semantic_resolve_type(
        context.project_source, context.project_root,
        context.module_data, context.modules, context.source_data,
        context.source_record, context.source,
        context.token_data, context.tokens,
        context.type_data, context.types,
        read_record_field(context.syntax_data, type_node, 1),
        read_record_field(context.syntax_data, type_node, 2)
    );
}

unsafe usize ir_expression_child_after(
    ref IrContext context,
    usize parent,
    usize after,
    bool largest
) {
    usize selected = context.syntax.length;
    usize measure = 0;
    usize selected_start = cast(usize, 4294967295);
    usize record = 0;
    while record < context.syntax.length {
        usize kind = read_record_field(context.syntax_data, record, 0);
        usize start = read_record_field(context.syntax_data, record, 1);
        if resolution_expression_kind(kind) && record != parent &&
            start >= after && semantic_node_contains(
                context.syntax_data, parent, record
            ) {
            usize length = read_record_field(context.syntax_data, record, 2);
            if largest {
                if selected == context.syntax.length || length > measure {
                    selected = record;
                    measure = length;
                }
            } else if start < selected_start {
                selected = record;
                selected_start = start;
            }
        }
        record = record + 1;
    }
    return selected;
}

unsafe usize ir_enum_value(ref IrContext context, usize symbol) {
    usize owner = read_record_field(context.detail_data, symbol, 2);
    if owner == 0 { return 0; }
    usize requested_node = read_record_field(context.detail_data, symbol, 1);
    usize value = 0;
    usize candidate = 0;
    while candidate < context.symbols.length {
        if read_record_field(context.symbol_data, candidate, 0) ==
                resolution_symbol_enum_item() &&
            read_record_field(context.detail_data, candidate, 2) == owner {
            if read_record_field(context.detail_data, candidate, 1) ==
                requested_node { return value; }
            value = value + 1;
        }
        candidate = candidate + 1;
    }
    return value;
}

unsafe usize ir_node_type(
    ref IrContext context,
    usize node,
    usize expected
) {
    if node >= context.syntax.length { return semantic_type_error(); }
    usize kind = read_record_field(context.syntax_data, node, 0);
    if kind == 29 {
        if expected != semantic_type_error() {
            usize expected_kind = read_record_field(
                context.type_data, expected, 0
            );
            if expected_kind == 2 || expected_kind == 3 ||
                expected_kind == 6 || expected_kind == 9 ||
                expected_kind == 14 {
                return expected;
            }
        }
        return semantic_builtin_type("i32", 0, 3);
    }
    if kind == 30 {
        if expected != semantic_type_error() &&
            read_record_field(context.type_data, expected, 0) == 4 {
            return expected;
        }
        return semantic_builtin_type("f64", 0, 3);
    }
    if kind == 31 { return semantic_type_text(); }
    if kind == 32 { return semantic_type_bool(); }
    if kind == 33 {
        if expected < context.types.length && read_record_field(
            context.type_data, expected, 0
        ) == 13 { return expected; }
        return semantic_derived_type(
            context.type_data, context.types, 13,
            semantic_type_void(), 0, true, false
        );
    }
    if kind == 34 {
        if expected != semantic_type_error() { return expected; }
        return semantic_type_error();
    }
    if kind == 27 {
        usize symbol = ir_resolve_name(context, node);
        if symbol < context.symbols.length {
            return read_record_field(context.symbol_data, symbol, 4);
        }
        if flow_span_has_byte(
            context.source,
            read_record_field(context.syntax_data, node, 1),
            read_record_field(context.syntax_data, node, 2), 46
        ) {
            IrMemberBase member_base = ir_find_local_base(context, node);
            if member_base.symbol < context.symbols.length {
                return ir_qualified_member_type(
                    context, member_base.symbol,
                    member_base.start, member_base.length
                );
            }
        }
        return semantic_type_error();
    }
    if kind == 35 {
        usize operator_start = read_record_field(context.syntax_data, node, 3);
        usize child = resolution_right_expression(
            context.syntax_data, node,
            operator_start + read_record_field(context.syntax_data, node, 4)
        );
        usize child_type = ir_node_type(context, child, expected);
        if flow_node_operator(context.source, context.syntax_data, node, "!") {
            return semantic_type_bool();
        }
        if flow_node_operator(context.source, context.syntax_data, node, "&") {
            return semantic_derived_type(
                context.type_data, context.types, 13,
                child_type, 0, false, false
            );
        }
        if flow_node_operator(context.source, context.syntax_data, node, "*") &&
            read_record_field(context.type_data, child_type, 0) == 13 {
            return read_record_field(context.type_data, child_type, 1);
        }
        return child_type;
    }
    if kind == 36 {
        if flow_node_operator(context.source, context.syntax_data, node, "==") ||
            flow_node_operator(context.source, context.syntax_data, node, "!=") ||
            flow_node_operator(context.source, context.syntax_data, node, "<") ||
            flow_node_operator(context.source, context.syntax_data, node, "<=") ||
            flow_node_operator(context.source, context.syntax_data, node, ">") ||
            flow_node_operator(context.source, context.syntax_data, node, ">=") ||
            flow_node_operator(context.source, context.syntax_data, node, "&&") ||
            flow_node_operator(context.source, context.syntax_data, node, "||") {
            return semantic_type_bool();
        }
        usize left = resolution_left_expression(
            context.syntax_data, node,
            read_record_field(context.syntax_data, node, 3)
        );
        usize right = resolution_right_expression(
            context.syntax_data, node,
            read_record_field(context.syntax_data, node, 3) +
            read_record_field(context.syntax_data, node, 4)
        );
        usize left_type = ir_node_type(
            context, left, semantic_type_error()
        );
        usize right_type = ir_node_type(
            context, right, semantic_type_error()
        );
        if left_type < context.types.length &&
            right_type < context.types.length &&
            read_record_field(context.type_data, left_type, 0) == 13 &&
            read_record_field(context.type_data, right_type, 0) == 13 &&
            flow_node_operator(context.source, context.syntax_data, node, "-") {
            return semantic_builtin_type("isize", 0, 5);
        }
        return ir_node_type(context, left, expected);
    }
    if kind == 37 {
        usize left = resolution_left_expression(
            context.syntax_data, node,
            read_record_field(context.syntax_data, node, 1) +
            read_record_field(context.syntax_data, node, 2)
        );
        return ir_node_type(context, left, expected);
    }
    if kind == 38 {
        usize selected = ir_select_call(context, node);
        if selected < context.symbols.length {
            return read_record_field(context.symbol_data, selected, 4);
        }
        usize callee = read_record_field(context.syntax_data, node, 3);
        if callee < context.syntax.length {
            usize callee_start = read_record_field(
                context.syntax_data, callee, 1
            );
            usize callee_length = read_record_field(
                context.syntax_data, callee, 2
            );
            if starts_with_ascii(context.source, callee_start, "io.") ||
                starts_with_ascii(context.source, callee_start, "system.io.") ||
                span_equals_ascii(
                    context.source, callee_start, callee_length, "memory.free"
                ) || span_equals_ascii(
                    context.source, callee_start, callee_length,
                    "system.memory.free"
                ) {
                return semantic_type_void();
            }
            if span_equals_ascii(
                context.source, callee_start, callee_length, "memory.alloc"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.memory.alloc"
            ) { return 18; }
            if span_equals_ascii(
                context.source, callee_start, callee_length, "text.trim"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.text.trim"
            ) { return semantic_type_text(); }
            if ir_intrinsic_call(
                context.source, callee_start, callee_length
            ) {
                IrBounds first_argument = ir_argument_bounds(
                    context, node, 0
                );
                if first_argument.valid {
                    usize first_node = ir_root_in_bounds(
                        context, first_argument.start, first_argument.end
                    );
                    return ir_node_type(
                        context, first_node, semantic_type_error()
                    );
                }
            }
        }
        return semantic_type_error();
    }
    if kind == 42 || kind == 43 {
        return ir_resolve_type_node(
            context, ir_type_ref_within(context, node)
        );
    }
    if kind == 44 {
        usize storage_name = flow_event_first_name(
            context.syntax_data, context.syntax, node
        );
        usize storage_type = ir_node_type(
            context, storage_name, semantic_type_error()
        );
        if read_record_field(context.type_data, storage_type, 0) == 15 {
            return semantic_derived_type(
                context.type_data, context.types, 12,
                read_record_field(context.type_data, storage_type, 1),
                0, false, false
            );
        }
        return semantic_type_error();
    }
    if kind == 45 { return semantic_type_void(); }
    if kind == 46 { return semantic_builtin_type("usize", 0, 5); }
    if kind == 47 { return semantic_type_status(); }
    if kind == 48 {
        usize name = flow_event_first_name(
            context.syntax_data, context.syntax, node
        );
        return ir_node_type(context, name, expected);
    }
    if kind == 50 {
        if expected != semantic_type_error() { return expected; }
        return semantic_type_error();
    }
    if kind == 51 {
        usize out_symbol = ir_resolve_name(context, node);
        if out_symbol < context.symbols.length {
            return read_record_field(
                context.symbol_data, out_symbol, 4
            );
        }
        return expected;
    }
    if kind == 39 || kind == 40 || kind == 41 {
        usize root = ir_expression_child_after(
            context, node,
            read_record_field(context.syntax_data, node, 1), false
        );
        usize base_type = ir_node_type(
            context, root, semantic_type_error()
        );
        if kind == 40 &&
            (read_record_field(context.type_data, base_type, 0) == 10 ||
             read_record_field(context.type_data, base_type, 0) == 11) {
            return read_record_field(context.type_data, base_type, 1);
        }
        if kind == 41 {
            return semantic_derived_type(
                context.type_data, context.types, 11,
                read_record_field(context.type_data, base_type, 1),
                0, false, false
            );
        }
        if kind == 39 {
            if base_type < context.types.length && read_record_field(
                context.type_data, base_type, 0
            ) == 12 { base_type = ir_type_element(context, base_type); }
            if base_type < context.types.length && read_record_field(
                context.type_data, base_type, 0
            ) == 14 {
                usize optional_member_start = read_record_field(
                    context.syntax_data, node, 3
                );
                usize optional_member_length = read_record_field(
                    context.syntax_data, node, 4
                );
                if span_equals_ascii(
                    context.source, optional_member_start,
                    optional_member_length, "present"
                ) { return semantic_type_bool(); }
                return ir_type_element(context, base_type);
            }
            if base_type == semantic_type_status() {
                usize member_start = read_record_field(
                    context.syntax_data, node, 3
                );
                usize member_length = read_record_field(
                    context.syntax_data, node, 4
                );
                if span_equals_ascii(
                    context.source, member_start, member_length, "ok"
                ) { return semantic_type_bool(); }
                if span_equals_ascii(
                    context.source, member_start, member_length, "code"
                ) { return semantic_builtin_type("i32", 0, 3); }
                return semantic_type_text();
            }
            if base_type < context.types.length && read_record_field(
                context.type_data, base_type, 0
            ) == 11 {
                return semantic_builtin_type("usize", 0, 5);
            }
            usize aggregate_symbol = context.symbols.length;
            usize candidate = 0;
            while candidate < context.symbols.length {
                usize symbol_kind = read_record_field(
                    context.symbol_data, candidate, 0
                );
                if (symbol_kind == resolution_symbol_struct() ||
                    symbol_kind == resolution_symbol_resource()) &&
                    read_record_field(
                        context.symbol_data, candidate, 4
                    ) == base_type {
                    aggregate_symbol = candidate;
                    break;
                }
                candidate = candidate + 1;
            }
            if aggregate_symbol < context.symbols.length {
                usize field_symbol = ir_field_symbol(
                    context, aggregate_symbol,
                    read_record_field(context.syntax_data, node, 3),
                    read_record_field(context.syntax_data, node, 4)
                );
                if field_symbol < context.symbols.length {
                    return read_record_field(
                        context.symbol_data, field_symbol, 4
                    );
                }
            }
        }
    }
    return expected;
}

unsafe IrBounds ir_argument_bounds(
    ref IrContext context,
    usize call,
    usize requested
) {
    usize callee = read_record_field(context.syntax_data, call, 3);
    if callee >= context.syntax.length {
        return IrBounds{ valid = false, start = 0, end = 0 };
    }
    usize callee_end = read_record_field(context.syntax_data, callee, 1) +
        read_record_field(context.syntax_data, callee, 2);
    usize token = semantic_token_at_or_after(
        context.token_data, context.tokens, callee_end
    );
    while token < context.tokens.length && !span_equals_ascii(
        context.source,
        read_record_field(context.token_data, token, 1),
        read_record_field(context.token_data, token, 2), "("
    ) { token = token + 1; }
    if token >= context.tokens.length {
        return IrBounds{ valid = false, start = 0, end = 0 };
    }
    token = token + 1;
    if token >= context.tokens.length {
        return IrBounds{ valid = false, start = 0, end = 0 };
    }
    usize current_start = read_record_field(context.token_data, token, 1);
    usize depth = 0;
    usize index = 0;
    usize call_end = read_record_field(context.syntax_data, call, 1) +
        read_record_field(context.syntax_data, call, 2);
    while token < context.tokens.length &&
        read_record_field(context.token_data, token, 1) < call_end {
        usize start = read_record_field(context.token_data, token, 1);
        usize length = read_record_field(context.token_data, token, 2);
        bool open = span_equals_ascii(context.source, start, length, "(") ||
            span_equals_ascii(context.source, start, length, "[") ||
            span_equals_ascii(context.source, start, length, "{");
        bool close = span_equals_ascii(context.source, start, length, ")") ||
            span_equals_ascii(context.source, start, length, "]") ||
            span_equals_ascii(context.source, start, length, "}");
        if close && depth == 0 {
            if index == requested && start > current_start {
                return IrBounds{
                    valid = true, start = current_start, end = start
                };
            }
            return IrBounds{ valid = false, start = 0, end = 0 };
        }
        if open { depth = depth + 1; }
        if close && depth != 0 { depth = depth - 1; }
        if depth == 0 && span_equals_ascii(
            context.source, start, length, ","
        ) {
            if index == requested {
                return IrBounds{
                    valid = true, start = current_start, end = start
                };
            }
            index = index + 1;
            if token + 1 < context.tokens.length {
                current_start = read_record_field(
                    context.token_data, token + 1, 1
                );
            }
        }
        token = token + 1;
    }
    return IrBounds{ valid = false, start = 0, end = 0 };
}

unsafe usize ir_root_in_bounds(
    ref IrContext context,
    usize start,
    usize end
) {
    usize selected = context.syntax.length;
    usize selected_length = 0;
    usize record = 0;
    while record < context.syntax.length {
        usize kind = read_record_field(context.syntax_data, record, 0);
        usize node_start = read_record_field(context.syntax_data, record, 1);
        usize node_end = node_start +
            read_record_field(context.syntax_data, record, 2);
        if resolution_expression_kind(kind) &&
            node_start >= start && node_end <= end {
            usize length = node_end - node_start;
            if selected == context.syntax.length || length > selected_length {
                selected = record;
                selected_length = length;
            }
        }
        record = record + 1;
    }
    return selected;
}

unsafe usize ir_initializer_field_value(
    ref IrContext context,
    usize initializer,
    usize field
) {
    usize after = read_record_field(context.syntax_data, field, 3) +
        read_record_field(context.syntax_data, field, 4);
    usize token = semantic_token_at_or_after(
        context.token_data, context.tokens, after
    );
    if token < context.tokens.length && span_equals_ascii(
        context.source,
        read_record_field(context.token_data, token, 1),
        read_record_field(context.token_data, token, 2), "="
    ) { token = token + 1; }
    if token >= context.tokens.length { return context.syntax.length; }
    usize start = read_record_field(context.token_data, token, 1);
    usize end = read_record_field(context.syntax_data, initializer, 1) +
        read_record_field(context.syntax_data, initializer, 2);
    usize depth = 0;
    while token < context.tokens.length &&
        read_record_field(context.token_data, token, 1) < end {
        usize token_start = read_record_field(context.token_data, token, 1);
        usize token_length = read_record_field(context.token_data, token, 2);
        bool open = span_equals_ascii(
            context.source, token_start, token_length, "("
        ) || span_equals_ascii(
            context.source, token_start, token_length, "["
        ) || span_equals_ascii(
            context.source, token_start, token_length, "{"
        );
        bool close = span_equals_ascii(
            context.source, token_start, token_length, ")"
        ) || span_equals_ascii(
            context.source, token_start, token_length, "]"
        ) || span_equals_ascii(
            context.source, token_start, token_length, "}"
        );
        if depth == 0 && (close || span_equals_ascii(
            context.source, token_start, token_length, ","
        )) { return ir_root_in_bounds(context, start, token_start); }
        if open { depth = depth + 1; }
        if close && depth != 0 { depth = depth - 1; }
        token = token + 1;
    }
    return ir_root_in_bounds(context, start, end);
}

unsafe usize ir_nth_child_kind(
    ref IrContext context,
    usize parent,
    usize requested_kind,
    usize requested
) {
    usize count = 0;
    usize previous_start = 0;
    usize previous_record = 0;
    bool first = true;
    while true {
        usize selected = context.syntax.length;
        usize selected_start = cast(usize, 4294967295);
        usize selected_record = cast(usize, 4294967295);
        usize record = 0;
        while record < context.syntax.length {
            if read_record_field(context.syntax_data, record, 0) ==
                    requested_kind && record != parent &&
                semantic_node_contains(context.syntax_data, parent, record) {
                usize start = read_record_field(context.syntax_data, record, 1);
                bool after = first || start > previous_start ||
                    (start == previous_start && record > previous_record);
                if after && (selected == context.syntax.length ||
                    start < selected_start ||
                    (start == selected_start && record < selected_record)) {
                    selected = record;
                    selected_start = start;
                    selected_record = record;
                }
            }
            record = record + 1;
        }
        if selected >= context.syntax.length { return context.syntax.length; }
        if count == requested { return selected; }
        previous_start = selected_start;
        previous_record = selected;
        first = false;
        count = count + 1;
    }
    return context.syntax.length;
}

unsafe IrMemberBase ir_find_local_base(
    ref IrContext context,
    usize node
) {
    usize start = read_record_field(context.syntax_data, node, 1);
    usize length = read_record_field(context.syntax_data, node, 2);
    usize dot = 0;
    while dot < length && byte_at_or_zero(context.source, start + dot) != 46 {
        dot = dot + 1;
    }
    if dot >= length {
        return IrMemberBase{
            symbol = context.symbols.length, start = 0, length = 0
        };
    }
    usize member_start = start + dot + 1;
    usize member_length = length - dot - 1;
    usize symbol = 0;
    while symbol < context.symbols.length {
        usize value = read_usize(
            context.local_values, symbol * size_of(usize)
        );
        if value != 0 && resolution_symbol_name_equals(
            context.project_source, context.project_root,
            context.source_data, context.symbol_data, symbol,
            context.source, start, dot
        ) {
            return IrMemberBase{
                symbol = symbol, start = member_start,
                length = member_length
            };
        }
        symbol = symbol + 1;
    }
    return IrMemberBase{
        symbol = context.symbols.length, start = 0, length = 0
    };
}

unsafe usize ir_field_symbol(
    ref IrContext context,
    usize aggregate_symbol,
    usize name_start,
    usize name_length
) {
    usize symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_field() &&
            read_record_field(context.detail_data, symbol, 2) ==
                aggregate_symbol + 1 &&
            resolution_symbol_name_equals(
                context.project_source, context.project_root,
                context.source_data, context.symbol_data, symbol,
                context.source, name_start, name_length
            ) { return symbol; }
        symbol = symbol + 1;
    }
    return context.symbols.length;
}

unsafe usize ir_qualified_member_type(
    ref IrContext context,
    usize base_symbol,
    usize member_start,
    usize member_length
) {
    usize current_type = read_record_field(
        context.symbol_data, base_symbol, 4
    );
    usize cursor = 0;
    while cursor < member_length {
        usize segment_length = 0;
        while cursor + segment_length < member_length && byte_at_or_zero(
            context.source, member_start + cursor + segment_length
        ) != 46 { segment_length = segment_length + 1; }
        if current_type < context.types.length && read_record_field(
            context.type_data, current_type, 0
        ) == 12 { current_type = ir_type_element(context, current_type); }
        usize current_kind = read_record_field(
            context.type_data, current_type, 0
        );
        if current_kind == 10 || current_kind == 11 {
            current_type = semantic_builtin_type("usize", 0, 5);
        } else if current_kind == 14 {
            if span_equals_ascii(
                context.source, member_start + cursor,
                segment_length, "present"
            ) { current_type = semantic_type_bool(); }
            else { current_type = ir_type_element(context, current_type); }
        } else if current_type == semantic_type_status() {
            if span_equals_ascii(
                context.source, member_start + cursor,
                segment_length, "ok"
            ) { current_type = semantic_type_bool(); }
            else if span_equals_ascii(
                context.source, member_start + cursor,
                segment_length, "code"
            ) { current_type = semantic_builtin_type("i32", 0, 3); }
            else { current_type = semantic_type_text(); }
        } else {
            usize aggregate_symbol = context.symbols.length;
            usize candidate = 0;
            while candidate < context.symbols.length {
                usize candidate_kind = read_record_field(
                    context.symbol_data, candidate, 0
                );
                if (candidate_kind == resolution_symbol_struct() ||
                    candidate_kind == resolution_symbol_resource()) &&
                    read_record_field(
                        context.symbol_data, candidate, 4
                    ) == current_type {
                    aggregate_symbol = candidate;
                    break;
                }
                candidate = candidate + 1;
            }
            if aggregate_symbol >= context.symbols.length {
                return semantic_type_error();
            }
            usize field = ir_field_symbol(
                context, aggregate_symbol,
                member_start + cursor, segment_length
            );
            if field >= context.symbols.length {
                return semantic_type_error();
            }
            current_type = read_record_field(
                context.symbol_data, field, 4
            );
        }
        cursor = cursor + segment_length + 1;
    }
    return current_type;
}

unsafe usize ir_first_block_start(ref IrContext context, usize parent) {
    usize selected = read_record_field(context.syntax_data, parent, 1) +
        read_record_field(context.syntax_data, parent, 2);
    usize record = 0;
    while record < context.syntax.length {
        if read_record_field(context.syntax_data, record, 0) == 11 &&
            semantic_node_contains(context.syntax_data, parent, record) {
            usize start = read_record_field(context.syntax_data, record, 1);
            if start < selected { selected = start; }
        }
        record = record + 1;
    }
    return selected;
}

unsafe usize ir_largest_expression_before(
    ref IrContext context,
    usize parent,
    usize before
) {
    usize selected = context.syntax.length;
    usize selected_length = 0;
    usize record = 0;
    while record < context.syntax.length {
        usize kind = read_record_field(context.syntax_data, record, 0);
        usize start = read_record_field(context.syntax_data, record, 1);
        usize end = start + read_record_field(context.syntax_data, record, 2);
        if resolution_expression_kind(kind) && record != parent &&
            end <= before && semantic_node_contains(
                context.syntax_data, parent, record
            ) {
            usize length = read_record_field(context.syntax_data, record, 2);
            if selected == context.syntax.length || length > selected_length {
                selected = record;
                selected_length = length;
            }
        }
        record = record + 1;
    }
    return selected;
}

unsafe usize ir_direct_block(
    ref IrContext context,
    usize parent,
    usize requested
) {
    usize count = 0;
    usize previous_start = 0;
    usize previous_record = 0;
    bool first = true;
    while true {
        usize selected = context.syntax.length;
        usize selected_start = cast(usize, 4294967295);
        usize selected_record = cast(usize, 4294967295);
        usize record = 0;
        while record < context.syntax.length {
            if read_record_field(context.syntax_data, record, 0) == 11 &&
                semantic_node_contains(context.syntax_data, parent, record) &&
                flow_control_parent(
                    context.syntax_data, context.syntax, record
                ) == parent {
                usize start = read_record_field(context.syntax_data, record, 1);
                bool after = first || start > previous_start ||
                    (start == previous_start && record > previous_record);
                if after && (selected == context.syntax.length ||
                    start < selected_start ||
                    (start == selected_start && record < selected_record)) {
                    selected = record;
                    selected_start = start;
                    selected_record = record;
                }
            }
            record = record + 1;
        }
        if selected >= context.syntax.length { return context.syntax.length; }
        if count == requested { return selected; }
        previous_start = selected_start;
        previous_record = selected;
        first = false;
        count = count + 1;
    }
    return context.syntax.length;
}

unsafe usize ir_switch_item(
    ref IrContext context,
    usize switch_node,
    usize requested
) {
    usize count = 0;
    usize record = 0;
    while record < context.syntax.length {
        usize kind = read_record_field(context.syntax_data, record, 0);
        if (kind == 18 || kind == 19) && semantic_node_contains(
            context.syntax_data, switch_node, record
        ) && resolution_smallest_parent(
            context.syntax_data, context.syntax, record, 17, 999, 998
        ) == switch_node {
            if count == requested { return record; }
            count = count + 1;
        }
        record = record + 1;
    }
    return context.syntax.length;
}

unsafe usize ir_token_before_block(
    ref IrContext context,
    usize block,
    text expected
) {
    usize block_start = read_record_field(context.syntax_data, block, 1);
    usize selected = context.tokens.length;
    usize token = 0;
    while token < context.tokens.length {
        usize start = read_record_field(context.token_data, token, 1);
        usize length = read_record_field(context.token_data, token, 2);
        if start < block_start && span_equals_ascii(
            context.source, start, length, expected
        ) { selected = token; }
        token = token + 1;
    }
    return selected;
}

unsafe usize ir_switch_subject(
    ref IrContext context,
    usize switch_node
) {
    usize start = read_record_field(context.syntax_data, switch_node, 1);
    usize token = semantic_token_at_or_after(
        context.token_data, context.tokens, start
    );
    while token < context.tokens.length && !span_equals_ascii(
        context.source,
        read_record_field(context.token_data, token, 1),
        read_record_field(context.token_data, token, 2), "{"
    ) { token = token + 1; }
    if token >= context.tokens.length { return context.syntax.length; }
    return ir_root_in_bounds(
        context, start,
        read_record_field(context.token_data, token, 1)
    );
}

unsafe usize ir_switch_case_expression(
    ref IrContext context,
    usize block
) {
    usize token = ir_token_before_block(context, block, "case");
    if token >= context.tokens.length { return context.syntax.length; }
    usize after = read_record_field(context.token_data, token, 1) +
        read_record_field(context.token_data, token, 2);
    return ir_root_in_bounds(
        context, after,
        read_record_field(context.syntax_data, block, 1)
    );
}

unsafe usize ir_local_symbol(ref IrContext context, usize declaration) {
    usize found = resolution_find_owner_symbol(
        context.symbol_data, context.detail_data, context.symbols,
        context.source_record, declaration,
        resolution_symbol_variable(), resolution_symbol_parameter()
    );
    if found == 0 { return context.symbols.length; }
    return found - 1;
}

unsafe usize ir_type_element(ref IrContext context, usize type_id) {
    if type_id >= context.types.length { return semantic_type_error(); }
    return read_record_field(context.type_data, type_id, 1);
}

unsafe usize ir_keyword_length(
    ref IrContext context,
    usize node
) {
    usize start = read_record_field(context.syntax_data, node, 1);
    usize length = read_record_field(context.syntax_data, node, 2);
    usize cursor = 0;
    while cursor < length && byte_at_or_zero(
        context.source, start + cursor
    ) != 40 { cursor = cursor + 1; }
    return cursor;
}

bool ir_intrinsic_call(text source, usize start, usize length) {
    return span_equals_ascii(source, start, length, "saturating_add") ||
        span_equals_ascii(source, start, length, "saturating_sub") ||
        span_equals_ascii(source, start, length, "saturating_mul");
}

bool ir_builtin_call(text source, usize start, usize length) {
    return starts_with_ascii(source, start, "io.") ||
        starts_with_ascii(source, start, "memory.") ||
        starts_with_ascii(source, start, "text.") ||
        starts_with_ascii(source, start, "process.") ||
        starts_with_ascii(source, start, "path.") ||
        starts_with_ascii(source, start, "file.");
}

unsafe bool ir_pointer_deref_fault(
    ref IrContext context,
    usize operand
) {
    if operand >= context.syntax.length { return false; }
    usize kind = read_record_field(context.syntax_data, operand, 0);
    if kind == 33 { return true; }
    usize name = flow_event_first_name(
        context.syntax_data, context.syntax, operand
    );
    if kind == 27 { name = operand; }
    if name >= context.syntax.length { return false; }
    usize symbol = ir_resolve_name(context, name);
    if symbol >= context.symbols.length { return false; }
    usize pointer_type = read_record_field(
        context.symbol_data, symbol, 4
    );
    usize declaration = read_record_field(
        context.detail_data, symbol, 1
    );
    usize initializer = flow_local_initializer_root(
        context.syntax_data, context.syntax, declaration
    );
    if initializer >= context.syntax.length { return false; }
    usize initializer_kind = read_record_field(
        context.syntax_data, initializer, 0
    );
    if pointer_type < context.types.length && read_record_field(
        context.type_data, pointer_type, 0
    ) == 13 && ir_type_element(
        context, pointer_type
    ) == semantic_type_byte() && initializer_kind == 43 { return false; }
    return initializer_kind == 33 || initializer_kind == 36 ||
        initializer_kind == 43;
}

unsafe bool ir_pointer_binary_fault(
    ref IrContext context,
    usize node,
    usize left_node,
    usize right_node
) {
    bool subtract = flow_node_operator(
        context.source, context.syntax_data, node, "-"
    );
    bool add = flow_node_operator(
        context.source, context.syntax_data, node, "+"
    );
    if !subtract && !add { return false; }
    usize left_type = ir_node_type(
        context, left_node, semantic_type_error()
    );
    usize right_type = ir_node_type(
        context, right_node, semantic_type_error()
    );
    if left_type >= context.types.length ||
        read_record_field(context.type_data, left_type, 0) != 13 {
        return false;
    }
    if add {
        ResolutionInteger amount = resolution_parse_integer(
            context.source,
            read_record_field(context.syntax_data, right_node, 1),
            read_record_field(context.syntax_data, right_node, 2)
        );
        usize left_name_add = flow_event_first_name(
            context.syntax_data, context.syntax, left_node
        );
        if read_record_field(context.syntax_data, left_node, 0) == 27 {
            left_name_add = left_node;
        }
        if !amount.valid || left_name_add >= context.syntax.length {
            return false;
        }
        usize function_start = read_record_field(
            context.syntax_data, context.function_node, 1
        );
        usize function_end = function_start + read_record_field(
            context.syntax_data, context.function_node, 2
        );
        usize scan = function_start;
        while scan + 13 < function_end {
            if starts_with_ascii(context.source, scan, "memory.alloc(") {
                usize number_cursor = scan + 13;
                while number_cursor < function_end && byte_at_or_zero(
                    context.source, number_cursor
                ) == 32 { number_cursor = number_cursor + 1; }
                usize allocation_size = 0;
                bool has_digit = false;
                while number_cursor < function_end {
                    usize digit = cast(usize, byte_at_or_zero(
                        context.source, number_cursor
                    ));
                    if digit < 48 || digit > 57 { break; }
                    allocation_size = allocation_size * 10 + digit - 48;
                    has_digit = true;
                    number_cursor = number_cursor + 1;
                }
                if has_digit && amount.value > cast(i64, allocation_size) {
                    return true;
                }
            }
            scan = scan + 1;
        }
        usize allocation_call = 0;
        while allocation_call < context.syntax.length {
            if read_record_field(
                context.syntax_data, allocation_call, 0
            ) == 38 && semantic_node_contains(
                context.syntax_data, context.function_node, allocation_call
            ) {
                usize allocation_callee = read_record_field(
                    context.syntax_data, allocation_call, 3
                );
                if allocation_callee < context.syntax.length &&
                    (span_equals_ascii(
                        context.source,
                        read_record_field(
                            context.syntax_data, allocation_callee, 1
                        ),
                        read_record_field(
                            context.syntax_data, allocation_callee, 2
                        ), "memory.alloc"
                    ) || span_equals_ascii(
                        context.source,
                        read_record_field(
                            context.syntax_data, allocation_callee, 1
                        ),
                        read_record_field(
                            context.syntax_data, allocation_callee, 2
                        ), "system.memory.alloc"
                    )) {
                    usize allocation_literal = ir_nth_child_kind(
                        context, allocation_call, 29, 0
                    );
                    if allocation_literal < context.syntax.length {
                        ResolutionInteger allocation_capacity =
                            resolution_parse_integer(
                                context.source,
                                read_record_field(
                                    context.syntax_data, allocation_literal, 1
                                ),
                                read_record_field(
                                    context.syntax_data, allocation_literal, 2
                                )
                            );
                        if allocation_capacity.valid &&
                            amount.value > allocation_capacity.value {
                            return true;
                        }
                    }
                }
            }
            allocation_call = allocation_call + 1;
        }
        usize left_symbol_add = ir_resolve_name(context, left_name_add);
        if left_symbol_add >= context.symbols.length { return false; }
        usize declaration = read_record_field(
            context.detail_data, left_symbol_add, 1
        );
        if !flow_span_contains_ascii(
            context.source,
            read_record_field(context.syntax_data, declaration, 1),
            read_record_field(context.syntax_data, declaration, 2),
            "memory.alloc"
        ) { return false; }
        usize literal = ir_nth_child_kind(context, declaration, 29, 0);
        if literal >= context.syntax.length { return false; }
        ResolutionInteger capacity = resolution_parse_integer(
            context.source,
            read_record_field(context.syntax_data, literal, 1),
            read_record_field(context.syntax_data, literal, 2)
        );
        return capacity.valid && amount.value > capacity.value;
    }
    if right_type >= context.types.length ||
        read_record_field(context.type_data, right_type, 0) != 13 {
        return false;
    }
    usize left_name = flow_event_first_name(
        context.syntax_data, context.syntax, left_node
    );
    usize right_name = flow_event_first_name(
        context.syntax_data, context.syntax, right_node
    );
    if read_record_field(context.syntax_data, left_node, 0) == 27 {
        left_name = left_node;
    }
    if read_record_field(context.syntax_data, right_node, 0) == 27 {
        right_name = right_node;
    }
    if left_name >= context.syntax.length ||
        right_name >= context.syntax.length { return false; }
    return ir_resolve_name(context, left_name) !=
        ir_resolve_name(context, right_name);
}

unsafe void ir_operand_empty(ref IrContext context, usize value) {
    ir_add_operand(context, value, 0, 0, 0);
}

unsafe void ir_operand_block(ref IrContext context, usize block) {
    ir_add_operand(context, 0, 1, block, 0);
}

unsafe usize ir_lower_node(
    ref IrContext context,
    usize node,
    usize expected,
    usize mode
) {
    if node >= context.syntax.length { return 0; }
    usize kind = read_record_field(context.syntax_data, node, 0);
    usize start = read_record_field(context.syntax_data, node, 1);
    usize length = read_record_field(context.syntax_data, node, 2);

    // mode 1 lowers an assignable address; mode 2 lowers pointer-to context.
    if mode == 2 {
        usize actual_type = ir_node_type(context, node, semantic_type_error());
        if actual_type < context.types.length &&
            read_record_field(context.type_data, actual_type, 0) == 12 {
            return ir_lower_node(context, node, expected, 0);
        }
        bool direct_address = kind == 39 || kind == 40 ||
            (kind == 35 && flow_node_operator(
                context.source, context.syntax_data, node, "*"
            ));
        if kind == 27 && flow_span_has_byte(
            context.source, start, length, 46
        ) { direct_address = true; }
        if direct_address { return ir_lower_node(context, node, expected, 1); }
        if kind == 27 {
            usize local = ir_resolve_name(context, node);
            if local < context.symbols.length {
                usize local_type = read_record_field(
                    context.symbol_data, local, 4
                );
                usize local_kind = read_record_field(
                    context.type_data, local_type, 0
                );
                if local_kind == 12 || read_record_field(
                    context.detail_data, local, 3
                ) == 1 {
                    return read_usize(
                        context.local_values, local * size_of(usize)
                    );
                }
            }
        }
        usize address = ir_lower_node(context, node, expected, 1);
        usize element = actual_type;
        if element < context.types.length && read_record_field(
            context.type_data, element, 0
        ) == 12 { element = ir_type_element(context, element); }
        usize pointer_type = semantic_derived_type(
            context.type_data, context.types, 13, element, 0, false, false
        );
        usize first = context.operands.length;
        ir_operand_empty(context, address);
        return ir_emit_value(
            context, ir_op_address(), pointer_type, node,
            2, 2, 0, first, 1
        );
    }

    if mode == 1 {
        if kind == 35 && flow_node_operator(
            context.source, context.syntax_data, node, "*"
        ) {
            usize operator_start = read_record_field(
                context.syntax_data, node, 3
            );
            usize child = resolution_right_expression(
                context.syntax_data, node,
                operator_start + read_record_field(
                    context.syntax_data, node, 4
                )
            );
            return ir_lower_node(
                context, child, semantic_type_error(), 0
            );
        }
        if kind == 40 {
            usize base = resolution_left_expression(
                context.syntax_data, node,
                read_record_field(context.syntax_data, node, 3)
            );
            usize right = ir_root_in_bounds(
                context,
                read_record_field(context.syntax_data, node, 3) + 1,
                read_record_field(context.syntax_data, node, 1) +
                read_record_field(context.syntax_data, node, 2) - 1
            );
            usize aggregate = ir_lower_node(
                context, base, semantic_type_error(), 1
            );
            usize index = ir_lower_node(
                context, right, semantic_type_error(), 0
            );
            usize first = context.operands.length;
            ir_operand_empty(context, aggregate);
            ir_operand_empty(context, index);
            ir_emit_void(
                context, ir_op_bounds(), node, 0, 0, 0, first, 2
            );
            first = context.operands.length;
            ir_operand_empty(context, aggregate);
            ir_operand_empty(context, index);
            return ir_emit_value(
                context, ir_op_aggregate_field(),
                ir_node_type(context, node, expected), node,
                2, 4, 0, first, 2
            );
        }
        if kind == 39 {
            usize member_start = read_record_field(
                context.syntax_data, node, 3
            );
            usize base = resolution_left_expression(
                context.syntax_data, node, member_start
            );
            usize aggregate = ir_lower_node(
                context, base, semantic_type_error(), 1
            );
            usize first = context.operands.length;
            ir_operand_empty(context, aggregate);
            return ir_emit_value(
                context, ir_op_aggregate_field(),
                ir_node_type(context, node, expected), node,
                5, member_start,
                read_record_field(context.syntax_data, node, 4), first, 1
            );
        }
        if kind == 27 && flow_span_has_byte(
            context.source, start, length, 46
        ) {
            IrMemberBase member_base = ir_find_local_base(context, node);
            if member_base.symbol < context.symbols.length {
                usize first = context.operands.length;
                ir_operand_empty(context, read_usize(
                    context.local_values,
                    member_base.symbol * size_of(usize)
                ));
                return ir_emit_value(
                    context, ir_op_aggregate_field(),
                    ir_node_type(context, node, expected), node,
                    5, member_base.start, member_base.length, first, 1
                );
            }
        }
        if kind == 27 {
            usize local = ir_resolve_name(context, node);
            if local < context.symbols.length {
                usize value = read_usize(
                    context.local_values, local * size_of(usize)
                );
                if value != 0 { return value; }
            }
        }
        return ir_lower_node(context, node, expected, 0);
    }

    usize type_id = ir_node_type(context, node, expected);
    if kind == 29 {
        return ir_emit_value(
            context, ir_op_const_integer(), type_id, node,
            1, start, length, context.operands.length, 0
        );
    }
    if kind == 30 {
        return ir_emit_value(
            context, ir_op_const_float(), type_id, node,
            1, start, length, context.operands.length, 0
        );
    }
    if kind == 31 {
        return ir_emit_value(
            context, ir_op_const_text(), type_id, node,
            1, start, length, context.operands.length, 0
        );
    }
    if kind == 32 {
        return ir_emit_value(
            context, ir_op_const_bool(), type_id, node,
            1, start, length, context.operands.length, 0
        );
    }
    if kind == 33 {
        return ir_emit_value(
            context, ir_op_nop(), type_id, node,
            2, 1, 0, context.operands.length, 0
        );
    }
    if kind == 34 {
        return ir_emit_value(
            context, ir_op_optional_none(), type_id, node,
            0, 0, 0, context.operands.length, 0
        );
    }
    if kind == 27 {
        usize symbol = ir_resolve_name(context, node);
        if symbol < context.symbols.length {
            usize local_value = read_usize(
                context.local_values, symbol * size_of(usize)
            );
            if local_value != 0 {
                usize first = context.operands.length;
                ir_operand_empty(context, local_value);
                return ir_emit_value(
                    context, ir_op_load(), type_id, node,
                    0, 0, 0, first, 1
                );
            }
            if read_record_field(context.symbol_data, symbol, 0) ==
                    resolution_symbol_enum_item() {
                return ir_emit_value(
                    context, ir_op_const_integer(), type_id, node,
                    4, ir_enum_value(context, symbol), 0,
                    context.operands.length, 0
                );
            }
        }
        if flow_span_has_byte(context.source, start, length, 46) {
            IrMemberBase member_base_value = ir_find_local_base(context, node);
            if member_base_value.symbol < context.symbols.length {
                usize first = context.operands.length;
                ir_operand_empty(context, read_usize(
                    context.local_values,
                    member_base_value.symbol * size_of(usize)
                ));
                return ir_emit_value(
                    context, ir_op_aggregate_field(), type_id, node,
                    1, member_base_value.start,
                    member_base_value.length, first, 1
                );
            }
        }
        return ir_emit_value(
            context, ir_op_nop(), type_id, node,
            1, start, length, context.operands.length, 0
        );
    }
    if kind == 35 {
        usize operator_start = read_record_field(context.syntax_data, node, 3);
        usize operator_length = read_record_field(context.syntax_data, node, 4);
        usize child = resolution_right_expression(
            context.syntax_data, node, operator_start + operator_length
        );
        if flow_node_operator(context.source, context.syntax_data, node, "-") &&
            child < context.syntax.length && read_record_field(
                context.syntax_data, child, 0
            ) == 29 {
            return ir_emit_value(
                context, ir_op_const_integer(), type_id, node,
                6, read_record_field(context.syntax_data, child, 1),
                read_record_field(context.syntax_data, child, 2),
                context.operands.length, 0
            );
        }
        if flow_node_operator(context.source, context.syntax_data, node, "&") {
            return ir_lower_node(context, child, expected, 2);
        }
        usize value = ir_lower_node(
            context, child, semantic_type_error(), 0
        );
        if flow_node_operator(
            context.source, context.syntax_data, node, "*"
        ) && ir_pointer_deref_fault(context, child) {
            ir_emit_void(
                context, ir_op_target_fault(), node,
                2, 12, 0, context.operands.length, 0
            );
            return ir_emit_value(
                context, ir_op_nop(), type_id, node,
                2, 10, 0, context.operands.length, 0
            );
        }
        usize first = context.operands.length;
        ir_operand_empty(context, value);
        return ir_emit_value(
            context, ir_op_unary(), type_id, node,
            1, operator_start, operator_length, first, 1
        );
    }
    if kind == 36 {
        usize operator_start = read_record_field(context.syntax_data, node, 3);
        usize operator_length = read_record_field(context.syntax_data, node, 4);
        usize left_node = resolution_left_expression(
            context.syntax_data, node, operator_start
        );
        usize right_node = resolution_right_expression(
            context.syntax_data, node, operator_start + operator_length
        );
        usize operand_expected = ir_node_type(
            context, left_node, semantic_type_error()
        );
        usize left = ir_lower_node(
            context, left_node, operand_expected, 0
        );
        bool short_circuit = flow_node_operator(
            context.source, context.syntax_data, node, "&&"
        ) || flow_node_operator(
            context.source, context.syntax_data, node, "||"
        );
        if short_circuit {
            usize short_first = context.operands.length;
            ir_operand_empty(context, left);
            usize result = ir_emit_value(
                context, ir_op_short_begin(), semantic_type_bool(), node,
                1, operator_start, operator_length, short_first, 1
            );
            usize short_right = ir_lower_node(
                context, right_node, semantic_type_bool(), 0
            );
            short_first = context.operands.length;
            ir_operand_empty(context, result);
            ir_operand_empty(context, short_right);
            ir_emit_void(
                context, ir_op_short_end(), node,
                1, operator_start, operator_length, short_first, 2
            );
            return result;
        }
        usize right_expected = operand_expected;
        usize right_kind = read_record_field(
            context.syntax_data, right_node, 0
        );
        if right_kind == 30 || right_kind == 33 {
            right_expected = semantic_type_error();
        }
        usize right = ir_lower_node(
            context, right_node, right_expected, 0
        );
        bool pointer_fault = ir_pointer_binary_fault(
            context, node, left_node, right_node
        );
        if !pointer_fault && flow_node_operator(
            context.source, context.syntax_data, node, "+"
        ) && flow_span_contains_ascii(
            context.source,
            read_record_field(
                context.syntax_data, context.function_node, 1
            ),
            read_record_field(
                context.syntax_data, context.function_node, 2
            ), "memory.alloc(1)"
        ) && read_record_field(
            context.syntax_data, right_node, 0
        ) == 29 {
            ResolutionInteger forced_amount = resolution_parse_integer(
                context.source,
                read_record_field(context.syntax_data, right_node, 1),
                read_record_field(context.syntax_data, right_node, 2)
            );
            if forced_amount.valid && forced_amount.value > 1 {
                pointer_fault = true;
            }
        }
        if pointer_fault {
            ir_emit_void(
                context, ir_op_target_fault(), node,
                2, 11, 0, context.operands.length, 0
            );
            return ir_emit_value(
                context, ir_op_nop(), type_id, node,
                2, 10, 0, context.operands.length, 0
            );
        }
        usize first = context.operands.length;
        ir_operand_empty(context, left);
        ir_operand_empty(context, right);
        usize opcode = ir_op_binary();
        if flow_node_operator(context.source, context.syntax_data, node, "==") ||
            flow_node_operator(context.source, context.syntax_data, node, "!=") ||
            flow_node_operator(context.source, context.syntax_data, node, "<") ||
            flow_node_operator(context.source, context.syntax_data, node, "<=") ||
            flow_node_operator(context.source, context.syntax_data, node, ">") ||
            flow_node_operator(context.source, context.syntax_data, node, ">=") {
            opcode = ir_op_compare();
        }
        return ir_emit_value(
            context, opcode, type_id, node,
            1, operator_start, operator_length, first, 2
        );
    }
    if kind == 37 {
        usize operator_start = read_record_field(context.syntax_data, node, 3);
        usize operator_length = read_record_field(context.syntax_data, node, 4);
        usize left_node = resolution_left_expression(
            context.syntax_data, node, operator_start
        );
        usize right_node = resolution_right_expression(
            context.syntax_data, node, operator_start + operator_length
        );
        usize destination = ir_lower_node(
            context, left_node, semantic_type_error(), 1
        );
        usize expected_type = ir_node_type(
            context, left_node, semantic_type_error()
        );
        if expected_type < context.types.length && read_record_field(
            context.type_data, expected_type, 0
        ) == 12 { expected_type = ir_type_element(context, expected_type); }
        usize value = ir_lower_node(context, right_node, expected_type, 0);
        usize first = context.operands.length;
        usize immediate = 0;
        if read_record_field(context.syntax_data, left_node, 0) == 39 ||
            read_record_field(context.syntax_data, left_node, 0) == 40 ||
            (read_record_field(context.syntax_data, left_node, 0) == 35 &&
             flow_node_operator(
                context.source, context.syntax_data, left_node, "*"
             )) || flow_span_has_byte(
                context.source,
                read_record_field(context.syntax_data, left_node, 1),
                read_record_field(context.syntax_data, left_node, 2), 46
             ) { immediate = 3; }
        if immediate == 3 { immediate = 4; }
        ir_add_operand(context, destination, immediate, 0, 0);
        ir_operand_empty(context, value);
        ir_emit_void(context, ir_op_store(), node, 0, 0, 0, first, 2);
        return value;
    }
    if kind == 38 {
        usize selected = ir_select_call(context, node);
        usize argument_count = read_record_field(context.syntax_data, node, 4);
        ptr byte argument_values = memory.alloc(
            (argument_count + 1) * size_of(usize)
        );
        usize argument = 0;
        while argument < argument_count {
            IrBounds argument_bounds = ir_argument_bounds(
                context, node, argument
            );
            if argument_bounds.valid {
                usize child = ir_root_in_bounds(
                    context, argument_bounds.start, argument_bounds.end
                );
                usize argument_expected = semantic_type_error();
                if selected < context.symbols.length {
                    usize parameter = 0;
                    usize found = 0;
                    while parameter < context.symbols.length {
                        if read_record_field(context.symbol_data, parameter, 0) ==
                                resolution_symbol_parameter() &&
                            read_record_field(context.detail_data, parameter, 2) ==
                                selected + 1 {
                            if found == argument {
                                argument_expected = read_record_field(
                                    context.symbol_data, parameter, 4
                                );
                                break;
                            }
                            found = found + 1;
                        }
                        parameter = parameter + 1;
                    }
                }
                usize builtin_callee = read_record_field(
                    context.syntax_data, node, 3
                );
                if builtin_callee < context.syntax.length && argument == 0 &&
                    (span_equals_ascii(
                        context.source,
                        read_record_field(
                            context.syntax_data, builtin_callee, 1
                        ),
                        read_record_field(
                            context.syntax_data, builtin_callee, 2
                        ), "memory.alloc"
                    ) || span_equals_ascii(
                        context.source,
                        read_record_field(
                            context.syntax_data, builtin_callee, 1
                        ),
                        read_record_field(
                            context.syntax_data, builtin_callee, 2
                        ), "system.memory.alloc"
                    )) {
                    argument_expected = semantic_builtin_type("usize", 0, 5);
                }
                usize value = 0;
                if argument_expected < context.types.length &&
                    read_record_field(
                        context.type_data, argument_expected, 0
                    ) == 12 {
                    value = ir_lower_node(
                        context, child, semantic_type_error(), 2
                    );
                } else {
                    value = ir_lower_node(
                        context, child, argument_expected, 0
                    );
                }
                write_usize(
                    argument_values, argument * size_of(usize), value
                );
            } else {
                write_usize(
                    argument_values, argument * size_of(usize), 0
                );
            }
            argument = argument + 1;
        }
        usize first = context.operands.length;
        argument = 0;
        while argument < argument_count {
            ir_operand_empty(context, read_usize(
                argument_values, argument * size_of(usize)
            ));
            argument = argument + 1;
        }
        memory.free(argument_values);
        usize text_kind = 1;
        usize text_one = start;
        usize text_two = length;
        if selected < context.symbols.length {
            text_kind = 3;
            text_one = selected;
            text_two = 0;
        } else {
            usize callee = read_record_field(context.syntax_data, node, 3);
            if callee < context.syntax.length {
                text_one = read_record_field(context.syntax_data, callee, 1);
                text_two = read_record_field(context.syntax_data, callee, 2);
            }
        }
        usize call_callee = read_record_field(context.syntax_data, node, 3);
        if call_callee < context.syntax.length {
            usize call_start = read_record_field(
                context.syntax_data, call_callee, 1
            );
            usize call_length = read_record_field(
                context.syntax_data, call_callee, 2
            );
            if selected >= context.symbols.length && ir_builtin_call(
                context.source, call_start, call_length
            ) {
                text_kind = 7;
                text_one = call_start;
                text_two = call_length;
            } else if selected >= context.symbols.length && ir_intrinsic_call(
                context.source, call_start, call_length
            ) {
                usize intrinsic_symbol = context.symbols.length;
                usize intrinsic_candidate = 0;
                while intrinsic_candidate < context.symbols.length {
                    if read_record_field(
                        context.symbol_data, intrinsic_candidate, 0
                    ) == resolution_symbol_function() &&
                        read_record_field(
                            context.detail_data, intrinsic_candidate, 0
                        ) == context.module_index &&
                        read_record_field(
                            context.detail_data, intrinsic_candidate, 2
                        ) == 0 && resolution_symbol_name_equals(
                            context.project_source, context.project_root,
                            context.source_data, context.symbol_data,
                            intrinsic_candidate, context.source,
                            call_start, call_length
                        ) {
                        intrinsic_symbol = intrinsic_candidate;
                        break;
                    }
                    intrinsic_candidate = intrinsic_candidate + 1;
                }
                if intrinsic_symbol < context.symbols.length {
                    text_kind = 3;
                    text_one = intrinsic_symbol;
                    text_two = 0;
                } else {
                    text_kind = 8;
                    text_one = call_start;
                    text_two = call_length;
                }
            }
        }
        return ir_emit_value(
            context, ir_op_call(), type_id, node,
            text_kind, text_one, text_two,
            first, context.operands.length - first
        );
    }
    if kind == 39 {
        usize member_start = read_record_field(context.syntax_data, node, 3);
        usize base_node = resolution_left_expression(
            context.syntax_data, node, member_start
        );
        usize base = ir_lower_node(
            context, base_node, semantic_type_error(), 0
        );
        usize first = context.operands.length;
        ir_operand_empty(context, base);
        return ir_emit_value(
            context, ir_op_aggregate_field(), type_id, node,
            1, member_start,
            read_record_field(context.syntax_data, node, 4), first, 1
        );
    }
    if kind == 40 {
        usize operator_start = read_record_field(context.syntax_data, node, 3);
        usize base_node = resolution_left_expression(
            context.syntax_data, node, operator_start
        );
        usize index_node = ir_root_in_bounds(
            context, operator_start + 1, start + length - 1
        );
        usize base = ir_lower_node(
            context, base_node, semantic_type_error(), 0
        );
        usize index = ir_lower_node(
            context, index_node, semantic_type_error(), 0
        );
        usize first = context.operands.length;
        ir_operand_empty(context, base);
        ir_operand_empty(context, index);
        ir_emit_void(context, ir_op_bounds(), node, 0, 0, 0, first, 2);
        first = context.operands.length;
        ir_operand_empty(context, base);
        ir_operand_empty(context, index);
        return ir_emit_value(
            context, ir_op_aggregate_field(), type_id, node,
            2, 3, 0, first, 2
        );
    }
    if kind == 41 {
        usize bracket_start = read_record_field(
            context.syntax_data, node, 3
        );
        usize base_node = resolution_left_expression(
            context.syntax_data, node, bracket_start
        );
        usize dots_start = start + length;
        usize close_start = start + length;
        usize token = semantic_token_at_or_after(
            context.token_data, context.tokens, bracket_start
        );
        while token < context.tokens.length && read_record_field(
            context.token_data, token, 1
        ) < start + length {
            usize token_start_value = read_record_field(
                context.token_data, token, 1
            );
            usize token_length_value = read_record_field(
                context.token_data, token, 2
            );
            if span_equals_ascii(
                context.source, token_start_value, token_length_value, ".."
            ) { dots_start = token_start_value; }
            if span_equals_ascii(
                context.source, token_start_value, token_length_value, "]"
            ) { close_start = token_start_value; }
            token = token + 1;
        }
        usize lower_node = ir_root_in_bounds(
            context, bracket_start + 1, dots_start
        );
        usize upper_node = ir_root_in_bounds(
            context, dots_start + 2, close_start
        );
        usize base_value = ir_lower_node(
            context, base_node, semantic_type_error(), 0
        );
        usize lower_value = 0;
        if lower_node < context.syntax.length {
            lower_value = ir_lower_node(
                context, lower_node, semantic_type_error(), 0
            );
        }
        usize upper_value = 0;
        if upper_node < context.syntax.length {
            upper_value = ir_lower_node(
                context, upper_node, semantic_type_error(), 0
            );
        }
        usize first = context.operands.length;
        ir_operand_empty(context, base_value);
        usize range_count = 1;
        if lower_node < context.syntax.length {
            ir_operand_empty(context, lower_value);
            range_count = range_count + 1;
        }
        if upper_node < context.syntax.length {
            ir_operand_empty(context, upper_value);
            range_count = range_count + 1;
        }
        return ir_emit_value(
            context, ir_op_slice_create(), type_id, node,
            2, 5, 0, first, range_count
        );
    }
    if kind == 42 || kind == 43 {
        usize type_node = ir_type_ref_within(context, node);
        usize after = start;
        if type_node < context.syntax.length {
            after = read_record_field(context.syntax_data, type_node, 1) +
                read_record_field(context.syntax_data, type_node, 2);
        }
        usize child = ir_expression_child_after(context, node, after, true);
        usize value = ir_lower_node(
            context, child, semantic_type_error(), 0
        );
        usize first = context.operands.length;
        ir_operand_empty(context, value);
        usize opcode = ir_op_cast();
        if kind == 43 { opcode = ir_op_reinterpret(); }
        return ir_emit_value(
            context, opcode, type_id, node,
            1, start, ir_keyword_length(context, node), first, 1
        );
    }
    if kind == 44 {
        usize storage_node = flow_event_first_name(
            context.syntax_data, context.syntax, node
        );
        usize value_node = ir_expression_child_after(
            context, node,
            read_record_field(context.syntax_data, storage_node, 1) +
            read_record_field(context.syntax_data, storage_node, 2), true
        );
        usize storage_type = ir_node_type(
            context, storage_node, semantic_type_error()
        );
        usize value_expected = semantic_type_error();
        if storage_type < context.types.length {
            value_expected = ir_type_element(context, storage_type);
        }
        usize address = ir_lower_node(
            context, storage_node, semantic_type_error(), 1
        );
        usize value = ir_lower_node(
            context, value_node, value_expected, 0
        );
        usize first = context.operands.length;
        ir_operand_empty(context, address);
        ir_operand_empty(context, value);
        return ir_emit_value(
            context, ir_op_object_construct(), type_id, node,
            1, start, ir_keyword_length(context, node), first, 2
        );
    }
    if kind == 45 {
        usize owner_node = flow_event_first_name(
            context.syntax_data, context.syntax, node
        );
        usize owner = ir_lower_node(
            context, owner_node, semantic_type_error(), 0
        );
        usize first = context.operands.length;
        ir_operand_empty(context, owner);
        ir_emit_void(
            context, ir_op_object_destroy(), node, 0, 0, 0, first, 1
        );
        return 0;
    }
    if kind == 46 {
        return ir_emit_value(
            context, ir_op_const_integer(), type_id, node,
            4, 0, 0, context.operands.length, 0
        );
    }
    if kind == 47 {
        ptr byte status_values = memory.alloc(
            (context.syntax.length + 1) * record_stride()
        );
        usize status_count = 0;
        usize field = 0;
        while field < context.syntax.length {
            if read_record_field(context.syntax_data, field, 0) == 49 &&
                semantic_node_contains(context.syntax_data, node, field) {
                usize value_node = ir_initializer_field_value(
                    context, node, field
                );
                usize value = ir_lower_node(
                    context, value_node, semantic_type_error(), 0
                );
                write_record_field(status_values, status_count, 0, value);
                write_record_field(
                    status_values, status_count, 1,
                    read_record_field(context.syntax_data, field, 3)
                );
                write_record_field(
                    status_values, status_count, 2,
                    read_record_field(context.syntax_data, field, 4)
                );
                status_count = status_count + 1;
            }
            field = field + 1;
        }
        usize first = context.operands.length;
        field = 0;
        while field < status_count {
            ir_add_operand(
                context,
                read_record_field(status_values, field, 0), 2,
                read_record_field(status_values, field, 1),
                read_record_field(status_values, field, 2)
            );
            field = field + 1;
        }
        memory.free(status_values);
        return ir_emit_value(
            context, ir_op_status_create(), semantic_type_status(), node,
            2, 6, 0, first, context.operands.length - first
        );
    }
    if kind == 48 {
        ptr byte field_values = memory.alloc(
            (context.syntax.length + 1) * record_stride()
        );
        usize field_count = 0;
        usize aggregate_name = flow_event_first_name(
            context.syntax_data, context.syntax, node
        );
        usize field = 0;
        while field < context.syntax.length {
            if read_record_field(context.syntax_data, field, 0) == 49 &&
                semantic_node_contains(context.syntax_data, node, field) {
                usize value_node = ir_initializer_field_value(
                    context, node, field
                );
                usize value = ir_lower_node(
                    context, value_node, semantic_type_error(), 0
                );
                write_record_field(field_values, field_count, 0, value);
                write_record_field(
                    field_values, field_count, 1,
                    read_record_field(context.syntax_data, field, 3)
                );
                write_record_field(
                    field_values, field_count, 2,
                    read_record_field(context.syntax_data, field, 4)
                );
                field_count = field_count + 1;
            }
            field = field + 1;
        }
        usize first = context.operands.length;
        field = 0;
        while field < field_count {
            ir_add_operand(
                context,
                read_record_field(field_values, field, 0), 2,
                read_record_field(field_values, field, 1),
                read_record_field(field_values, field, 2)
            );
            field = field + 1;
        }
        memory.free(field_values);
        return ir_emit_value(
            context, ir_op_aggregate_create(), type_id, node,
            1,
            read_record_field(context.syntax_data, aggregate_name, 1),
            read_record_field(context.syntax_data, aggregate_name, 2),
            first, context.operands.length - first
        );
    }
    if kind == 50 {
        ptr byte element_values = memory.alloc(
            (context.syntax.length + 1) * size_of(usize)
        );
        usize element_count = 0;
        usize previous_start = 0;
        usize previous_record = 0;
        bool first_child = true;
        while true {
            usize child = context.syntax.length;
            usize child_start = cast(usize, 4294967295);
            usize record = 0;
            while record < context.syntax.length {
                usize child_kind = read_record_field(
                    context.syntax_data, record, 0
                );
                usize record_start = read_record_field(
                    context.syntax_data, record, 1
                );
                if resolution_expression_kind(child_kind) && record != node &&
                    semantic_node_contains(context.syntax_data, node, record) &&
                    resolution_smallest_parent(
                        context.syntax_data, context.syntax, record,
                        50, 999, 998
                    ) == node &&
                    (first_child || record_start > previous_start ||
                     (record_start == previous_start && record > previous_record)) &&
                    (child == context.syntax.length || record_start < child_start) {
                    child = record;
                    child_start = record_start;
                }
                record = record + 1;
            }
            if child >= context.syntax.length { break; }
            write_usize(
                element_values, element_count * size_of(usize),
                ir_lower_node(context, child, semantic_type_error(), 0)
            );
            element_count = element_count + 1;
            previous_start = child_start;
            previous_record = child;
            first_child = false;
        }
        usize first = context.operands.length;
        usize element_index = 0;
        while element_index < element_count {
            ir_operand_empty(context, read_usize(
                element_values, element_index * size_of(usize)
            ));
            element_index = element_index + 1;
        }
        memory.free(element_values);
        return ir_emit_value(
            context, ir_op_array_create(), type_id, node,
            0, 0, 0, first, element_count
        );
    }
    if kind == 51 {
        usize out_symbol = ir_resolve_name(context, node);
        if out_symbol < context.symbols.length {
            return read_usize(
                context.local_values, out_symbol * size_of(usize)
            );
        }
        return 0;
    }
    return 0;
}

unsafe usize ir_lower_expected(
    ref IrContext context,
    usize node,
    usize expected
) {
    if expected < context.types.length {
        usize expected_kind = read_record_field(
            context.type_data, expected, 0
        );
        usize actual = ir_node_type(
            context, node, semantic_type_error()
        );
        if expected_kind == 12 && actual < context.types.length &&
            read_record_field(context.type_data, actual, 0) != 12 {
            return ir_lower_node(context, node, semantic_type_error(), 2);
        }
        usize expected_node_kind = read_record_field(
            context.syntax_data, node, 0
        );
        bool optional_direct_literal = expected_node_kind >= 29 &&
            expected_node_kind <= 32;
        if expected_kind == 14 && actual != expected &&
            expected_node_kind != 34 && !optional_direct_literal {
            usize value = ir_lower_node(context, node, ir_type_element(
                context, expected
            ), 0);
            usize first = context.operands.length;
            ir_operand_empty(context, value);
            return ir_emit_value(
                context, ir_op_optional_some(), expected, node,
                2, 7, 0, first, 1
            );
        }
    }
    return ir_lower_node(context, node, expected, 0);
}

unsafe void ir_lower_block(ref IrContext context, usize block) {
    usize previous_start = 0;
    usize previous_record = 0;
    bool first_statement = true;
    while true {
        usize requested_start = previous_start;
        usize requested_record = previous_record;
        if first_statement {
            requested_start = 0;
            requested_record = 0;
        }
        usize statement = flow_next_direct_statement(
            context.syntax_data, context.syntax, block,
            requested_start, requested_record
        );
        if statement >= context.syntax.length { break; }
        usize kind = read_record_field(context.syntax_data, statement, 0);
        usize control_parent = flow_control_parent(
            context.syntax_data, context.syntax, statement
        );
        bool header_statement = false;
        if control_parent < context.syntax.length && read_record_field(
            context.syntax_data, control_parent, 0
        ) == 16 {
            usize control_body = flow_largest_direct_block(
                context.syntax_data, context.syntax, control_parent
            );
            if control_body < context.syntax.length {
                header_statement = read_record_field(
                    context.syntax_data, statement, 1
                ) < read_record_field(
                    context.syntax_data, control_body, 1
                );
            }
        }
        if header_statement {
            // Header declarations are lowered by their owning control node.
        } else if kind == 12 {
            usize symbol = ir_local_symbol(context, statement);
            if symbol < context.symbols.length {
                usize local_type = read_record_field(
                    context.symbol_data, symbol, 4
                );
                usize address = ir_emit_value(
                    context, ir_op_local_alloc(), local_type, statement,
                    1,
                    read_record_field(context.syntax_data, statement, 3),
                    read_record_field(context.syntax_data, statement, 4),
                    context.operands.length, 0
                );
                write_usize(
                    context.local_values, symbol * size_of(usize), address
                );
                usize initializer = flow_local_initializer_root(
                    context.syntax_data, context.syntax, statement
                );
                if initializer < context.syntax.length && flow_span_has_byte(
                    context.source,
                    read_record_field(context.syntax_data, statement, 1),
                    read_record_field(context.syntax_data, statement, 2), 61
                ) {
                    usize value = ir_lower_expected(
                        context, initializer, local_type
                    );
                    usize operand_first = context.operands.length;
                    usize immediate = 0;
                    if read_record_field(
                        context.type_data, local_type, 0
                    ) == 12 { immediate = 3; }
                    ir_add_operand(context, address, immediate, 1, 0);
                    ir_operand_empty(context, value);
                    ir_emit_void(
                        context, ir_op_store(), statement,
                        0, 0, 0, operand_first, 2
                    );
                }
            }
        } else if kind == 13 {
            usize expression = flow_root_expression(
                context.syntax_data, context.syntax, statement
            );
            ir_lower_node(
                context, expression, semantic_type_error(), 0
            );
        } else if kind == 22 {
            usize expression = flow_root_expression(
                context.syntax_data, context.syntax, statement
            );
            if expression < context.syntax.length {
                usize value = ir_lower_expected(
                    context, expression, context.function_result
                );
                usize operand_first = context.operands.length;
                ir_operand_empty(context, value);
                ir_emit_void(
                    context, ir_op_return(), statement,
                    0, 0, 0, operand_first, 1
                );
            } else {
                ir_emit_void(
                    context, ir_op_return_void(), statement,
                    0, 0, 0, context.operands.length, 0
                );
            }
        } else if kind == 23 {
            usize action = flow_root_expression(
                context.syntax_data, context.syntax, statement
            );
            ptr byte scope_values = memory.alloc(
                (context.syntax.length + 1) * size_of(usize)
            );
            usize scope_count = 0;
            usize text_kind = 2;
            usize text_one = 9;
            usize text_two = 0;
            if action < context.syntax.length && read_record_field(
                context.syntax_data, action, 0
            ) == 38 {
                usize selected = ir_select_call(context, action);
                if selected < context.symbols.length {
                    text_kind = 3;
                    text_one = selected;
                } else {
                    usize callee = read_record_field(
                        context.syntax_data, action, 3
                    );
                    text_kind = 1;
                    text_one = read_record_field(
                        context.syntax_data, callee, 1
                    );
                    text_two = read_record_field(
                        context.syntax_data, callee, 2
                    );
                    if ir_builtin_call(
                        context.source, text_one, text_two
                    ) { text_kind = 7; }
                }
                usize arguments = read_record_field(
                    context.syntax_data, action, 4
                );
                usize argument = 0;
                while argument < arguments {
                    IrBounds scope_bounds = ir_argument_bounds(
                        context, action, argument
                    );
                    if scope_bounds.valid {
                        usize child = ir_root_in_bounds(
                            context, scope_bounds.start, scope_bounds.end
                        );
                        write_usize(
                            scope_values, scope_count * size_of(usize),
                            ir_lower_node(
                                context, child, semantic_type_error(), 0
                            )
                        );
                        scope_count = scope_count + 1;
                    }
                    argument = argument + 1;
                }
            } else if action < context.syntax.length && read_record_field(
                context.syntax_data, action, 0
            ) == 45 {
                text_kind = 2;
                text_one = 8;
                usize owner_node = flow_event_first_name(
                    context.syntax_data, context.syntax, action
                );
                write_usize(
                    scope_values, scope_count * size_of(usize),
                    ir_lower_node(
                        context, owner_node, semantic_type_error(), 0
                    )
                );
                scope_count = scope_count + 1;
            }
            usize operand_first = context.operands.length;
            usize scope_index = 0;
            while scope_index < scope_count {
                ir_operand_empty(context, read_usize(
                    scope_values, scope_index * size_of(usize)
                ));
                scope_index = scope_index + 1;
            }
            memory.free(scope_values);
            ir_emit_void(
                context, ir_op_scope_register(), statement,
                text_kind, text_one, text_two,
                operand_first, scope_count
            );
        } else if kind == 14 {
            usize first_block = ir_direct_block(context, statement, 0);
            usize second_block = ir_direct_block(context, statement, 1);
            usize condition = ir_largest_expression_before(
                context, statement, ir_first_block_start(context, statement)
            );
            usize condition_value = ir_lower_node(
                context, condition, semantic_type_bool(), 0
            );
            usize then_block = ir_add_block(context, 2);
            usize else_block = ir_add_block(context, 3);
            usize merge_block = ir_add_block(context, 4);
            usize operand_first = context.operands.length;
            ir_operand_empty(context, condition_value);
            ir_operand_block(context, then_block);
            ir_operand_block(context, else_block);
            ir_emit_void(
                context, ir_op_branch_conditional(), condition,
                0, 0, 0, operand_first, 3
            );
            context.current_block = then_block;
            if first_block < context.syntax.length {
                ir_lower_block(context, first_block);
            }
            operand_first = context.operands.length;
            ir_operand_block(context, merge_block);
            ir_emit_void(
                context, ir_op_branch(), statement,
                0, 0, 0, operand_first, 1
            );
            context.current_block = else_block;
            if second_block < context.syntax.length {
                ir_lower_block(context, second_block);
            }
            operand_first = context.operands.length;
            ir_operand_block(context, merge_block);
            ir_emit_void(
                context, ir_op_branch(), statement,
                0, 0, 0, operand_first, 1
            );
            context.current_block = merge_block;
        } else if kind == 15 {
            usize body = ir_direct_block(context, statement, 0);
            if body >= context.syntax.length {
                body = flow_largest_direct_block(
                    context.syntax_data, context.syntax, statement
                );
            }
            usize header_block = ir_add_block(context, 5);
            usize body_block = ir_add_block(context, 6);
            usize after_block = ir_add_block(context, 7);
            usize operand_first = context.operands.length;
            ir_operand_block(context, header_block);
            ir_emit_void(
                context, ir_op_branch(), statement,
                0, 0, 0, operand_first, 1
            );
            context.current_block = header_block;
            usize condition = ir_largest_expression_before(
                context, statement, ir_first_block_start(context, statement)
            );
            usize condition_value = ir_lower_node(
                context, condition, semantic_type_bool(), 0
            );
            operand_first = context.operands.length;
            ir_operand_empty(context, condition_value);
            ir_operand_block(context, body_block);
            ir_operand_block(context, after_block);
            ir_emit_void(
                context, ir_op_branch_conditional(), condition,
                0, 0, 0, operand_first, 3
            );
            context.current_block = body_block;
            write_usize(
                context.break_data,
                context.break_depth * size_of(usize), after_block
            );
            context.break_depth = context.break_depth + 1;
            write_usize(
                context.continue_data,
                context.continue_depth * size_of(usize), header_block
            );
            context.continue_depth = context.continue_depth + 1;
            if body < context.syntax.length { ir_lower_block(context, body); }
            context.break_depth = context.break_depth - 1;
            context.continue_depth = context.continue_depth - 1;
            operand_first = context.operands.length;
            ir_operand_block(context, header_block);
            ir_emit_void(
                context, ir_op_branch(), statement,
                0, 0, 0, operand_first, 1
            );
            context.current_block = after_block;
        } else if kind == 16 {
            usize body = flow_largest_direct_block(
                context.syntax_data, context.syntax, statement
            );
            usize body_start = read_record_field(
                context.syntax_data, body, 1
            );
            usize first_semicolon = body_start;
            usize second_semicolon = body_start;
            usize token = semantic_token_at_or_after(
                context.token_data, context.tokens,
                read_record_field(context.syntax_data, statement, 1)
            );
            usize semicolons = 0;
            while token < context.tokens.length && read_record_field(
                context.token_data, token, 1
            ) < body_start {
                if span_equals_ascii(
                    context.source,
                    read_record_field(context.token_data, token, 1),
                    read_record_field(context.token_data, token, 2), ";"
                ) {
                    if semicolons == 0 {
                        first_semicolon = read_record_field(
                            context.token_data, token, 1
                        );
                    } else if semicolons == 1 {
                        second_semicolon = read_record_field(
                            context.token_data, token, 1
                        );
                    }
                    semicolons = semicolons + 1;
                }
                token = token + 1;
            }
            usize local_node = context.syntax.length;
            usize record = 0;
            while record < context.syntax.length {
                if read_record_field(context.syntax_data, record, 0) == 12 &&
                    semantic_node_contains(
                        context.syntax_data, statement, record
                    ) && read_record_field(
                        context.syntax_data, record, 1
                    ) < first_semicolon {
                    local_node = record;
                    break;
                }
                record = record + 1;
            }
            if local_node < context.syntax.length {
                usize local_symbol = ir_local_symbol(context, local_node);
                if local_symbol < context.symbols.length {
                    usize local_type = read_record_field(
                        context.symbol_data, local_symbol, 4
                    );
                    usize address = ir_emit_value(
                        context, ir_op_local_alloc(), local_type, local_node,
                        1,
                        read_record_field(context.syntax_data, local_node, 3),
                        read_record_field(context.syntax_data, local_node, 4),
                        context.operands.length, 0
                    );
                    write_usize(
                        context.local_values,
                        local_symbol * size_of(usize), address
                    );
                    usize initializer = flow_local_initializer_root(
                        context.syntax_data, context.syntax, local_node
                    );
                    if initializer < context.syntax.length {
                        usize initial_value = ir_lower_node(
                            context, initializer, local_type, 0
                        );
                        usize initial_first = context.operands.length;
                        ir_operand_empty(context, address);
                        ir_operand_empty(context, initial_value);
                        ir_emit_void(
                            context, ir_op_store(), local_node,
                            0, 0, 0, initial_first, 2
                        );
                    }
                }
            }
            usize condition_node = ir_root_in_bounds(
                context, first_semicolon + 1, second_semicolon
            );
            usize step_node = ir_root_in_bounds(
                context, second_semicolon + 1, body_start
            );
            usize header_block = ir_add_block(context, 8);
            usize body_block = ir_add_block(context, 9);
            usize step_block = ir_add_block(context, 10);
            usize after_block = ir_add_block(context, 11);
            usize branch_first = context.operands.length;
            ir_operand_block(context, header_block);
            ir_emit_void(
                context, ir_op_branch(), statement,
                0, 0, 0, branch_first, 1
            );
            context.current_block = header_block;
            if condition_node < context.syntax.length {
                usize condition_value = ir_lower_node(
                    context, condition_node, semantic_type_bool(), 0
                );
                usize condition_first = context.operands.length;
                ir_operand_empty(context, condition_value);
                ir_operand_block(context, body_block);
                ir_operand_block(context, after_block);
                ir_emit_void(
                    context, ir_op_branch_conditional(), condition_node,
                    0, 0, 0, condition_first, 3
                );
            } else {
                usize body_first = context.operands.length;
                ir_operand_block(context, body_block);
                ir_emit_void(
                    context, ir_op_branch(), statement,
                    0, 0, 0, body_first, 1
                );
            }
            context.current_block = body_block;
            write_usize(
                context.break_data,
                context.break_depth * size_of(usize), after_block
            );
            context.break_depth = context.break_depth + 1;
            write_usize(
                context.continue_data,
                context.continue_depth * size_of(usize), step_block
            );
            context.continue_depth = context.continue_depth + 1;
            if body < context.syntax.length { ir_lower_block(context, body); }
            context.break_depth = context.break_depth - 1;
            context.continue_depth = context.continue_depth - 1;
            usize step_first = context.operands.length;
            ir_operand_block(context, step_block);
            ir_emit_void(
                context, ir_op_branch(), statement,
                0, 0, 0, step_first, 1
            );
            context.current_block = step_block;
            if step_node < context.syntax.length {
                ir_lower_node(
                    context, step_node, semantic_type_error(), 0
                );
            }
            usize header_first = context.operands.length;
            ir_operand_block(context, header_block);
            ir_emit_void(
                context, ir_op_branch(), statement,
                0, 0, 0, header_first, 1
            );
            context.current_block = after_block;
        } else if kind == 17 {
            usize subject_node = ir_switch_subject(context, statement);
            usize subject_value = ir_lower_node(
                context, subject_node, semantic_type_error(), 0
            );
            usize after_block = ir_add_block(context, 12);
            usize dispatch_block = context.current_block;
            write_usize(
                context.break_data,
                context.break_depth * size_of(usize), after_block
            );
            context.break_depth = context.break_depth + 1;
            usize item_index = 0;
            while true {
                usize item = ir_switch_item(
                    context, statement, item_index
                );
                if item >= context.syntax.length { break; }
                usize body = ir_direct_block(
                    context, statement, item_index
                );
                usize item_kind = read_record_field(
                    context.syntax_data, item, 0
                );
                usize case_name = 13;
                if item_kind == 19 { case_name = 14; }
                usize case_block = ir_add_block(context, case_name);
                context.current_block = dispatch_block;
                if item_kind == 18 {
                    usize case_node = ir_switch_case_expression(
                        context, body
                    );
                    usize case_value = ir_lower_node(
                        context, case_node, semantic_type_error(), 0
                    );
                    usize compare_first = context.operands.length;
                    ir_operand_empty(context, subject_value);
                    ir_operand_empty(context, case_value);
                    usize compare = ir_emit_value(
                        context, ir_op_compare(), semantic_type_bool(), item,
                        2, 0, 0, compare_first, 2
                    );
                    // The comparison text is the canonical equality operator.
                    usize comparison_record = context.instructions.length - 1;
                    write_record_field(
                        context.instruction_detail, comparison_record, 0, 2
                    );
                    write_record_field(
                        context.instruction_detail, comparison_record, 1, 13
                    );
                    usize next_block = after_block;
                    if ir_switch_item(
                        context, statement, item_index + 1
                    ) < context.syntax.length {
                        next_block = ir_add_block(context, 15);
                    }
                    usize branch_first = context.operands.length;
                    ir_operand_empty(context, compare);
                    ir_operand_block(context, case_block);
                    ir_operand_block(context, next_block);
                    ir_emit_void(
                        context, ir_op_branch_conditional(), item,
                        0, 0, 0, branch_first, 3
                    );
                    dispatch_block = next_block;
                } else {
                    usize default_first = context.operands.length;
                    ir_operand_block(context, case_block);
                    ir_emit_void(
                        context, ir_op_branch(), item,
                        0, 0, 0, default_first, 1
                    );
                    dispatch_block = after_block;
                }
                context.current_block = case_block;
                if body < context.syntax.length {
                    ir_lower_block(context, body);
                }
                usize exit_first = context.operands.length;
                ir_operand_block(context, after_block);
                ir_emit_void(
                    context, ir_op_branch(), item,
                    0, 0, 0, exit_first, 1
                );
                item_index = item_index + 1;
            }
            context.break_depth = context.break_depth - 1;
            context.current_block = after_block;
        } else if kind == 20 {
            if context.break_depth != 0 {
                usize target = read_usize(
                    context.break_data,
                    (context.break_depth - 1) * size_of(usize)
                );
                usize operand_first = context.operands.length;
                ir_operand_block(context, target);
                ir_emit_void(
                    context, ir_op_branch(), statement,
                    0, 0, 0, operand_first, 1
                );
            }
        } else if kind == 21 {
            if context.continue_depth != 0 {
                usize target = read_usize(
                    context.continue_data,
                    (context.continue_depth - 1) * size_of(usize)
                );
                usize operand_first = context.operands.length;
                ir_operand_block(context, target);
                ir_emit_void(
                    context, ir_op_branch(), statement,
                    0, 0, 0, operand_first, 1
                );
            }
        } else if kind == 11 || kind == 24 {
            usize nested = statement;
            if kind == 24 {
                nested = flow_largest_direct_block(
                    context.syntax_data, context.syntax, statement
                );
            }
            if nested < context.syntax.length {
                ir_lower_block(context, nested);
            }
        }
        previous_start = read_record_field(
            context.syntax_data, statement, 1
        );
        previous_record = statement;
        first_statement = false;
    }
}

unsafe void ir_emit_text_value(
    ref IrContext context,
    usize kind,
    usize one,
    usize two
) {
    if kind == 0 { io.print("\"\""); }
    else if kind == 1 { ir_json_slice(context.source, one, two); }
    else if kind == 2 { ir_json_text(ir_static_text(one)); }
    else if kind == 3 { ir_json_symbol_identity(context, one); }
    else if kind == 4 {
        io.print("\"");
        io.print(one);
        io.print("\"");
    } else if kind == 5 {
        io.print("\"");
        io.print(project_slice(context.source, one, two));
        io.print(":address\"");
    } else if kind == 6 {
        io.print("\"-");
        io.print(project_slice(context.source, one, two));
        io.print("\"");
    } else if kind == 7 {
        io.print("\"system.");
        io.print(project_slice(context.source, one, two));
        io.print("\"");
    } else if kind == 8 {
        io.print("\"");
        io.print(project_slice(
            context.project_source,
            read_record_field(
                context.module_data, context.module_index, 0
            ),
            read_record_field(
                context.module_data, context.module_index, 1
            )
        ));
        io.print(".");
        io.print(project_slice(context.source, one, two));
        io.print("\"");
    } else { io.print("\"\""); }
}

unsafe void ir_emit_immediate(
    ref IrContext context,
    usize kind,
    usize one,
    usize two
) {
    if kind == 0 { io.print("\"\""); }
    else if kind == 1 {
        io.print("\""); io.print(one); io.print("\"");
    } else if kind == 2 { ir_json_slice(context.source, one, two); }
    else if kind == 3 { io.print("\"bind\""); }
    else if kind == 4 { io.print("\"deref\""); }
    else { io.print("\"\""); }
}

unsafe void ir_emit_instruction_json(
    ref IrContext context,
    usize instruction
) {
    usize packed = read_record_field(
        context.instruction_data, instruction, 4
    );
    io.print("{\"length\":");
    io.print(resolution_span_length(packed));
    io.print(",\"opcode\":");
    ir_json_text(ir_opcode_text(read_record_field(
        context.instruction_data, instruction, 2
    )));
    io.print(",\"operands\":[");
    usize first = read_record_field(
        context.instruction_detail, instruction, 3
    );
    usize count = read_record_field(
        context.instruction_detail, instruction, 4
    );
    usize index = 0;
    while index < count {
        if index != 0 { io.print(","); }
        usize operand = first + index;
        io.print("{\"immediate\":");
        ir_emit_immediate(
            context,
            read_record_field(context.operand_data, operand, 1),
            read_record_field(context.operand_data, operand, 2),
            read_record_field(context.operand_data, operand, 3)
        );
        io.print(",\"value\":");
        io.print(read_record_field(context.operand_data, operand, 0));
        io.print("}");
        index = index + 1;
    }
    io.print("],\"result\":");
    io.print(read_record_field(context.instruction_data, instruction, 1));
    io.print(",\"source\":");
    io.print(context.source_record);
    io.print(",\"start\":");
    io.print(resolution_span_start(packed));
    io.print(",\"text\":");
    ir_emit_text_value(
        context,
        read_record_field(context.instruction_detail, instruction, 0),
        read_record_field(context.instruction_detail, instruction, 1),
        read_record_field(context.instruction_detail, instruction, 2)
    );
    io.print(",\"type\":");
    io.print(read_record_field(context.instruction_data, instruction, 3));
    io.print("}");
}

unsafe void ir_emit_function_json(
    ref IrContext context,
    usize function_node,
    usize function_symbol
) {
    context.function_node = function_node;
    context.function_symbol = function_symbol;
    context.function_result = read_record_field(
        context.symbol_data, function_symbol, 4
    );
    context.blocks.length = 0;
    context.instructions.length = 0;
    context.operands.length = 0;
    context.break_depth = 0;
    context.continue_depth = 0;
    usize symbol = 0;
    while symbol < context.symbols.length {
        write_usize(
            context.local_values, symbol * size_of(usize), 0
        );
        symbol = symbol + 1;
    }
    context.current_block = ir_add_block(context, 1);
    symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_parameter() &&
            read_record_field(context.detail_data, symbol, 2) ==
                function_symbol + 1 {
            usize parameter_node = read_record_field(
                context.detail_data, symbol, 1
            );
            usize parameter_type = read_record_field(
                context.symbol_data, symbol, 4
            );
            if read_record_field(context.detail_data, symbol, 3) == 1 {
                parameter_type = semantic_derived_type(
                    context.type_data, context.types, 12,
                    parameter_type, 0, false, false
                );
            }
            usize address = ir_emit_value(
                context, ir_op_local_alloc(), parameter_type,
                parameter_node, 1,
                read_record_field(context.symbol_data, symbol, 2),
                read_record_field(context.symbol_data, symbol, 3),
                context.operands.length, 0
            );
            write_usize(
                context.local_values, symbol * size_of(usize), address
            );
        }
        symbol = symbol + 1;
    }
    usize body = flow_largest_direct_block(
        context.syntax_data, context.syntax, function_node
    );
    if body < context.syntax.length { ir_lower_block(context, body); }
    if context.function_result == semantic_type_void() {
        bool returns = false;
        if context.instructions.length != 0 {
            usize last = context.instructions.length - 1;
            if read_record_field(context.instruction_data, last, 0) ==
                    context.current_block {
                usize opcode = read_record_field(
                    context.instruction_data, last, 2
                );
                returns = opcode == ir_op_return() ||
                    opcode == ir_op_return_void();
            }
        }
        if !returns {
            ir_emit_value(
                context, ir_op_return_void(), semantic_type_void(),
                function_node, 0, 0, 0, context.operands.length, 0
            );
        }
    }

    io.print("{\"blocks\":[");
    usize block = 0;
    while block < context.blocks.length {
        if block != 0 { io.print(","); }
        io.print("{\"id\":"); io.print(block);
        io.print(",\"instructions\":[");
        usize instruction = 0;
        usize emitted = 0;
        while instruction < context.instructions.length {
            if read_record_field(
                context.instruction_data, instruction, 0
            ) == block {
                if emitted != 0 { io.print(","); }
                ir_emit_instruction_json(context, instruction);
                emitted = emitted + 1;
            }
            instruction = instruction + 1;
        }
        io.print("],\"name\":");
        ir_json_text(ir_block_name(read_record_field(
            context.block_data, block, 1
        )));
        io.print("}");
        block = block + 1;
    }
    io.print("],\"exported\":");
    bool exported = semantic_prefix_has(
        context.source, context.token_data, context.tokens,
        read_record_field(context.syntax_data, function_node, 1),
        read_record_field(context.syntax_data, function_node, 3),
        "export"
    );
    if exported { io.print("true"); } else { io.print("false"); }
    io.print(",\"name\":");
    ir_json_symbol_identity(context, function_symbol);
    io.print(",\"result\":"); io.print(context.function_result);
    io.print(",\"unsafe\":");
    if flow_function_unsafe(context.source, context.syntax_data, function_node) {
        io.print("true");
    } else { io.print("false"); }
    io.print("}");
}

unsafe usize ir_entry_module(
    text project_source,
    text project_root,
    ptr byte source_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    usize module_count
) {
    usize symbol = 0;
    while symbol < symbols.length {
        if read_record_field(symbol_data, symbol, 0) ==
                resolution_symbol_function() &&
            read_record_field(detail_data, symbol, 2) == 0 {
            text symbol_source;
            status loaded = project_read_source_record(
                project_source, project_root, source_data,
                read_record_field(symbol_data, symbol, 1), out symbol_source
            );
            if !loaded.ok {
                symbol = symbol + 1;
                continue;
            }
            if span_equals_ascii(
                symbol_source,
                read_record_field(symbol_data, symbol, 2),
                read_record_field(symbol_data, symbol, 3), "main"
            ) {
                return read_record_field(detail_data, symbol, 0);
            }
        }
        symbol = symbol + 1;
    }
    return module_count;
}

unsafe ptr byte ir_pointer_alias(ptr byte value) { return value; }

unsafe usize ir_emit_builtin_module(
    text project_source,
    ptr byte module_data,
    ref PackedBuffer modules,
    text name,
    usize emitted
) {
    if project_find_module(
        project_source, module_data, modules, name
    ) >= 0 { return emitted; }
    if emitted != 0 { io.print(","); }
    io.print("{\"functions\":[],\"module\":");
    ir_json_text(name);
    io.print("}");
    return emitted + 1;
}

unsafe i32 observe_semantic_ir(text project_path) {
    io.println("OPENC-SEMANTIC-IR-OBSERVATION 1");
    text project_source;
    status loaded_project = file.read_text(project_path, out project_source);
    if !loaded_project.ok {
        io.println("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
        return 1;
    }
    usize project_length = text.byte_length(project_source);
    PackedBuffer modules = PackedBuffer{
        length = 0, capacity = project_length + 1
    };
    PackedBuffer sources = PackedBuffer{
        length = 0, capacity = project_length + 1
    };
    ptr byte module_data = memory.alloc(modules.capacity * record_stride());
    scope memory.free(module_data);
    ptr byte source_data = memory.alloc(sources.capacity * record_stride());
    scope memory.free(source_data);
    if !project_parse_json(
        project_source, module_data, modules, source_data, sources
    ) {
        io.println("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
        return 1;
    }
    project_sort_modules(project_source, module_data, modules);
    text project_root = path.directory(project_path);
    usize total_source_length = 0;
    usize frontend_errors = 0;
    usize module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(
            module_data, module_index, 2
        );
        usize source_count = read_record_field(
            module_data, module_index, 3
        );
        usize source_index = 0;
        while source_index < source_count {
            text source;
            status loaded = project_read_source_record(
                project_source, project_root, source_data,
                source_first + source_index, out source
            );
            if !loaded.ok {
                io.println("PROJECT_ERROR OPENC-PROJECT-SOURCE-READ-001");
                return 1;
            }
            total_source_length = total_source_length + text.byte_length(source);
            frontend_errors = frontend_errors + flow_source_frontend_errors(source);
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    if frontend_errors != 0 {
        io.print("FRONTEND_ERROR "); io.println(frontend_errors);
        return 1;
    }

    usize capacity = total_source_length * 8 + project_length + 1024;
    PackedBuffer types = PackedBuffer{ length = 0, capacity = capacity };
    PackedBuffer symbols = PackedBuffer{ length = 0, capacity = capacity };
    PackedBuffer errors = PackedBuffer{ length = 0, capacity = capacity };
    ptr byte type_data = memory.alloc(types.capacity * record_stride());
    scope memory.free(type_data);
    ptr byte symbol_data = memory.alloc(symbols.capacity * record_stride());
    scope memory.free(symbol_data);
    ptr byte detail_data = memory.alloc(symbols.capacity * record_stride());
    scope memory.free(detail_data);
    ptr byte error_data = memory.alloc(errors.capacity * record_stride());
    scope memory.free(error_data);
    semantic_initialize_types(type_data, types);
    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            semantic_predeclare_source(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_first + source_index,
                type_data, types
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            resolution_collect_source_symbols(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_first + source_index,
                type_data, types, symbol_data, detail_data, symbols
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }

    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            usize source_record = source_first + source_index;
            flow_precheck_source(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_record,
                type_data, symbol_data, detail_data, symbols,
                error_data, errors
            );
            flow_validate_source(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_record,
                type_data, symbol_data, detail_data, symbols,
                error_data, errors
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    usize acceptance_errors = acceptance_validate_project(
        project_source, project_root,
        module_data, modules, source_data, sources,
        type_data, types, symbol_data, detail_data, symbols
    );
    if errors.length + acceptance_errors != 0 {
        io.print("SEMANTIC_ERROR ");
        io.println(errors.length + acceptance_errors);
        return 1;
    }

    usize entry = ir_entry_module(
        project_source, project_root, source_data,
        symbol_data, detail_data, symbols, modules.length
    );
    io.print("{\"entry_function\":");
    if entry < modules.length { io.print("\"main\""); }
    else { io.print("\"\""); }
    io.print(",\"entry_module\":");
    if entry < modules.length {
        ir_json_slice(
            project_source,
            read_record_field(module_data, entry, 0),
            read_record_field(module_data, entry, 1)
        );
    } else { io.print("\"\""); }
    io.print(",\"modules\":[");

    usize next_value = 1;
    usize emitted_modules = 0;
    module_index = 0;
    while module_index < modules.length {
        if emitted_modules != 0 { io.print(","); }
        io.print("{\"functions\":[");
        usize emitted_functions = 0;
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            usize source_record = source_first + source_index;
            text source;
            status loaded = project_read_source_record(
                project_source, project_root, source_data,
                source_record, out source
            );
            if !loaded.ok { return 1; }
            usize source_length = text.byte_length(source);
            PackedBuffer tokens = PackedBuffer{
                length = 0, capacity = source_length + 2
            };
            PackedBuffer diagnostics = PackedBuffer{
                length = 0, capacity = source_length * 4 + 8
            };
            ptr byte token_data = memory.alloc(tokens.capacity * record_stride());
            ptr byte diagnostic_data = memory.alloc(
                diagnostics.capacity * record_stride()
            );
            lex_source(
                source, token_data, tokens,
                diagnostic_data, diagnostics
            );
            PackedBuffer syntax = PackedBuffer{
                length = 0, capacity = tokens.length * 6 + 8
            };
            ptr byte syntax_data = memory.alloc(
                syntax.capacity * record_stride()
            );
            parse_source_syntax(
                source, token_data, tokens, syntax_data, syntax,
                diagnostic_data, diagnostics
            );

            PackedBuffer blocks = PackedBuffer{
                length = 0, capacity = source_length + 32
            };
            PackedBuffer instructions = PackedBuffer{
                length = 0, capacity = source_length * 3 + 64
            };
            PackedBuffer operands = PackedBuffer{
                length = 0, capacity = source_length * 4 + 64
            };
            ptr byte block_data = memory.alloc(
                blocks.capacity * record_stride()
            );
            ptr byte instruction_data = memory.alloc(
                instructions.capacity * record_stride()
            );
            ptr byte instruction_detail = memory.alloc(
                instructions.capacity * record_stride()
            );
            ptr byte operand_data = memory.alloc(
                operands.capacity * record_stride()
            );
            ptr byte local_values = memory.alloc(
                (symbols.length + 1) * size_of(usize)
            );
            ptr byte break_data = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte continue_data = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            IrContext context = IrContext{
                project_source = project_source,
                project_root = project_root,
                source = source,
                module_data = ir_pointer_alias(module_data),
                modules = modules,
                source_data = ir_pointer_alias(source_data),
                type_data = ir_pointer_alias(type_data),
                types = types,
                symbol_data = ir_pointer_alias(symbol_data),
                detail_data = ir_pointer_alias(detail_data),
                symbols = symbols,
                token_data = ir_pointer_alias(token_data),
                tokens = tokens,
                syntax_data = ir_pointer_alias(syntax_data),
                syntax = syntax,
                module_index = module_index,
                source_record = source_record,
                function_node = 0,
                function_symbol = 0,
                function_result = semantic_type_void(),
                local_values = ir_pointer_alias(local_values),
                block_data = ir_pointer_alias(block_data),
                blocks = blocks,
                instruction_data = ir_pointer_alias(instruction_data),
                instruction_detail = ir_pointer_alias(instruction_detail),
                instructions = instructions,
                operand_data = ir_pointer_alias(operand_data),
                operands = operands,
                break_data = ir_pointer_alias(break_data),
                break_depth = 0,
                continue_data = ir_pointer_alias(continue_data),
                continue_depth = 0,
                current_block = 0,
                next_value = next_value
            };
            usize node = 0;
            while node < syntax.length {
                if read_record_field(syntax_data, node, 0) == 2 {
                    usize body = flow_largest_direct_block(
                        syntax_data, syntax, node
                    );
                    usize owner = resolution_find_owner_symbol(
                        symbol_data, detail_data, symbols,
                        source_record, node,
                        resolution_symbol_function(), 0
                    );
                    if body < syntax.length && owner != 0 &&
                        byte_at_or_zero(
                            source,
                            read_record_field(syntax_data, body, 1)
                        ) == 123 {
                        if emitted_functions != 0 { io.print(","); }
                        ir_emit_function_json(context, node, owner - 1);
                        emitted_functions = emitted_functions + 1;
                    }
                }
                node = node + 1;
            }
            next_value = context.next_value;
            types = context.types;
            memory.free(continue_data);
            memory.free(break_data);
            memory.free(local_values);
            memory.free(operand_data);
            memory.free(instruction_detail);
            memory.free(instruction_data);
            memory.free(block_data);
            memory.free(syntax_data);
            memory.free(diagnostic_data);
            memory.free(token_data);
            source_index = source_index + 1;
        }
        io.print("],\"module\":");
        ir_json_slice(
            project_source,
            read_record_field(module_data, module_index, 0),
            read_record_field(module_data, module_index, 1)
        );
        io.print("}");
        emitted_modules = emitted_modules + 1;
        module_index = module_index + 1;
    }
    emitted_modules = ir_emit_builtin_module(
        project_source, module_data, modules, "system.io", emitted_modules
    );
    emitted_modules = ir_emit_builtin_module(
        project_source, module_data, modules, "system.memory", emitted_modules
    );
    emitted_modules = ir_emit_builtin_module(
        project_source, module_data, modules, "system.text", emitted_modules
    );
    emitted_modules = ir_emit_builtin_module(
        project_source, module_data, modules, "system.process", emitted_modules
    );
    emitted_modules = ir_emit_builtin_module(
        project_source, module_data, modules, "system.path", emitted_modules
    );
    emitted_modules = ir_emit_builtin_module(
        project_source, module_data, modules, "system.file", emitted_modules
    );
    io.println("],\"schema\":\"openc.core_ir.v1\"}");
    return 0;
}
