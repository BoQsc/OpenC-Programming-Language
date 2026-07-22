import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

struct FlowCounts {
    usize functions;
    usize blocks;
    usize edges;
    usize cleanups;
}

struct FlowCfg {
    usize blocks;
    usize edges;
    bool terminal;
    usize break_depth;
    usize continue_depth;
}

unsafe bool flow_function_has_word(
    text source,
    ptr byte syntax_data,
    usize function_node,
    text word
) {
    usize start = read_record_field(syntax_data, function_node, 1);
    usize end = start + read_record_field(syntax_data, function_node, 2);
    usize length = text.byte_length(word);
    usize cursor = start;
    while cursor + length <= end {
        bool left = cursor == start ||
            !is_identifier_continue(byte_at_or_zero(source, cursor - 1));
        bool right = cursor + length == end ||
            !is_identifier_continue(byte_at_or_zero(source, cursor + length));
        if left && right && starts_with_ascii(source, cursor, word) {
            return true;
        }
        cursor = cursor + 1;
    }
    return false;
}

usize flow_phase_name() { return 1; }
usize flow_phase_type() { return 2; }
usize flow_phase_flow() { return 3; }
usize flow_phase_ownership() { return 4; }
usize flow_phase_borrow() { return 5; }
usize flow_phase_unsafe() { return 6; }

usize flow_rule_safe_init() { return 1; }
usize flow_rule_status_duplicate() { return 2; }
usize flow_rule_status_code() { return 3; }
usize flow_rule_out_status() { return 4; }
usize flow_rule_out_carrier() { return 5; }
usize flow_rule_out_function_status() { return 6; }
usize flow_rule_out_return() { return 7; }
usize flow_rule_own_exit() { return 8; }
usize flow_rule_own_overwrite() { return 9; }
usize flow_rule_resource_duplicate_owner() { return 10; }
usize flow_rule_scope_owner_state() { return 11; }
usize flow_rule_own_cleanup_reserved() { return 12; }
usize flow_rule_own_double_discharge() { return 13; }
usize flow_rule_own_use_destroy() { return 14; }
usize flow_rule_own_use_move() { return 15; }
usize flow_rule_lifetime_use_destroy() { return 16; }
usize flow_rule_borrow_move() { return 17; }
usize flow_rule_borrow_conflict() { return 18; }
usize flow_rule_scope_action() { return 19; }
usize flow_rule_scope_nofail() { return 20; }
usize flow_rule_pointer_onepast() { return 21; }
usize flow_rule_pointer_address() { return 22; }
usize flow_rule_pointer_deref() { return 23; }
usize flow_rule_pointer_arithmetic() { return 24; }
usize flow_rule_reinterpret() { return 25; }
usize flow_rule_unsafe_required() { return 26; }
usize flow_rule_unsafe_call() { return 27; }

text flow_phase_text(usize phase) {
    if phase == flow_phase_name() { return "name"; }
    if phase == flow_phase_type() { return "type"; }
    if phase == flow_phase_flow() { return "flow"; }
    if phase == flow_phase_ownership() { return "ownership"; }
    if phase == flow_phase_borrow() { return "borrow"; }
    return "unsafe";
}

text flow_rule_text(usize rule) {
    if rule == flow_rule_safe_init() { return "OPENC-SAFE-INIT-001"; }
    if rule == flow_rule_status_duplicate() { return "OPENC-STATUS-FIELD-DUPLICATE-001"; }
    if rule == flow_rule_status_code() { return "OPENC-STATUS-CODE-001"; }
    if rule == flow_rule_out_status() { return "OPENC-OUT-STATUS-001"; }
    if rule == flow_rule_out_carrier() { return "OPENC-OUT-CARRIER-001"; }
    if rule == flow_rule_out_function_status() { return "OPENC-OUT-FUNCTION-STATUS-001"; }
    if rule == flow_rule_out_return() { return "OPENC-OUT-RETURN-001"; }
    if rule == flow_rule_own_exit() { return "OPENC-OWN-EXIT-001"; }
    if rule == flow_rule_own_overwrite() { return "OPENC-OWN-OVERWRITE-001"; }
    if rule == flow_rule_resource_duplicate_owner() { return "OPENC-RESOURCE-INIT-DUPLICATE-OWNER-001"; }
    if rule == flow_rule_scope_owner_state() { return "OPENC-SCOPE-OWNER-STATE-001"; }
    if rule == flow_rule_own_cleanup_reserved() { return "OPENC-OWN-CLEANUP-RESERVED-001"; }
    if rule == flow_rule_own_double_discharge() { return "OPENC-OWN-DOUBLE-DISCHARGE-001"; }
    if rule == flow_rule_own_use_destroy() { return "OPENC-OWN-USE-AFTER-DESTROY-001"; }
    if rule == flow_rule_own_use_move() { return "OPENC-OWN-USE-AFTER-MOVE-001"; }
    if rule == flow_rule_lifetime_use_destroy() { return "OPENC-LIFETIME-USE-AFTER-DESTROY-001"; }
    if rule == flow_rule_borrow_move() { return "OPENC-BORROW-MOVE-001"; }
    if rule == flow_rule_borrow_conflict() { return "OPENC-BORROW-CONFLICT-001"; }
    if rule == flow_rule_scope_action() { return "OPENC-SCOPE-ACTION-001"; }
    if rule == flow_rule_scope_nofail() { return "OPENC-SCOPE-NOFAIL-001"; }
    if rule == flow_rule_pointer_onepast() { return "OPENC-PTR-ONEPAST-001"; }
    if rule == flow_rule_pointer_address() { return "OPENC-PTR-ADDRESS-UNSAFE-001"; }
    if rule == flow_rule_pointer_deref() { return "OPENC-PTR-DEREF-UNSAFE-001"; }
    if rule == flow_rule_pointer_arithmetic() { return "OPENC-PTR-ARITH-UNSAFE-001"; }
    if rule == flow_rule_reinterpret() { return "OPENC-REINTERPRET-UNSAFE-001"; }
    if rule == flow_rule_unsafe_required() { return "OPENC-UNSAFE-REQUIRED-001"; }
    return "OPENC-UNSAFE-CALL-001";
}

unsafe void flow_record_error(
    ptr byte error_data,
    ref PackedBuffer errors,
    usize source_record,
    usize start,
    usize length,
    usize phase,
    usize rule
) {
    usize record = errors.length;
    write_record_field(error_data, record, 0, source_record);
    write_record_field(error_data, record, 1, start);
    write_record_field(error_data, record, 2, length);
    write_record_field(error_data, record, 3, rule);
    write_record_field(error_data, record, 4, phase);
    errors.length = errors.length + 1;
}

bool flow_statement_kind(usize kind) {
    return kind >= 11 && kind <= 25;
}

bool flow_expression_kind(usize kind) {
    return kind >= 27 && kind <= 51;
}

unsafe usize flow_smallest_block_parent(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize child
) {
    usize selected = syntax.length;
    usize selected_length = cast(usize, 4294967295);
    usize record = 0;
    while record < syntax.length {
        if record != child && read_record_field(syntax_data, record, 0) == 11 &&
            semantic_node_contains(syntax_data, record, child) {
            usize length = read_record_field(syntax_data, record, 2);
            if length < selected_length {
                selected = record;
                selected_length = length;
            }
        }
        record = record + 1;
    }
    return selected;
}

unsafe usize flow_largest_direct_block(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize parent
) {
    usize selected = syntax.length;
    usize selected_length = 0;
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == 11 &&
            semantic_node_contains(syntax_data, parent, record) {
            usize length = read_record_field(syntax_data, record, 2);
            if selected == syntax.length || length > selected_length {
                selected = record;
                selected_length = length;
            }
        }
        record = record + 1;
    }
    return selected;
}

unsafe usize flow_control_parent(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize child
) {
    usize first = resolution_smallest_parent(
        syntax_data, syntax, child, 14, 15, 16
    );
    usize second = resolution_smallest_parent(
        syntax_data, syntax, child, 17, 18, 19
    );
    usize third = resolution_smallest_parent(
        syntax_data, syntax, child, 24, 25, 999
    );
    usize selected = first;
    if second < syntax.length &&
        (selected >= syntax.length ||
         read_record_field(syntax_data, second, 2) <
         read_record_field(syntax_data, selected, 2)) {
        selected = second;
    }
    if third < syntax.length &&
        (selected >= syntax.length ||
         read_record_field(syntax_data, third, 2) <
         read_record_field(syntax_data, selected, 2)) {
        selected = third;
    }
    return selected;
}
