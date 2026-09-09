import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

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
    usize index = 0;
    usize candidate_count = context.syntax.length;
    if context.type_ref_nodes != null {
        candidate_count = context.type_ref_count;
    }
    context.profile_syntax_candidates =
        context.profile_syntax_candidates + candidate_count;
    while index < candidate_count {
        usize record = index;
        if context.type_ref_nodes != null {
            record = read_usize(
                context.type_ref_nodes, index * size_of(usize)
            );
        }
        if read_record_field(context.syntax_data, record, 0) == 26 &&
            semantic_node_contains(context.syntax_data, node, record) {
            usize start = read_record_field(context.syntax_data, record, 1);
            if start < selected_start {
                selected = record;
                selected_start = start;
            }
        }
        index = index + 1;
    }
    return selected;
}

unsafe usize ir_resolve_type_node(ref IrContext context, usize type_node) {
    if type_node >= context.syntax.length { return semantic_type_error(); }
    if context.resolved_type_ref_cache != null {
        usize cached = read_usize(
            context.resolved_type_ref_cache,
            type_node * size_of(usize)
        );
        if cached != 0 { return cached - 1; }
    }
    usize resolved = semantic_resolve_type(
        context.project_source, context.project_root,
        context.module_data, context.modules, context.source_data,
        context.source_record, context.source,
        context.token_data, context.tokens,
        context.type_data, context.types,
        read_record_field(context.syntax_data, type_node, 1),
        read_record_field(context.syntax_data, type_node, 2)
    );
    if context.resolved_type_ref_cache != null {
        write_usize(
            context.resolved_type_ref_cache,
            type_node * size_of(usize), resolved + 1
        );
    }
    return resolved;
}

unsafe usize ir_expression_child_after(
    ref IrContext context,
    usize parent,
    usize after,
    bool largest
) {
    if context.expression_start_heads != null &&
        context.expression_start_next != null &&
        context.expression_start_capacity != 0 {
        usize selected = context.syntax.length;
        usize measure = 0;
        usize parent_end = read_record_field(
            context.syntax_data, parent, 1
        ) + read_record_field(context.syntax_data, parent, 2);
        if parent_end > after && context.expression_next_start == null {
            context.profile_expression_positions =
                context.profile_expression_positions + parent_end - after;
        }
        usize cursor = after;
        while cursor < parent_end &&
            cursor < context.expression_start_capacity {
            if context.expression_next_start != null {
                usize next_encoded = read_usize(
                    context.expression_next_start,
                    cursor * size_of(usize)
                );
                if next_encoded == 0 { break; }
                cursor = next_encoded - 1;
                if cursor >= parent_end { break; }
                context.profile_expression_positions =
                    context.profile_expression_positions + 1;
            }
            usize encoded = read_usize(
                context.expression_start_heads,
                cursor * size_of(usize)
            );
            while encoded != 0 {
                usize record = encoded - 1;
                if record != parent && semantic_node_contains(
                    context.syntax_data, parent, record
                ) {
                    usize length = read_record_field(
                        context.syntax_data, record, 2
                    );
                    if largest {
                        if selected == context.syntax.length ||
                            length > measure || (length == measure &&
                            record < selected) {
                            selected = record;
                            measure = length;
                        }
                    } else if selected == context.syntax.length ||
                        record < selected {
                        selected = record;
                    }
                }
                encoded = read_usize(
                    context.expression_start_next,
                    record * size_of(usize)
                );
            }
            if !largest && selected < context.syntax.length {
                return selected;
            }
            cursor = cursor + 1;
        }
        return selected;
    }
    usize fallback_selected = context.syntax.length;
    usize fallback_measure = 0;
    usize fallback_selected_start = cast(usize, 4294967295);
    usize fallback_record = 0;
    while fallback_record < context.syntax.length {
        usize kind = read_record_field(context.syntax_data, fallback_record, 0);
        usize start = read_record_field(context.syntax_data, fallback_record, 1);
        if resolution_expression_kind(kind) && fallback_record != parent &&
            start >= after && semantic_node_contains(
                context.syntax_data, parent, fallback_record
            ) {
            usize length = read_record_field(
                context.syntax_data, fallback_record, 2
            );
            if largest {
                if fallback_selected == context.syntax.length ||
                    length > fallback_measure {
                    fallback_selected = fallback_record;
                    fallback_measure = length;
                }
            } else if start < fallback_selected_start {
                fallback_selected = fallback_record;
                fallback_selected_start = start;
            }
        }
        fallback_record = fallback_record + 1;
    }
    return fallback_selected;
}

unsafe usize ir_enum_value(ref IrContext context, usize symbol) {
    if context.enum_item_value != null && symbol < context.symbols.length {
        usize encoded = read_usize(
            context.enum_item_value, symbol * size_of(usize)
        );
        if encoded != 0 { return encoded - 1; }
    }
    usize owner = read_record_field(context.detail_data, symbol, 2);
    if owner == 0 { return 0; }
    usize requested_node = read_record_field(context.detail_data, symbol, 1);
    usize value = 0;
    usize candidate = 0;
    context.profile_symbol_candidates =
        context.profile_symbol_candidates + context.symbols.length;
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
    bool has_cache = context.type_cache != null &&
        node < context.syntax.length;
    bool cacheable = expected == semantic_type_error() && has_cache;
    if has_cache {
        usize cached = read_usize(
            context.type_cache, node * size_of(usize)
        );
        if cached != 0 {
            usize cached_type = cached - 1;
            if cacheable { return cached_type; }
            usize kind = read_record_field(
                context.syntax_data, node, 0
            );
            bool expectation_independent = kind == 27 || kind == 31 ||
                kind == 32 || kind == 38 || kind == 42 || kind == 43 ||
                kind == 44 || kind == 45 || kind == 46 || kind == 47;
            if expectation_independent ||
                ((kind == 39 || kind == 40 || kind == 41) &&
                 cached_type != semantic_type_error()) {
                return cached_type;
            }
        }
    }
    usize resolved = ir_node_type_uncached(context, node, expected);
    if cacheable {
        write_usize(
            context.type_cache,
            node * size_of(usize),
            resolved + 1
        );
    }
    return resolved;
}

unsafe usize ir_node_type_uncached(
    ref IrContext context,
    usize node,
    usize expected
) {
    if node >= context.syntax.length { return semantic_type_error(); }
    ir_select_node_function(context, node);
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
        ResolutionInteger literal = resolution_parse_integer(
            context.source,
            read_record_field(context.syntax_data, node, 1),
            read_record_field(context.syntax_data, node, 2)
        );
        if literal.valid && literal.value > cast(i64, 2147483647) {
            return semantic_builtin_type("i64", 0, 3);
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
        usize child = ir_right_expression(
            context, node,
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
        usize left = ir_left_expression(
            context, node,
            read_record_field(context.syntax_data, node, 3)
        );
        usize right = ir_right_expression(
            context, node,
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
        ResolutionInteger left_integer = acceptance_integer_value(
            context, left
        );
        ResolutionInteger right_integer = acceptance_integer_value(
            context, right
        );
        if left_integer.valid && !right_integer.valid {
            return ir_node_type(context, right, expected);
        }
        return ir_node_type(context, left, expected);
    }
    if kind == 37 {
        usize left = ir_left_expression(
            context, node,
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
                ) || span_equals_ascii(
                    context.source, callee_start, callee_length,
                    "text.copy_utf8_unchecked"
                ) || span_equals_ascii(
                    context.source, callee_start, callee_length,
                    "system.text.copy_utf8_unchecked"
                ) || span_equals_ascii(
                    context.source, callee_start, callee_length,
                    "text.copy_utf8_slice_unchecked"
                ) || span_equals_ascii(
                    context.source, callee_start, callee_length,
                    "system.text.copy_utf8_slice_unchecked"
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
                context.source, callee_start, callee_length,
                "memory.load_usize"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.memory.load_usize"
            ) { return semantic_builtin_type("usize", 0, 5); }
            if span_equals_ascii(
                context.source, callee_start, callee_length,
                "memory.store_usize"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.memory.store_usize"
            ) { return semantic_type_void(); }
            if span_equals_ascii(
                context.source, callee_start, callee_length,
                "text.length"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.text.length"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "text.byte_length"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.text.byte_length"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "process.argument_count"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.process.argument_count"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "process.monotonic_milliseconds"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.process.monotonic_milliseconds"
            ) { return semantic_builtin_type("usize", 0, 5); }
            if span_equals_ascii(
                context.source, callee_start, callee_length,
                "text.scalar_at"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.text.scalar_at"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "text.byte_at"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.text.byte_at"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "text.slice"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.text.slice"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "process.run"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.process.run"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "file.read_text"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.file.read_text"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "file.read_text_cached"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.file.read_text_cached"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "file.write_text"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.file.write_text"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "file.write_bytes"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.file.write_bytes"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "file.read_bytes"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.file.read_bytes"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "file.read_bytes_raw"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.file.read_bytes_raw"
            ) { return semantic_type_status(); }
            if span_equals_ascii(
                context.source, callee_start, callee_length,
                "text.byte_at_unchecked"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.text.byte_at_unchecked"
            ) { return semantic_builtin_type("u8", 0, 2); }
            if span_equals_ascii(
                context.source, callee_start, callee_length, "text.trim"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.text.trim"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length, "text.from_utf8"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.text.from_utf8"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "text.concat"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.text.concat"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "process.argument"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.process.argument"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "process.current_directory"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.process.current_directory"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "process.executable_directory"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.process.executable_directory"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "path.join"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.path.join"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "path.normalize"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.path.normalize"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "path.directory"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.path.directory"
            ) { return semantic_type_text(); }
            if span_equals_ascii(
                context.source, callee_start, callee_length,
                "text.equal"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.text.equal"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "path.absolute"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.path.absolute"
            ) { return semantic_type_bool(); }
            if span_equals_ascii(
                context.source, callee_start, callee_length,
                "text.compare"
            ) || span_equals_ascii(
                context.source, callee_start, callee_length,
                "system.text.compare"
            ) { return semantic_builtin_type("i32", 0, 3); }
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
        usize storage_name = ir_first_name(context, node);
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
        usize name = ir_first_name(context, node);
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
            usize aggregate_symbol = ir_aggregate_for_type(
                context, base_type
            );
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
