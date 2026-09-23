import system.file;
import system.io;
import system.memory;
import system.process;
import system.text;

struct AcceptanceExpressionFeatures {
    bool has_assignments;
    bool has_binary;
    bool has_index_ranges;
    bool has_casts;
    bool has_aggregates;
}

unsafe AcceptanceExpressionFeatures acceptance_expression_features(
    ref IrContext context
) {
    AcceptanceExpressionFeatures features = AcceptanceExpressionFeatures{
        has_assignments = false,
        has_binary = false,
        has_index_ranges = false,
        has_casts = false,
        has_aggregates = false
    };
    usize node_index = 0;
    usize node_count = context.syntax.length;
    if context.expression_nodes != null {
        node_count = context.expression_count;
    }
    while node_index < node_count {
        usize node = node_index;
        if context.expression_nodes != null {
            node = read_usize(
                context.expression_nodes,
                node_index * size_of(usize)
            );
        }
        usize kind = read_record_field(context.syntax_data, node, 0);
        if kind == 37 {
            features.has_assignments = true;
        } else if kind == 36 {
            features.has_binary = true;
        } else if kind == 40 || kind == 41 {
            features.has_index_ranges = true;
        } else if kind == 42 || kind == 43 || kind == 46 {
            features.has_casts = true;
        } else if kind == 48 {
            features.has_aggregates = true;
        }
        node_index = node_index + 1;
    }
    return features;
}

unsafe usize acceptance_validate_context(
    ref IrContext context,
    ref BuildTimings timings
) {
    usize group_started = process.monotonic_milliseconds();
    acceptance_mask_external_declarations(context);
    timings.validation_acceptance_mask_ms =
        timings.validation_acceptance_mask_ms +
        process.monotonic_milliseconds() - group_started;
    usize errors = 0;
    group_started = process.monotonic_milliseconds();
    usize found = acceptance_validate_type_refs(context);
    acceptance_report_source_count(context, "type_refs", found);
    errors = errors + found;
    found = acceptance_validate_fields(context);
    acceptance_report_source_count(context, "fields", found);
    errors = errors + found;
    found = acceptance_validate_locals(context);
    acceptance_report_source_count(context, "locals", found);
    errors = errors + found;
    timings.validation_acceptance_types_ms =
        timings.validation_acceptance_types_ms +
        process.monotonic_milliseconds() - group_started;
    group_started = process.monotonic_milliseconds();
    AcceptanceExpressionFeatures expression_features =
        acceptance_expression_features(context);
    usize assignment_queries_before = context.profile_type_queries;
    usize assignment_hits_before = context.profile_type_cache_hits;
    usize assignment_uncached_before = context.profile_type_uncached;
    usize assignments_started = process.monotonic_milliseconds();
    found = 0;
    if expression_features.has_assignments {
        found = acceptance_validate_assignments(context);
    }
    timings.validation_acceptance_assignments_ms =
        timings.validation_acceptance_assignments_ms +
        process.monotonic_milliseconds() - assignments_started;
    timings.validation_assignment_type_queries =
        timings.validation_assignment_type_queries +
        context.profile_type_queries - assignment_queries_before;
    timings.validation_assignment_type_cache_hits =
        timings.validation_assignment_type_cache_hits +
        context.profile_type_cache_hits - assignment_hits_before;
    timings.validation_assignment_type_uncached =
        timings.validation_assignment_type_uncached +
        context.profile_type_uncached - assignment_uncached_before;
    acceptance_report_source_count(context, "assignments", found);
    errors = errors + found;
    found = 0;
    if expression_features.has_binary {
        found = acceptance_validate_binary(context);
    }
    acceptance_report_source_count(context, "binary", found);
    errors = errors + found;
    found = acceptance_validate_conditions(context);
    acceptance_report_source_count(context, "conditions", found);
    errors = errors + found;
    found = 0;
    if expression_features.has_index_ranges {
        found = acceptance_validate_index_ranges(context);
    }
    acceptance_report_source_count(context, "index_ranges", found);
    errors = errors + found;
    found = 0;
    if expression_features.has_casts {
        found = acceptance_validate_casts(context);
    }
    acceptance_report_source_count(context, "casts", found);
    errors = errors + found;
    found = 0;
    if expression_features.has_aggregates {
        found = acceptance_validate_aggregates(context);
    }
    acceptance_report_source_count(context, "aggregates", found);
    errors = errors + found;
    timings.validation_acceptance_expressions_ms =
        timings.validation_acceptance_expressions_ms +
        process.monotonic_milliseconds() - group_started;
    group_started = process.monotonic_milliseconds();
    found = acceptance_validate_functions(context);
    acceptance_report_source_count(context, "functions", found);
    errors = errors + found;
    found = acceptance_validate_scopes(context);
    acceptance_report_source_count(context, "scopes", found);
    errors = errors + found;
    found = 0;
    if acceptance_source_has_enum(context) {
        found = acceptance_validate_enums(context);
    }
    acceptance_report_source_count(context, "enums", found);
    errors = errors + found;
    timings.validation_acceptance_functions_ms =
        timings.validation_acceptance_functions_ms +
        process.monotonic_milliseconds() - group_started;
    group_started = process.monotonic_milliseconds();
    usize call_rule_started = process.monotonic_milliseconds();
    found = acceptance_validate_overload_calls(context);
    acceptance_report_source_count(context, "overload_calls", found);
    errors = errors + found;
    timings.validation_acceptance_overload_calls_ms =
        timings.validation_acceptance_overload_calls_ms +
        process.monotonic_milliseconds() - call_rule_started;
    call_rule_started = process.monotonic_milliseconds();
    found = acceptance_validate_slice_aliases(context);
    acceptance_report_source_count(context, "slice_aliases", found);
    errors = errors + found;
    timings.validation_acceptance_slice_aliases_ms =
        timings.validation_acceptance_slice_aliases_ms +
        process.monotonic_milliseconds() - call_rule_started;
    call_rule_started = process.monotonic_milliseconds();
    found = acceptance_validate_calls(context);
    acceptance_report_source_count(context, "calls", found);
    errors = errors + found;
    timings.validation_acceptance_call_rules_ms =
        timings.validation_acceptance_call_rules_ms +
        process.monotonic_milliseconds() - call_rule_started;
    timings.validation_acceptance_calls_ms =
        timings.validation_acceptance_calls_ms +
        process.monotonic_milliseconds() - group_started;
    group_started = process.monotonic_milliseconds();
    found = acceptance_validate_storage(context);
    acceptance_report_source_count(context, "storage", found);
    errors = errors + found;
    found = acceptance_validate_import_aliases(context);
    acceptance_report_source_count(context, "import_aliases", found);
    errors = errors + found;
    found = acceptance_validate_optional_proofs(context);
    acceptance_report_source_count(context, "optional_proofs", found);
    errors = errors + found;
    timings.validation_acceptance_resources_ms =
        timings.validation_acceptance_resources_ms +
        process.monotonic_milliseconds() - group_started;
    group_started = process.monotonic_milliseconds();
    found = acceptance_validate_pointer_ownership(context);
    acceptance_report_source_count(context, "pointer_ownership", found);
    errors = errors + found;
    found = acceptance_validate_pointer_order(context);
    acceptance_report_source_count(context, "pointer_order", found);
    errors = errors + found;
    timings.validation_acceptance_pointers_ms =
        timings.validation_acceptance_pointers_ms +
        process.monotonic_milliseconds() - group_started;
    timings.validation_statement_candidates =
        timings.validation_statement_candidates +
        context.profile_statement_candidates;
    timings.validation_parent_candidates =
        timings.validation_parent_candidates +
        context.profile_parent_candidates;
    timings.validation_expression_positions =
        timings.validation_expression_positions +
        context.profile_expression_positions;
    timings.validation_syntax_candidates =
        timings.validation_syntax_candidates +
        context.profile_syntax_candidates;
    timings.validation_symbol_candidates =
        timings.validation_symbol_candidates +
        context.profile_symbol_candidates;
    return errors;
}
