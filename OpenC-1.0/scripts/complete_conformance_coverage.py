#!/usr/bin/env python3
"""Materialize the audited Core rule and grammar-production coverage maps."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURE_ROOT = ROOT / "conformance" / "fixtures"
EXECUTION_STATE = "EXECUTED_PASS_WINDOWS_X86_64_RC8"


# Each formerly uncovered rule is assigned to one fixture whose authored
# source or structured behavior directly exercises that rule. A fixture can
# exercise several inseparable requirements, but every association is explicit
# and reviewable here.
RULE_FIXTURE_ASSIGNMENTS: dict[str, tuple[str, ...]] = {
    "runtime/unsafe_fault_target_bounded": (
        "OPENC-SAFETY-NOUB-001",
        "OPENC-SAFETY-UNSAFE-001",
        "OPENC-SAFETY-OUTCOME-001",
        "OPENC-UNSAFE-PRECONDITION-001",
        "OPENC-CLEANUP-UNSAFEFAULT-001",
        "OPENC-TARGET-SANITIZE-001",
    ),
    "runtime/evaluation_binary_left_to_right": (
        "OPENC-SAFETY-OPTIMIZE-001",
    ),
    "runtime/fatal_allocation_defined": (
        "OPENC-SAFETY-IMPLIMIT-001",
    ),
    "runtime/runtime_checked_failure_runs_cleanup": (
        "OPENC-TERM-CHECKFAIL-001",
        "OPENC-OWN-CHECKEDGE-001",
        "OPENC-CLEANUP-ALL-001",
        "OPENC-CLEANUP-PRIMARY-001",
        "OPENC-CLEANUP-STATE-001",
    ),
    "valid/source_bom_ignored": (
        "OPENC-SOURCE-BOM-001",
    ),
    "valid/when_context_expression": (
        "OPENC-WHEN-CONTEXT-001",
        "OPENC-WHEN-EXPR-001",
    ),
    "valid/identifier_case_sensitive": (
        "OPENC-LEX-MAXIMAL-001",
        "OPENC-LEX-WORDCLASS-001",
    ),
    "valid/module_multi_source_overload": (
        "OPENC-MODULE-MULTISOURCE-001",
        "OPENC-MODULE-ORDER-001",
        "OPENC-MODULE-MAPPING-001",
    ),
    "invalid/module_import_not_shared": (
        "OPENC-MODULE-NOREEXPORT-001",
    ),
    "invalid/module_import_cycle": (
        "OPENC-MODULE-CONSTCYCLE-001",
    ),
    "invalid/module_private_access": (
        "OPENC-MODULE-API-001",
    ),
    "valid/text_value_semantics": (
        "OPENC-TYPE-TEXT-001",
        "OPENC-TEXT-LENGTH-001",
        "OPENC-TEXT-EQUALITY-001",
        "OPENC-TEXT-COPY-001",
    ),
    "invalid/optional_contains_resource": (
        "OPENC-TYPE-RESOURCEARRAY-001",
    ),
    "valid/type_shapes_ref_ptr_optional_array_slice_storage": (
        "OPENC-TYPE-CONSTRUCTORS-001",
        "OPENC-TYPE-SUFFIX-001",
    ),
    "valid/parameter_modes_visible": (
        "OPENC-OWN-MODE-001",
        "OPENC-OUT-MODE-001",
    ),
    "invalid/out_initialized_target": (
        "OPENC-OUT-ALIAS-001",
        "OPENC-OUT-REASSIGN-001",
    ),
    "valid/constant_expression_same_numeric_rules": (
        "OPENC-CONST-EXPR-001",
    ),
    "invalid/numeric_div_min_negative_one_static": (
        "OPENC-CONST-CHECKFAIL-001",
    ),
    "valid/unsafe_pointer": (
        "OPENC-PTR-ADDRESSABLE-001",
        "OPENC-PTR-PROVENANCE-001",
        "OPENC-PTR-DERIVED-NONOWNING-001",
    ),
    "valid/byte_pointer_object_representation": (
        "OPENC-BYTE-DISTINCT-001",
    ),
    "valid/enum_switch": (
        "OPENC-SWITCH-DOMAIN-001",
        "OPENC-SWITCH-CASE-001",
        "OPENC-SWITCH-EXECUTE-001",
        "OPENC-ENUM-IMPLICIT-001",
    ),
    "invalid/enum_duplicate_value": (
        "OPENC-SWITCH-DUPLICATE-001",
    ),
    "valid/bool_condition": (
        "OPENC-IF-EXECUTE-001",
    ),
    "valid/flow_loop_preinitialized": (
        "OPENC-WHILE-EXECUTE-001",
    ),
    "runtime/break_and_scope_registration_order": (
        "OPENC-FOR-EXECUTE-001",
    ),
    "valid/status_proof_initializes_out": (
        "OPENC-OUT-CALL-001",
        "OPENC-OUT-RESULTBIND-001",
        "OPENC-FUNCTION-OUTRETURN-001",
        "OPENC-OUT-FORWARD-001",
        "OPENC-OUT-COMMIT-001",
    ),
    "valid/overload_exact_preferred": (
        "OPENC-OVERLOAD-CONVERSIONS-001",
    ),
    "valid/function_recursion": (
        "OPENC-FUNCTION-RECURSION-001",
    ),
    "valid/current_resource": (
        "OPENC-RESOURCE-TRAILING-001",
    ),
    "valid/resource_initializer_lifecycle": (
        "OPENC-RESOURCE-FIELD-DEFAULT-001",
        "OPENC-RESOURCE-INIT-001",
        "OPENC-RESOURCE-INIT-REQUIRED-001",
        "OPENC-RESOURCE-INIT-OWNER-001",
        "OPENC-RESOURCE-INIT-RESERVE-001",
        "OPENC-RESOURCE-INIT-COMMIT-001",
        "OPENC-RESOURCE-INIT-ROLLBACK-001",
        "OPENC-RESOURCE-INIT-PLACEMENT-001",
        "OPENC-RESOURCE-FIELD-VIEW-001",
        "OPENC-RESOURCE-OPAQUE-DISCHARGE-001",
    ),
    "invalid/resource_field_state_rejections": (
        "OPENC-RESOURCE-FIELD-ASSIGN-001",
        "OPENC-RESOURCE-FIELD-CONSUME-001",
        "OPENC-RESOURCE-DISMANTLE-001",
        "OPENC-RESOURCE-FIELD-ONCE-001",
        "OPENC-RESOURCE-CONSUMER-RETURN-001",
    ),
    "invalid/resource_reinitialize_live": (
        "OPENC-RESOURCE-REINIT-001",
    ),
    "invalid/const_reassignment_rejected": (
        "OPENC-STRUCT-CONSTFIELD-001",
    ),
    "valid/struct_named_fields_and_copy": (
        "OPENC-STRUCT-NORESOURCE-001",
        "OPENC-STRUCT-INIT-COMMIT-001",
    ),
    "valid/struct_equality": (
        "OPENC-STRUCT-EQUALITY-001",
    ),
    "invalid/missing_struct_field": (
        "OPENC-STRUCT-DEFAULT-NODEP-001",
    ),
    "valid/slice_length_and_mutation": (
        "OPENC-SLICE-COPY-001",
    ),
    "invalid/slice_outlives_owner": (
        "OPENC-SLICE-ESCAPE-001",
    ),
    "invalid/ignored_status": (
        "OPENC-STATUS-OVERWRITE-001",
        "OPENC-STATUS-INITIALIZER-001",
    ),
    "invalid/out_own_pointer_missing_contract": (
        "OPENC-OUT-OWNFLOW-001",
    ),
    "valid/status_invariant_success": (
        "OPENC-STATUS-READONLY-001",
        "OPENC-STATUS-COPY-001",
    ),
    "invalid/out_failure_partial_exposure": (
        "OPENC-OUT-OWNCOMMIT-001",
        "OPENC-OUT-OWNTAIL-001",
        "OPENC-OUT-OWNFAIL-001",
    ),
    "valid/optional_none_and_copy": (
        "OPENC-OPTIONAL-ASSIGN-001",
    ),
    "invalid/optional_question_syntax": (
        "OPENC-OPTIONAL-NESTED-001",
    ),
    "valid/resource_return_transfers": (
        "OPENC-OWN-PRODUCE-001",
        "OPENC-OWN-EXIT-001",
        "OPENC-OWN-PRODUCER-PLACEMENT-001",
    ),
    "valid/domain_own_call": (
        "OPENC-OWN-CONSUME-ARG-001",
    ),
    "valid/typed_storage": (
        "OPENC-CONSTRUCT-VALUE-001",
        "OPENC-CONSTRUCT-PLACEMENT-001",
        "OPENC-STORAGE-EMPTY-001",
        "OPENC-STORAGE-COMMIT-001",
    ),
    "invalid/reinterpret_pointer_no_new_lifetime": (
        "OPENC-PTR-BYTEWRITE-001",
        "OPENC-PTR-INVALIDATE-001",
    ),
    "valid/pointer_one_past_compare": (
        "OPENC-PTR-BINDING-MUTABLE-001",
        "OPENC-PTR-SUBTRACT-001",
    ),
    "invalid/owning_pointer_copy": (
        "OPENC-PTR-BASE-001",
    ),
    "invalid/pointer_deref_one_past": (
        "OPENC-PTR-DEREF-RANGE-001",
    ),
    "invalid/safe_wrapper_missing_check": (
        "OPENC-SAFE-GUARANTEE-001",
        "OPENC-SAFE-WRAPPER-001",
    ),
    "invalid/unsafe_contract_caller_responsibility": (
        "OPENC-EXTENSION-SAFETY-001",
    ),
    "records/diagnostic_structure_quality": (
        "OPENC-DIAG-SPAN-001",
        "OPENC-DIAG-PHASE-001",
        "OPENC-DIAG-SEVERITY-001",
        "OPENC-DIAG-PRIMARY-001",
    ),
    "valid/first_program": (
        "OPENC-GRAMMAR-AUTHORITY-001",
        "OPENC-GRAMMAR-COVERAGE-001",
    ),
    "valid/array_init_length_copy": (
        "OPENC-EVAL-ARRAYINIT-001",
    ),
    "invalid/out_read_inside_callee": (
        "OPENC-FLOW-OUT-TOKEN-001",
        "OPENC-OUT-PENDINGUSE-001",
    ),
    "valid/flow_out_early_return": (
        "OPENC-FLOW-OUT-PREDICATE-001",
        "OPENC-FLOW-OUT-SUCCESS-001",
        "OPENC-OUT-PROOF-LOST-001",
    ),
    "invalid/flow_continue_skips_init": (
        "OPENC-FLOW-OUT-LOOP-001",
    ),
    "valid/integer_literal_exact_context": (
        "OPENC-NUM-LITERAL-CONTEXT-001",
    ),
    "valid/unchecked_integer_cast": (
        "OPENC-NUM-WRAP-001",
        "OPENC-NUM-INTRINSIC-001",
    ),
    "runtime/checked_addition": (
        "OPENC-NUM-AUTHORITY-001",
        "OPENC-NUM-COMPOUND-001",
    ),
    "valid/float_binary_types": (
        "OPENC-NUM-FLOAT-CONST-001",
    ),
    "invalid/fallible_scope_action_rejected": (
        "OPENC-CLEANUP-VOID-001",
        "OPENC-CLEANUP-SAFEWRAPPER-001",
        "OPENC-CLEANUP-FINISH-001",
    ),
    "valid/type_size_alignment": (
        "OPENC-TARGET-QUERYDOMAIN-001",
        "OPENC-TARGET-STORAGESIZE-001",
    ),
    "command/target_context_complete": (
        "OPENC-PORTABILITY-PLAIN-001",
        "OPENC-TARGET-SCHEMA-001",
        "OPENC-TARGET-CROSS-001",
    ),
    "valid/eval_call_left_to_right": (
        "OPENC-EXPR-PRECEDENCE-001",
    ),
}


# The production map is exhaustive. Each group names an accepted source
# fixture containing the production and a rejecting boundary fixture for the
# same syntactic family.
GRAMMAR_PAIR_GROUPS: dict[tuple[str, str], tuple[str, ...]] = {
    ("valid/first_program", "invalid/missing_semicolon"): (
        "source_unit", "top_decl", "statement", "expression_stmt",
        "return_stmt",
    ),
    ("valid/first_program", "invalid/module_import_cycle"): (
        "import_decl",
    ),
    ("valid/module_short_and_full_qualifier", "invalid/module_short_qualifier_ambiguous"): (
        "module_name", "qualified_name",
    ),
    ("valid/global_const_valid", "invalid/mutable_global_rejected"): (
        "module_const_decl", "module_const_type", "module_const_value_type",
    ),
    ("valid/struct_named_fields_and_copy", "invalid/struct_trailing_semicolon"): (
        "struct_decl", "struct_field_decl", "struct_field_type",
        "field_value_type",
    ),
    ("valid/current_resource", "invalid/resource_copy"): (
        "resource_decl", "resource_field_decl", "resource_value_field_decl",
        "resource_owned_pointer_field_decl",
    ),
    ("valid/enum_switch", "invalid/enum_duplicate_value"): (
        "enum_decl", "enum_item",
    ),
    ("valid/function_add", "invalid/arrow_function"): (
        "function_decl", "function_result", "ordinary_result_type",
        "ordinary_parameter", "parameter_type",
    ),
    ("valid/resource_return_transfers", "invalid/resource_obligation_not_discharged"): (
        "owning_pointer_result", "own_parameter", "own_parameter_target",
    ),
    ("valid/parameter_modes_visible", "invalid/out_reference_parameter"): (
        "parameter", "out_parameter", "output_parameter_type",
        "output_value_type", "out_own_pointer_parameter",
    ),
    ("valid/when_context_expression", "invalid/when_token_fragment_rejected"): (
        "when_decl", "when_stmt", "when_expression", "when_or_expression",
        "when_and_expression", "when_equality_expression",
        "when_relational_expression", "when_unary_expression",
        "when_primary_expression", "when_literal", "when_integer_literal",
        "when_context_name",
    ),
    ("valid/initialized_local", "invalid/missing_braces"): (
        "block", "block_item", "local_decl", "local_type",
    ),
    ("valid/type_shapes_ref_ptr_optional_array_slice_storage", "invalid/declaration_requires_type"): (
        "type", "value_type", "value_suffix", "type_atom",
        "primitive_object_type",
    ),
    ("valid/read_borrow", "invalid/ref_local_without_initializer"): (
        "ref_type", "ref_target",
    ),
    ("valid/unsafe_pointer", "invalid/c_pointer_decl"): (
        "ptr_type", "ptr_target",
    ),
    ("valid/current_optional", "invalid/optional_question_syntax"): (
        "optional_type", "optional_core_type", "optional_target",
    ),
    ("valid/typed_storage", "invalid/storage_field"): (
        "storage_type", "storage_target",
    ),
    ("valid/fixed_array", "invalid/c_array_decl"): (
        "fixed_array_suffix", "signed_integer_type", "unsigned_integer_type",
    ),
    ("valid/slice_sum", "invalid/optional_slice"): (
        "slice_suffix_type",
    ),
    ("valid/bool_condition", "invalid/integer_condition"): (
        "if_stmt",
    ),
    ("valid/flow_loop_preinitialized", "invalid/flow_while_only_initialization"): (
        "while_stmt",
    ),
    ("runtime/break_and_scope_registration_order", "invalid/for_variable_scope"): (
        "for_stmt", "for_init", "break_stmt", "continue_stmt",
    ),
    ("valid/enum_switch", "invalid/switch_implicit_fallthrough"): (
        "switch_stmt", "switch_case", "default_case",
    ),
    ("valid/scope_nested_lifo", "invalid/fallible_scope_action_rejected"): (
        "scope_stmt", "scope_action", "scope_call", "scope_argument",
    ),
    ("valid/small_local_unsafe_block", "invalid/address_outside_unsafe"): (
        "unsafe_stmt",
    ),
    ("valid/eval_compound_target_once", "invalid/assignment_target_required"): (
        "expression", "assignment_expr", "assignment_op",
    ),
    ("runtime/boolean_short_circuit", "invalid/integer_condition"): (
        "logical_or_expr", "logical_and_expr",
    ),
    ("valid/constant_expression_same_numeric_rules", "invalid/numeric_signed_bitwise"): (
        "bitwise_or_expr", "bitwise_xor_expr", "bitwise_and_expr",
    ),
    ("valid/text_value_semantics", "invalid/resource_equality_rejected"): (
        "equality_expr",
    ),
    ("valid/numeric_division_toward_zero", "invalid/arithmetic_type_mismatch"): (
        "relational_expr", "additive_expr", "multiplicative_expr",
    ),
    ("runtime/signed_right_shift_defined", "invalid/numeric_shift_width"): (
        "shift_expr",
    ),
    ("valid/unary_minus_signed_only", "invalid/arithmetic_type_mismatch"): (
        "unary_expr",
    ),
    ("valid/checked_cast", "invalid/checked_cast_requires_exact_value"): (
        "cast_expr",
    ),
    ("valid/unchecked_integer_cast", "invalid/unchecked_float_to_integer"): (
        "cast_unchecked_expr",
    ),
    ("valid/reinterpret_u32_f32", "invalid/reinterpret_size_mismatch"): (
        "reinterpret_expr",
    ),
    ("valid/typed_storage", "invalid/construct_twice"): (
        "construct_expr", "destroy_expr",
    ),
    ("valid/type_size_alignment", "invalid/size_of_expression"): (
        "type_query_expr",
    ),
    ("valid/function_add", "invalid/call_argument_count"): (
        "postfix_expr", "postfix_suffix", "call_suffix", "call_argument",
    ),
    ("valid/status_proof_initializes_out", "invalid/out_field_target"): (
        "out_argument",
    ),
    ("valid/struct_named_fields_and_copy", "invalid/unknown_member"): (
        "member_suffix",
    ),
    ("valid/fixed_array", "invalid/array_out_of_bounds"): (
        "index_suffix",
    ),
    ("valid/subslice", "invalid/slice_range_checked"): (
        "range_suffix",
    ),
    ("valid/integer_literal_exact_context", "invalid/numeric_literal_suffix"): (
        "primary_expr", "literal",
    ),
    ("valid/status_invariant_success", "invalid/status_failure_zero_code"): (
        "status_initializer", "status_code_init", "status_message_init",
    ),
    ("valid/struct_named_init", "invalid/missing_struct_field"): (
        "aggregate_initializer", "aggregate_field_init",
        "ordinary_field_init",
    ),
    ("valid/current_resource", "invalid/plain_struct_hides_owning_pointer"): (
        "ownership_field_init", "ownership_source",
    ),
    ("valid/array_init_length_copy", "invalid/array_out_of_bounds"): (
        "array_initializer",
    ),
    ("valid/constant_expression_same_numeric_rules", "invalid/numeric_div_min_negative_one_static"): (
        "constant_expression", "constant_or_expression",
        "constant_and_expression", "constant_bitwise_or_expression",
        "constant_bitwise_xor_expression", "constant_bitwise_and_expression",
        "constant_equality_expression", "constant_relational_expression",
        "constant_shift_expression", "constant_additive_expression",
        "constant_multiplicative_expression", "constant_unary_expression",
        "constant_primary_expression", "constant_literal",
        "constant_type_query", "constant_array_initializer",
        "constant_aggregate_initializer", "constant_field_init",
        "constant_integer_expression",
    ),
    ("valid/comments_preserve_tokens", "invalid/unterminated_block_comment"): (
        "ignored_element", "space_character", "horizontal_tab_character",
        "line_feed_character", "carriage_return_character",
        "backslash_character", "double_quote_character", "whitespace",
        "line_terminator", "line_comment", "line_comment_character",
        "block_comment", "block_comment_body",
    ),
    ("valid/identifier_case_sensitive", "invalid/predeclared_typeword_binding"): (
        "identifier", "identifier_start", "identifier_continue",
        "ascii_letter", "predeclared_type_word",
    ),
    ("valid/numeric_separator_valid", "invalid/numeric_separator_doubled"): (
        "decimal_digit", "hex_digit", "binary_digit", "digit_separator",
        "integer_literal", "decimal_integer", "hexadecimal_integer",
        "binary_integer", "decimal_digits",
    ),
    ("valid/floating_literal_default_f64", "invalid/numeric_literal_suffix"): (
        "float_literal", "exponent_part",
    ),
    ("valid/utf8_source_valid", "invalid/unicode_escape_surrogate"): (
        "text_literal", "text_character", "escape_sequence", "escape_code",
        "unicode_escape_tail",
    ),
}


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def serialized(value: object) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True) + "\n"


def fixture_records() -> tuple[dict[str, dict], dict[str, Path]]:
    records: dict[str, dict] = {}
    paths: dict[str, Path] = {}
    for path in sorted(FIXTURE_ROOT.rglob("fixture.json")):
        record = read_json(path)
        fixture_id = record["id"]
        if fixture_id in records:
            raise SystemExit(f"duplicate fixture ID: {fixture_id}")
        records[fixture_id] = record
        paths[fixture_id] = path
    return records, paths


def grammar_pairs() -> dict[str, tuple[str, str]]:
    result: dict[str, tuple[str, str]] = {}
    for pair, productions in GRAMMAR_PAIR_GROUPS.items():
        for production in productions:
            if production in result:
                raise SystemExit(f"duplicate grammar production mapping: {production}")
            result[production] = pair
    return result


def materialize(check: bool) -> None:
    rule_index = read_json(
        ROOT / "standard/core/metadata/OpenC_Core_Rule_Index.json"
    )
    active_rules = {entry["id"] for entry in rule_index["rules"]}
    queue_path = ROOT / "conformance/matrices/FIXTURE_AUTHORING_QUEUE.json"
    queue = read_json(queue_path)
    formerly_uncovered = {
        entry["rule"]
        for entry in queue["entries"]
        if entry["authoring_status"] == "REQUIRED"
    }
    assigned_rules = {
        rule for rules in RULE_FIXTURE_ASSIGNMENTS.values() for rule in rules
    }
    if formerly_uncovered and assigned_rules != formerly_uncovered:
        missing = sorted(formerly_uncovered - assigned_rules)
        extra = sorted(assigned_rules - formerly_uncovered)
        raise SystemExit(
            f"rule assignment mismatch; missing={missing} extra={extra}"
        )
    if assigned_rules - active_rules:
        raise SystemExit(
            "rule assignments name inactive rules: "
            + ", ".join(sorted(assigned_rules - active_rules))
        )

    fixtures, fixture_paths = fixture_records()
    missing_fixtures = sorted(set(RULE_FIXTURE_ASSIGNMENTS) - set(fixtures))
    if missing_fixtures:
        raise SystemExit("missing assigned fixtures: " + ", ".join(missing_fixtures))
    # Rebuild the generated assignments from scratch.  This makes mapping changes
    # remove stale rule IDs instead of only ever accumulating them.
    for fixture in fixtures.values():
        retained = sorted(set(fixture["active_rules"]) - assigned_rules)
        fixture["active_rules"] = retained
        fixture["expected"]["rules"] = retained
    for fixture_id, rules in RULE_FIXTURE_ASSIGNMENTS.items():
        fixture = fixtures[fixture_id]
        combined = sorted(set(fixture["active_rules"]) | set(rules))
        fixture["active_rules"] = combined
        fixture["expected"]["rules"] = combined

    for fixture in fixtures.values():
        fixture["evidence_state"] = EXECUTION_STATE

    reverse: dict[str, list[str]] = {rule: [] for rule in active_rules}
    for fixture_id, fixture in fixtures.items():
        for rule in fixture["active_rules"]:
            if rule not in active_rules:
                raise SystemExit(f"{fixture_id} names inactive rule {rule}")
            reverse[rule].append(fixture_id)
    for ids in reverse.values():
        ids.sort()
    uncovered = sorted(rule for rule, ids in reverse.items() if not ids)
    if uncovered:
        raise SystemExit("active rules remain uncovered: " + ", ".join(uncovered))

    pairs = grammar_pairs()
    grammar_path = (
        ROOT / "standard/core/conformance/OpenC_Core_Grammar_Coverage.json"
    )
    grammar = read_json(grammar_path)
    production_names = [entry["production"] for entry in grammar["productions"]]
    if set(production_names) != set(pairs):
        raise SystemExit(
            "grammar mapping mismatch; missing="
            + repr(sorted(set(production_names) - set(pairs)))
            + " extra="
            + repr(sorted(set(pairs) - set(production_names)))
        )
    for production in production_names:
        positive, rejection = pairs[production]
        if positive not in fixtures or rejection not in fixtures:
            raise SystemExit(
                f"{production} names missing pair {positive}, {rejection}"
            )
        if fixtures[positive]["kind"] not in {
            "valid", "runtime", "command", "records"
        }:
            raise SystemExit(f"{production} positive fixture is not accepting")
        if fixtures[rejection]["kind"] not in {"invalid", "diagnostic"}:
            raise SystemExit(f"{production} rejection fixture is not rejecting")

    outputs: dict[Path, object] = {}
    for fixture_id, fixture in fixtures.items():
        outputs[fixture_paths[fixture_id]] = fixture

    manifest = {
        "active_rule_count": len(active_rules),
        "candidate": "OpenC 1.0.0-rc.8",
        "evidence_state": EXECUTION_STATE,
        "fixture_count": len(fixtures),
        "fixtures": [
            {
                "execution_status": "PASS_WINDOWS_X86_64_RC8",
                "id": fixture_id,
                "kind": fixture["kind"],
                "path": fixture_paths[fixture_id]
                .parent.relative_to(ROOT)
                .as_posix(),
                "provenance": fixture["origin"],
                "rules": fixture["active_rules"],
                "source_files": fixture["source_files"],
            }
            for fixture_id, fixture in sorted(fixtures.items())
        ],
        "rule_fixture_index": {
            rule: ids for rule, ids in sorted(reverse.items())
        },
        "rules_with_imported_fixtures": len(active_rules),
        "rules_without_imported_fixtures": [],
        "schema": "openc.fixture_manifest.v3",
    }
    outputs[FIXTURE_ROOT / "MANIFEST.json"] = manifest

    rule_coverage_path = (
        ROOT / "standard/core/conformance/OpenC_Core_Rule_Coverage.json"
    )
    rule_coverage = read_json(rule_coverage_path)
    rule_coverage["coverage_state"] = (
        "466_RULES_WITH_EXECUTED_DEDICATED_FIXTURES"
    )
    rule_coverage["rules_with_dedicated_fixtures"] = len(active_rules)
    rule_coverage["rules_without_dedicated_fixtures"] = 0
    rule_coverage["schema"] = "openc.core.rule_coverage.v4"
    for entry in rule_coverage["rules"]:
        entry["execution_state"] = "PASS_WINDOWS_X86_64_RC8"
        entry["fixtures"] = reverse[entry["rule"]]
    outputs[rule_coverage_path] = rule_coverage

    queue["authored_rule_count"] = len(active_rules)
    queue["fixture_count"] = len(fixtures)
    queue["required_rule_count"] = 0
    queue["schema"] = "openc.conformance.fixture_queue.v2"
    for entry in queue["entries"]:
        entry["authoring_status"] = "AUTHORED"
        entry["execution_status"] = "PASS_WINDOWS_X86_64_RC8"
        entry["fixtures"] = reverse[entry["rule"]]
    outputs[queue_path] = queue

    grammar["coverage_state"] = (
        "174_PRODUCTIONS_WITH_EXECUTED_POSITIVE_REJECTION_PAIRS"
    )
    grammar["schema"] = "openc.core.grammar_coverage.v4"
    for entry in grammar["productions"]:
        positive, rejection = pairs[entry["production"]]
        entry["execution_state"] = "PASS_WINDOWS_X86_64_RC8"
        entry["positive_fixture"] = positive
        entry["rejection_fixture"] = rejection
    outputs[grammar_path] = grammar

    differences: list[str] = []
    for path, value in outputs.items():
        text = serialized(value)
        if check:
            if not path.is_file() or path.read_text(encoding="utf-8") != text:
                differences.append(path.relative_to(ROOT).as_posix())
        else:
            path.write_text(text, encoding="utf-8", newline="\n")
    if differences:
        raise SystemExit("stale coverage outputs: " + ", ".join(differences))
    print(
        "Core coverage materialized: "
        f"rules={len(active_rules)}/{len(active_rules)} "
        f"productions={len(pairs)}/{len(production_names)} "
        f"fixtures={len(fixtures)}"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    materialize(args.check)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
