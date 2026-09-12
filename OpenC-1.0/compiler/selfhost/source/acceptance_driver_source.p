import system.file;
import system.io;
import system.memory;
import system.process;
import system.text;

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
    acceptance_report_count("type_refs", context.source_record, found);
    errors = errors + found;
    found = acceptance_validate_fields(context);
    acceptance_report_count("fields", context.source_record, found);
    errors = errors + found;
    found = acceptance_validate_locals(context);
    acceptance_report_count("locals", context.source_record, found);
    errors = errors + found;
    timings.validation_acceptance_types_ms =
        timings.validation_acceptance_types_ms +
        process.monotonic_milliseconds() - group_started;
    group_started = process.monotonic_milliseconds();
    found = acceptance_validate_assignments(context);
    acceptance_report_count("assignments", context.source_record, found);
    errors = errors + found;
    found = acceptance_validate_binary(context);
    acceptance_report_count("binary", context.source_record, found);
    errors = errors + found;
    found = acceptance_validate_conditions(context);
    acceptance_report_count("conditions", context.source_record, found);
    errors = errors + found;
    found = acceptance_validate_index_ranges(context);
    acceptance_report_count("index_ranges", context.source_record, found);
    errors = errors + found;
    found = acceptance_validate_casts(context);
    acceptance_report_count("casts", context.source_record, found);
    errors = errors + found;
    found = acceptance_validate_aggregates(context);
    acceptance_report_count("aggregates", context.source_record, found);
    errors = errors + found;
    timings.validation_acceptance_expressions_ms =
        timings.validation_acceptance_expressions_ms +
        process.monotonic_milliseconds() - group_started;
    group_started = process.monotonic_milliseconds();
    found = acceptance_validate_functions(context);
    acceptance_report_count("functions", context.source_record, found);
    errors = errors + found;
    found = acceptance_validate_scopes(context);
    acceptance_report_count("scopes", context.source_record, found);
    errors = errors + found;
    found = acceptance_validate_enums(context);
    acceptance_report_count("enums", context.source_record, found);
    errors = errors + found;
    timings.validation_acceptance_functions_ms =
        timings.validation_acceptance_functions_ms +
        process.monotonic_milliseconds() - group_started;
    group_started = process.monotonic_milliseconds();
    usize call_rule_started = process.monotonic_milliseconds();
    found = acceptance_validate_overload_calls(context);
    acceptance_report_count("overload_calls", context.source_record, found);
    errors = errors + found;
    timings.validation_acceptance_overload_calls_ms =
        timings.validation_acceptance_overload_calls_ms +
        process.monotonic_milliseconds() - call_rule_started;
    call_rule_started = process.monotonic_milliseconds();
    found = acceptance_validate_slice_aliases(context);
    acceptance_report_count("slice_aliases", context.source_record, found);
    errors = errors + found;
    timings.validation_acceptance_slice_aliases_ms =
        timings.validation_acceptance_slice_aliases_ms +
        process.monotonic_milliseconds() - call_rule_started;
    call_rule_started = process.monotonic_milliseconds();
    found = acceptance_validate_calls(context);
    acceptance_report_count("calls", context.source_record, found);
    errors = errors + found;
    timings.validation_acceptance_call_rules_ms =
        timings.validation_acceptance_call_rules_ms +
        process.monotonic_milliseconds() - call_rule_started;
    timings.validation_acceptance_calls_ms =
        timings.validation_acceptance_calls_ms +
        process.monotonic_milliseconds() - group_started;
    group_started = process.monotonic_milliseconds();
    found = acceptance_validate_storage(context);
    acceptance_report_count("storage", context.source_record, found);
    errors = errors + found;
    found = acceptance_validate_import_aliases(context);
    acceptance_report_count("import_aliases", context.source_record, found);
    errors = errors + found;
    found = acceptance_validate_optional_proofs(context);
    acceptance_report_count("optional_proofs", context.source_record, found);
    errors = errors + found;
    timings.validation_acceptance_resources_ms =
        timings.validation_acceptance_resources_ms +
        process.monotonic_milliseconds() - group_started;
    group_started = process.monotonic_milliseconds();
    found = acceptance_validate_pointer_ownership(context);
    acceptance_report_count("pointer_ownership", context.source_record, found);
    errors = errors + found;
    found = acceptance_validate_pointer_order(context);
    acceptance_report_count("pointer_order", context.source_record, found);
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
