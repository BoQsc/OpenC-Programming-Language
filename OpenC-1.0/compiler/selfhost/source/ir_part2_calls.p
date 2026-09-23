import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize ir_indexed_call_selection(
    ref IrContext context,
    usize call,
    usize first
) {
    if context.function_bucket_heads == null ||
        context.function_bucket_next == null ||
        context.function_bucket_capacity == 0 ||
        first >= context.symbols.length || read_record_field(
            context.symbol_data, first, 0
        ) != resolution_symbol_function() {
        return flow_call_selection(
            context.project_source, context.project_root,
            context.module_data, context.modules, context.source_data,
            context.type_data, context.symbol_data,
            context.detail_data, context.symbols,
            context.token_data, context.tokens,
            context.syntax_data, context.syntax,
            context.module_index, context.source_record,
            call, context.source
        );
    }

    usize argument_count = read_record_field(
        context.syntax_data, call, 4
    );
    usize callee = read_record_field(context.syntax_data, call, 3);
    usize callee_start = read_record_field(
        context.syntax_data, callee, 1
    );
    usize callee_length = read_record_field(
        context.syntax_data, callee, 2
    );
    usize scan = 0;
    while scan < callee_length {
        if byte_at_or_zero(context.source, callee_start + scan) == 46 {
            callee_start = callee_start + scan + 1;
            callee_length = callee_length - scan - 1;
            scan = 0;
        } else { scan = scan + 1; }
    }
    usize target_module = read_record_field(
        context.detail_data, first, 0
    );
    usize hash = ir_name_hash(
        context.source, callee_start, callee_length, target_module
    );
    usize encoded = read_usize(
        context.function_bucket_heads,
        (hash % context.function_bucket_capacity) * size_of(usize)
    );
    usize matching = 0;
    usize unique = context.symbols.length;
    usize match_encoded = encoded;
    while match_encoded != 0 {
        usize match_candidate = match_encoded - 1;
        if read_record_field(
                context.symbol_data, match_candidate, 0
            ) == resolution_symbol_function() && read_record_field(
                context.detail_data, match_candidate, 0
            ) == target_module && resolution_symbol_name_equals(
                context.project_source, context.project_root,
                context.source_data, context.symbol_data,
                match_candidate, context.source,
                callee_start, callee_length
            ) {
            matching = matching + 1;
            unique = match_candidate;
        }
        match_encoded = read_usize(
            context.function_bucket_next,
            match_candidate * size_of(usize)
        );
    }
    // With one declaration there is no overload decision to make. Arity,
    // argument compatibility, and export visibility are checked by the
    // acceptance pass against this same declaration.
    if matching == 1 { return unique; }
    usize selected = context.symbols.length;
    usize best_conversions = cast(usize, 4294967295);
    bool ambiguous = false;
    while encoded != 0 {
        usize candidate = encoded - 1;
        if read_record_field(context.symbol_data, candidate, 0) ==
                resolution_symbol_function() && read_record_field(
                context.detail_data, candidate, 0
            ) == target_module && resolution_symbol_name_equals(
                context.project_source, context.project_root,
                context.source_data, context.symbol_data,
                candidate, context.source, callee_start, callee_length
            ) && ir_parameter_count(
                context, candidate
            ) == argument_count {
            bool valid = true;
            usize conversions = 0;
            usize argument = 0;
            while argument < argument_count {
                usize parameter = ir_parameter_at(
                    context, candidate, argument
                );
                if parameter >= context.symbols.length {
                    valid = false;
                    break;
                }
                usize argument_node = ir_call_argument_node(
                    context, call, argument
                );
                usize argument_type = semantic_type_error();
                if argument_node < context.syntax.length {
                    argument_type = ir_node_type(
                        context, argument_node, semantic_type_error()
                    );
                }
                usize parameter_type = read_record_field(
                    context.symbol_data, parameter, 4
                );
                if argument_type != parameter_type {
                    if resolution_lossless(
                        context.type_data, argument_type, parameter_type
                    ) { conversions = conversions + 1; }
                    else { valid = false; }
                }
                argument = argument + 1;
            }
            if valid {
                if selected == context.symbols.length ||
                    conversions < best_conversions {
                    selected = candidate;
                    best_conversions = conversions;
                    ambiguous = false;
                } else if conversions == best_conversions {
                    ambiguous = true;
                }
            }
        }
        encoded = read_usize(
            context.function_bucket_next,
            candidate * size_of(usize)
        );
    }
    if ambiguous { return context.symbols.length; }
    return selected;
}

unsafe usize ir_select_call(ref IrContext context, usize call) {
    ir_select_node_function(context, call);
    if (context.call_cache != null ||
        context.typed_expression_cache != null) &&
        call < context.syntax.length {
        usize cached = 0;
        if context.typed_expression_cache != null {
            cached = ir_typed_expression_read(context, call, 1);
        } else {
            cached = read_usize(
                context.call_cache, call * size_of(usize)
            );
        }
        if cached != 0 { return cached - 1; }
    }
    usize selected = context.symbols.length;
    ir_index_call_arguments(context, call);
    usize callee = context.syntax.length;
    if call < context.syntax.length {
        callee = read_record_field(context.syntax_data, call, 3);
    }
    if callee < context.syntax.length {
        usize callee_start = read_record_field(
            context.syntax_data, callee, 1
        );
        usize callee_length = read_record_field(
            context.syntax_data, callee, 2
        );
        bool builtin_spelling = ir_builtin_call(
            context.source, callee_start, callee_length
        ) || ir_intrinsic_call(
            context.source, callee_start, callee_length
        );
        usize declared = context.symbols.length;
        if builtin_spelling { declared = ir_resolve_name(context, callee); }
        // Imported/user modules may deliberately use short aliases such as
        // `file`, `memory`, or `process`. A declared function has precedence;
        // Hosted built-in routing is only the fallback for an unresolved name.
        if builtin_spelling && declared >= context.symbols.length {
            if context.typed_expression_cache != null &&
                call < context.syntax.length {
                ir_typed_expression_write(
                    context, call, 1, selected + 1
                );
            } else if context.call_cache != null &&
                call < context.syntax.length {
                write_usize(context.call_cache,
                    call * size_of(usize), selected + 1);
            }
            return selected;
        }
    }
    if context.function_bucket_heads == null ||
        context.function_bucket_next == null ||
        context.function_bucket_capacity == 0 {
        selected = flow_call_selection(
            context.project_source, context.project_root,
            context.module_data, context.modules, context.source_data,
            context.type_data, context.symbol_data,
            context.detail_data, context.symbols,
            context.token_data, context.tokens,
            context.syntax_data, context.syntax,
            context.module_index, context.source_record,
            call, context.source
        );
    } else {
        usize first = context.symbols.length;
        if callee < context.syntax.length {
            first = ir_resolve_name(context, callee);
        }
        selected = ir_indexed_call_selection(context, call, first);
    }
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
    // A failed overload/name selection can be transient while the fused pass
    // changes source/function context and completes argument indexing. Keep
    // only real symbol selections; otherwise a precheck miss becomes a false
    // permanent error during acceptance and lowering.
    if (context.call_cache != null ||
        context.typed_expression_cache != null) &&
        call < context.syntax.length &&
        selected < context.symbols.length {
        if context.typed_expression_cache != null {
            ir_typed_expression_write(
                context, call, 1, selected + 1
            );
        } else {
            write_usize(
                context.call_cache, call * size_of(usize), selected + 1
            );
        }
    }
    return selected;
}
