import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

struct IrScalarState {
    bool enabled;
    usize preflight_reason;
    usize expected_assignments;
    usize expected_binaries;
    usize expected_conditions;
    usize visited_assignments;
    usize visited_binaries;
    usize visited_conditions;
    usize errors;
    usize legacy_assignment_visits;
    usize legacy_binary_visits;
    usize covered_uncached_type_calls;
}

IrScalarState ir_scalar_state_empty() {
    return IrScalarState{
        enabled = false,
        preflight_reason = 0,
        expected_assignments = 0,
        expected_binaries = 0,
        expected_conditions = 0,
        visited_assignments = 0,
        visited_binaries = 0,
        visited_conditions = 0,
        errors = 0,
        legacy_assignment_visits = 0,
        legacy_binary_visits = 0,
        covered_uncached_type_calls = 0
    };
}

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
    ptr byte spelling_cache;
    usize spelling_cache_capacity;
    ptr byte call_cache;
    ptr byte call_argument_first;
    ptr byte call_argument_last;
    ptr byte argument_next;
    ptr byte type_cache;
    ptr byte resolved_type_ref_cache;
    ptr byte left_expression_cache;
    ptr byte right_expression_cache;
    ptr byte block_parent_cache;
    ptr byte control_parent_cache;
    ptr byte statement_nodes;
    usize statement_count;
    ptr byte block_statement_first;
    ptr byte statement_next;
    ptr byte control_block_first;
    ptr byte block_next;
    ptr byte control_child_first;
    ptr byte control_child_next;
    ptr byte initializer_field_first;
    ptr byte initializer_field_next;
    ptr byte initializer_field_owner;
    ptr byte array_element_first;
    ptr byte array_element_next;
    ptr byte block_nodes;
    usize block_count;
    ptr byte control_nodes;
    usize control_count;
    ptr byte expression_nodes;
    usize expression_count;
    ptr byte call_nodes;
    usize call_count;
    ptr byte expression_start_heads;
    usize expression_start_capacity;
    ptr byte expression_start_next;
    ptr byte expression_next_start;
    ptr byte function_at_position;
    ptr byte name_nodes;
    usize name_count;
    ptr byte type_ref_nodes;
    usize type_ref_count;
    ptr byte declaration_symbol_cache;
    ptr byte top_symbols;
    usize top_symbol_count;
    ptr byte function_bucket_heads;
    usize function_bucket_capacity;
    ptr byte function_bucket_next;
    ptr byte function_parameter_first;
    ptr byte function_parameter_count;
    ptr byte parameter_next;
    ptr byte function_local_range_first;
    ptr byte function_local_range_end;
    ptr byte type_aggregate_symbols;
    ptr byte aggregate_field_first;
    ptr byte field_next;
    ptr byte enum_item_value;
    ptr byte symbol_export_cache;
    ptr byte native_layout_size_cache;
    ptr byte native_layout_alignment_cache;
    ptr byte native_layout_state_cache;
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
    usize profile_statement_candidates;
    usize profile_parent_candidates;
    usize profile_expression_positions;
    usize profile_syntax_candidates;
    usize profile_symbol_candidates;
    bool profile_type_queries_enabled;
    ptr byte profile_type_seen;
    usize profile_type_queries;
    usize profile_type_cache_hits;
    usize profile_type_uncached;
    usize profile_type_distinct_uncached;
    usize profile_type_repeated_uncached;
    usize profile_type_failures;
    usize profile_type_name_uncached;
    usize profile_type_literal_uncached;
    usize profile_type_unary_uncached;
    usize profile_type_binary_uncached;
    usize profile_type_assignment_uncached;
    usize profile_type_call_uncached;
    usize profile_type_other_uncached;
    IrScalarState scalar_state;
    bool suppress_acceptance_diagnostics;
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

usize ir_index_capacity(usize requested) {
    usize capacity = 16;
    while capacity < requested { capacity = capacity * 2; }
    return capacity;
}

usize ir_name_hash(
    text source,
    usize start,
    usize length,
    usize owner
) {
    usize hash = (owner % 16777213) + 1;
    if length == 0 { return hash; }
    usize cursor = 0;
    // Four base-131 steps fit in 64 bits when the prior chunk is reduced.
    // Delaying the modulus preserves the exact existing hash while avoiding
    // three divisions for every complete four-byte name chunk.
    while cursor + 4 <= length {
        hash = hash * 131 + cast(usize, byte_at_or_zero(
            source, start + cursor)) + 1;
        hash = hash * 131 + cast(usize, byte_at_or_zero(
            source, start + cursor + 1)) + 1;
        hash = hash * 131 + cast(usize, byte_at_or_zero(
            source, start + cursor + 2)) + 1;
        hash = hash * 131 + cast(usize, byte_at_or_zero(
            source, start + cursor + 3)) + 1;
        hash = hash % 16777213;
        cursor = cursor + 4;
    }
    while cursor < length {
        hash = hash * 131 + cast(usize, byte_at_or_zero(
            source, start + cursor)) + 1;
        cursor = cursor + 1;
    }
    return hash % 16777213;
}

unsafe void ir_initialize_symbol_indexes(
    ref IrContext context,
    ptr byte parameter_last
) {
    if context.function_bucket_heads == null ||
        context.function_bucket_next == null ||
        context.function_parameter_first == null ||
        context.function_parameter_count == null ||
        context.parameter_next == null ||
        context.function_local_range_first == null ||
        context.function_local_range_end == null ||
        context.type_aggregate_symbols == null ||
        context.aggregate_field_first == null ||
        context.field_next == null || parameter_last == null {
        return;
    }
    usize index = 0;
    while index < context.function_bucket_capacity {
        write_usize(
            context.function_bucket_heads, index * size_of(usize), 0
        );
        index = index + 1;
    }
    index = 0;
    while index <= context.symbols.length {
        write_usize(
            context.function_bucket_next, index * size_of(usize), 0
        );
        write_usize(
            context.function_parameter_first, index * size_of(usize), 0
        );
        write_usize(
            context.function_parameter_count, index * size_of(usize), 0
        );
        write_usize(
            context.parameter_next, index * size_of(usize), 0
        );
        write_usize(
            context.function_local_range_first,
            index * size_of(usize), context.symbols.length
        );
        write_usize(
            context.function_local_range_end,
            index * size_of(usize), context.symbols.length
        );
        write_usize(
            context.aggregate_field_first,
            index * size_of(usize), 0
        );
        write_usize(
            context.field_next, index * size_of(usize), 0
        );
        if context.enum_item_value != null {
            write_usize(
                context.enum_item_value, index * size_of(usize), 0
            );
        }
        write_usize(parameter_last, index * size_of(usize), 0);
        index = index + 1;
    }
    index = 0;
    while index <= context.types.length {
        write_usize(
            context.type_aggregate_symbols,
            index * size_of(usize), 0
        );
        index = index + 1;
    }

    usize loaded_source_record = context.symbols.length + 1;
    text symbol_source = "";
    usize symbol = 0;
    while symbol < context.symbols.length {
        usize kind = read_record_field(context.symbol_data, symbol, 0);
        usize source_record = read_record_field(
            context.symbol_data, symbol, 1
        );
        if source_record != loaded_source_record {
            text loaded_symbol_source;
            status loaded = project_read_source_record(
                context.project_source, context.project_root,
                context.source_data, source_record,
                out loaded_symbol_source
            );
            if loaded.ok {
                symbol_source = loaded_symbol_source;
                loaded_source_record = source_record;
            }
        }
        if source_record == loaded_source_record {
            usize owner = read_record_field(
                context.detail_data, symbol, 2
            );
            usize namespace = read_record_field(
                context.detail_data, symbol, 0
            );
            if owner != 0 {
                namespace = context.modules.length + owner;
            }
            usize hash = ir_name_hash(
                symbol_source,
                read_record_field(context.symbol_data, symbol, 2),
                read_record_field(context.symbol_data, symbol, 3),
                namespace
            );
            usize bucket = hash % context.function_bucket_capacity;
            usize previous = read_usize(
                context.function_bucket_heads,
                bucket * size_of(usize)
            );
            write_usize(
                context.function_bucket_next,
                symbol * size_of(usize), previous
            );
            write_usize(
                context.function_bucket_heads,
                bucket * size_of(usize), symbol + 1
            );
        }
        if kind == resolution_symbol_struct() ||
            kind == resolution_symbol_resource() ||
            kind == resolution_symbol_enum() {
            usize type_id = read_record_field(
                context.symbol_data, symbol, 4
            );
            if type_id < context.types.length && read_usize(
                context.type_aggregate_symbols,
                type_id * size_of(usize)
            ) == 0 {
                write_usize(
                    context.type_aggregate_symbols,
                    type_id * size_of(usize), symbol + 1
                );
            }
        }
        if kind == resolution_symbol_parameter() ||
            kind == resolution_symbol_variable() {
            usize local_owner = read_record_field(
                context.detail_data, symbol, 2
            );
            if local_owner != 0 &&
                local_owner - 1 < context.symbols.length {
                usize local_function = local_owner - 1;
                if read_usize(
                    context.function_local_range_first,
                    local_function * size_of(usize)
                ) == context.symbols.length {
                    write_usize(
                        context.function_local_range_first,
                        local_function * size_of(usize), symbol
                    );
                }
                write_usize(
                    context.function_local_range_end,
                    local_function * size_of(usize), symbol + 1
                );
            }
        }
        if kind == resolution_symbol_parameter() {
            usize owner = read_record_field(
                context.detail_data, symbol, 2
            );
            if owner != 0 && owner - 1 < context.symbols.length {
                usize function_symbol = owner - 1;
                usize last = read_usize(
                    parameter_last,
                    function_symbol * size_of(usize)
                );
                if last == 0 {
                    write_usize(
                        context.function_parameter_first,
                        function_symbol * size_of(usize), symbol + 1
                    );
                } else {
                    write_usize(
                        context.parameter_next,
                        (last - 1) * size_of(usize), symbol + 1
                    );
                }
                write_usize(
                    parameter_last,
                    function_symbol * size_of(usize), symbol + 1
                );
                usize count = read_usize(
                    context.function_parameter_count,
                    function_symbol * size_of(usize)
                );
                write_usize(
                    context.function_parameter_count,
                    function_symbol * size_of(usize), count + 1
                );
            }
        }
        symbol = symbol + 1;
    }
    index = 0;
    while index <= context.symbols.length {
        write_usize(parameter_last, index * size_of(usize), 0);
        index = index + 1;
    }
    symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_field() {
            usize owner = read_record_field(
                context.detail_data, symbol, 2
            );
            if owner != 0 && owner - 1 < context.symbols.length {
                usize aggregate_symbol = owner - 1;
                usize last = read_usize(
                    parameter_last,
                    aggregate_symbol * size_of(usize)
                );
                if last == 0 {
                    write_usize(
                        context.aggregate_field_first,
                        aggregate_symbol * size_of(usize), symbol + 1
                    );
                } else {
                    write_usize(
                        context.field_next,
                        (last - 1) * size_of(usize), symbol + 1
                    );
                }
                write_usize(
                    parameter_last,
                    aggregate_symbol * size_of(usize), symbol + 1
                );
            }
        }
        symbol = symbol + 1;
    }
    if context.enum_item_value != null {
        index = 0;
        while index <= context.symbols.length {
            write_usize(parameter_last, index * size_of(usize), 0);
            index = index + 1;
        }
        symbol = 0;
        while symbol < context.symbols.length {
            if read_record_field(context.symbol_data, symbol, 0) ==
                    resolution_symbol_enum_item() {
                usize owner = read_record_field(
                    context.detail_data, symbol, 2
                );
                if owner != 0 && owner - 1 < context.symbols.length {
                    usize count = read_usize(
                        parameter_last,
                        (owner - 1) * size_of(usize)
                    );
                    write_usize(
                        context.enum_item_value,
                        symbol * size_of(usize), count + 1
                    );
                    write_usize(
                        parameter_last,
                        (owner - 1) * size_of(usize), count + 1
                    );
                }
            }
            symbol = symbol + 1;
        }
    }
}
