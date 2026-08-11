#ifndef OPENC_SH5_RUNTIME_H
#define OPENC_SH5_RUNTIME_H

#define OPENC_RUNTIME_BUILD 1
#include "openc_runtime.h"
#include <limits.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

void ocb_process_initialize(int argc, char **argv);
void ocb_process_finalize(void);

void *ocb_memory_alloc(uintptr_t size);
void ocb_memory_free(void *allocation);
uintptr_t ocb_memory_load_usize(const void *address);
void ocb_memory_store_usize(void *address, uintptr_t value);

typedef int32_t (*ocb_compiler_parallel_callback)(
    void *state,
    uintptr_t worker
);
int32_t ocb_compiler_parallel_jobs(
    void *state,
    uintptr_t worker_count,
    void *callback
);

uintptr_t ocb_compiler_semantic_derived_type_impl(
    uint8_t *type_data,
    uintptr_t *type_count,
    uintptr_t kind,
    uintptr_t element,
    uintptr_t array_length,
    bool const_qualified,
    bool preserve_name
);

uintptr_t ocb_compiler_ir_root_in_bounds_impl(
    uint8_t *syntax_data,
    uintptr_t syntax_length,
    uint8_t *expression_nodes,
    uintptr_t expression_count,
    uint8_t *expression_start_heads,
    uint8_t *expression_start_next,
    uintptr_t expression_start_capacity,
    uint8_t *expression_next_start,
    uintptr_t *profile_expression_positions,
    uintptr_t start,
    uintptr_t end
);
uintptr_t ocb_compiler_ir_first_name_impl(
    uint8_t *syntax_data,
    uintptr_t syntax_length,
    uint8_t *expression_start_heads,
    uint8_t *expression_start_next,
    uintptr_t expression_start_capacity,
    uint8_t *expression_next_start,
    uintptr_t *profile_expression_positions,
    uint8_t *name_nodes,
    uintptr_t name_count,
    uintptr_t event
);

/*
 * Compiler-private packed-buffer primitives. Calls are selected only for the
 * matching declarations in openc.selfhost.main; user functions with the same
 * spelling retain normal OpenC call semantics. These helpers operate on
 * compiler-owned, aligned buffers and remove several generated call layers
 * from the compiler's hottest record-access path.
 */
#define ocb_compiler_record_stride() \
    ((uintptr_t)(5u * sizeof(uintptr_t)))
#define ocb_compiler_read_usize(data, offset) \
    (*(const uintptr_t *)((data) + (offset)))
#define ocb_compiler_write_usize(data, offset, value) \
    (*(uintptr_t *)((data) + (offset)) = (uintptr_t)(value))
#define ocb_compiler_read_record_field(data, record, field) \
    (((const uintptr_t *)(data))[(record) * 5u + (field)])
#define ocb_compiler_write_record_field(data, record, field, value) \
    (((uintptr_t *)(data))[(record) * 5u + (field)] = (uintptr_t)(value))
#define ocb_compiler_byte_at_or_zero(source, index) \
    ((index) < (source).length ? (source).data[(index)] : (uint8_t)0u)
#define ocb_compiler_starts_with_ascii(source, start, expected) \
    ((start) <= (source).length && \
     (expected).length <= (source).length - (start) && \
     ((expected).length == 0u || memcmp( \
        (source).data + (start), (expected).data, (expected).length) == 0))
#define ocb_compiler_span_equals_ascii( \
    source, start, span_length, expected) \
    ((span_length) == (expected).length && \
     ocb_compiler_starts_with_ascii((source), (start), (expected)))
#define ocb_compiler_semantic_spans_equal( \
    left, left_start, left_span_length, right, right_start, right_span_length) \
    ((left_span_length) == (right_span_length) && \
     (left_start) <= (left).length && \
     (left_span_length) <= (left).length - (left_start) && \
     (right_start) <= (right).length && \
     (right_span_length) <= (right).length - (right_start) && \
     ((left_span_length) == 0u || memcmp( \
        (left).data + (left_start), (right).data + (right_start), \
        (left_span_length)) == 0))
#define ocb_compiler_flow_span_has_byte( \
    source, start, span_length, expected) \
    ((start) <= (source).length && \
     (span_length) <= (source).length - (start) && \
     (span_length) != 0u && memchr( \
         (source).data + (start), (int)(expected), (span_length)) != NULL)
#define ocb_compiler_project_slice(source, start, span_length) \
    (((start) > (source).length || \
      (span_length) > (source).length - (start)) \
        ? (oc_text){NULL, 0u} \
        : (oc_text){(source).data + (start), (span_length)})

/*
 * Compiler-private output-buffer primitives. The C emitter invokes these for
 * every generated token. Keeping the successful path in the translation unit
 * avoids millions of tiny calls through the unoptimised bootstrap executable.
 * Emitted arguments are SSA temporaries, so repeated macro evaluation is safe.
 */
#define ocb_compiler_d_put_byte(buffer, value) do { \
    if (!(buffer)->ok || (buffer)->length >= (buffer)->capacity) { \
        (buffer)->ok = false; \
    } else { \
        (buffer)->data[(buffer)->length] = (uint8_t)(value); \
        (buffer)->length += 1u; \
    } \
} while (0)
#define ocb_compiler_d_put(buffer, value) do { \
    if (!(buffer)->ok || (buffer)->length > (buffer)->capacity || \
        (value).length > (buffer)->capacity - (buffer)->length) { \
        (buffer)->ok = false; \
    } else { \
        if ((value).length != 0u) { \
            memcpy((buffer)->data + (buffer)->length, \
                (value).data, (value).length); \
        } \
        (buffer)->length += (value).length; \
    } \
} while (0)
#define ocb_compiler_d_put_slice(buffer, value, start, span_length) do { \
    if (!(buffer)->ok || (buffer)->length > (buffer)->capacity || \
        (span_length) > (buffer)->capacity - (buffer)->length) { \
        (buffer)->ok = false; \
    } else { \
        if ((span_length) != 0u) { \
            memcpy((buffer)->data + (buffer)->length, \
                (value).data + (start), (span_length)); \
        } \
        (buffer)->length += (span_length); \
    } \
} while (0)
#define ocb_compiler_d_put_mangled_slice( \
    buffer, value, start, span_length) do { \
    uintptr_t ocb_mangled_index = 0u; \
    while (ocb_mangled_index < (span_length)) { \
        uint8_t ocb_mangled_octet = ocb_compiler_byte_at_or_zero( \
            (value), (start) + ocb_mangled_index); \
        if (ocb_mangled_octet == 46u) ocb_mangled_octet = 95u; \
        ocb_compiler_d_put_byte((buffer), ocb_mangled_octet); \
        ocb_mangled_index += 1u; \
    } \
} while (0)
#define ocb_compiler_d_put_usize(buffer, value) do { \
    uintptr_t ocb_decimal_value = (uintptr_t)(value); \
    if (ocb_decimal_value == 0u) { \
        ocb_compiler_d_put_byte((buffer), 48u); \
    } else { \
        uintptr_t ocb_decimal_divisor = 1u; \
        uintptr_t ocb_decimal_remaining = ocb_decimal_value; \
        while (ocb_decimal_remaining >= 10u) { \
            ocb_decimal_divisor *= 10u; \
            ocb_decimal_remaining /= 10u; \
        } \
        while (ocb_decimal_divisor != 0u) { \
            ocb_compiler_d_put_byte((buffer), \
                48u + (ocb_decimal_value / ocb_decimal_divisor) % 10u); \
            ocb_decimal_divisor /= 10u; \
        } \
    } \
} while (0)
#define ocb_compiler_node_contains(data, parent, child) \
    (((const uintptr_t *)(data))[(child) * 5u + 1u] >= \
        ((const uintptr_t *)(data))[(parent) * 5u + 1u] && \
     ((const uintptr_t *)(data))[(child) * 5u + 1u] + \
        ((const uintptr_t *)(data))[(child) * 5u + 2u] <= \
     ((const uintptr_t *)(data))[(parent) * 5u + 1u] + \
        ((const uintptr_t *)(data))[(parent) * 5u + 2u])
#define ocb_compiler_pack_span(start, length) \
    ((uintptr_t)(start) * (uintptr_t)UINT64_C(4294967296) + \
        (uintptr_t)(length))
#define ocb_compiler_ir_op_nop() ((uintptr_t)1u)
#define ocb_compiler_ir_op_const_integer() ((uintptr_t)2u)
#define ocb_compiler_ir_op_const_float() ((uintptr_t)3u)
#define ocb_compiler_ir_op_const_text() ((uintptr_t)4u)
#define ocb_compiler_ir_op_const_bool() ((uintptr_t)5u)
#define ocb_compiler_ir_op_local_alloc() ((uintptr_t)6u)
#define ocb_compiler_ir_op_load() ((uintptr_t)7u)
#define ocb_compiler_ir_op_store() ((uintptr_t)8u)
#define ocb_compiler_ir_op_unary() ((uintptr_t)9u)
#define ocb_compiler_ir_op_binary() ((uintptr_t)10u)
#define ocb_compiler_ir_op_short_begin() ((uintptr_t)11u)
#define ocb_compiler_ir_op_short_end() ((uintptr_t)12u)
#define ocb_compiler_ir_op_compare() ((uintptr_t)13u)
#define ocb_compiler_ir_op_cast() ((uintptr_t)14u)
#define ocb_compiler_ir_op_reinterpret() ((uintptr_t)15u)
#define ocb_compiler_ir_op_address() ((uintptr_t)16u)
#define ocb_compiler_ir_op_bounds() ((uintptr_t)17u)
#define ocb_compiler_ir_op_call() ((uintptr_t)18u)
#define ocb_compiler_ir_op_branch() ((uintptr_t)19u)
#define ocb_compiler_ir_op_branch_conditional() ((uintptr_t)20u)
#define ocb_compiler_ir_op_return() ((uintptr_t)21u)
#define ocb_compiler_ir_op_return_void() ((uintptr_t)22u)
#define ocb_compiler_ir_op_aggregate_create() ((uintptr_t)23u)
#define ocb_compiler_ir_op_aggregate_field() ((uintptr_t)24u)
#define ocb_compiler_ir_op_array_create() ((uintptr_t)25u)
#define ocb_compiler_ir_op_slice_create() ((uintptr_t)26u)
#define ocb_compiler_ir_op_optional_none() ((uintptr_t)27u)
#define ocb_compiler_ir_op_optional_some() ((uintptr_t)28u)
#define ocb_compiler_ir_op_status_create() ((uintptr_t)29u)
#define ocb_compiler_ir_op_scope_register() ((uintptr_t)30u)
#define ocb_compiler_ir_op_object_construct() ((uintptr_t)31u)
#define ocb_compiler_ir_op_object_destroy() ((uintptr_t)32u)
#define ocb_compiler_ir_op_target_fault() ((uintptr_t)33u)
#define ocb_compiler_resolution_symbol_function() ((uintptr_t)1u)
#define ocb_compiler_resolution_symbol_struct() ((uintptr_t)2u)
#define ocb_compiler_resolution_symbol_resource() ((uintptr_t)3u)
#define ocb_compiler_resolution_symbol_enum() ((uintptr_t)4u)
#define ocb_compiler_resolution_symbol_enum_item() ((uintptr_t)5u)
#define ocb_compiler_resolution_symbol_constant() ((uintptr_t)6u)
#define ocb_compiler_resolution_symbol_parameter() ((uintptr_t)7u)
#define ocb_compiler_resolution_symbol_variable() ((uintptr_t)8u)
#define ocb_compiler_resolution_symbol_field() ((uintptr_t)9u)
#define ocb_compiler_semantic_type_error() ((uintptr_t)0u)
#define ocb_compiler_semantic_type_void() ((uintptr_t)1u)
#define ocb_compiler_semantic_type_bool() ((uintptr_t)2u)
#define ocb_compiler_semantic_type_byte() ((uintptr_t)3u)
#define ocb_compiler_semantic_type_text() ((uintptr_t)4u)
#define ocb_compiler_semantic_type_status() ((uintptr_t)5u)
#define ocb_compiler_semantic_builtin_type( \
    source, start, span_length) \
    (((start) > (source).length || \
      (span_length) > (source).length - (start)) ? (uintptr_t)0u : \
     ((span_length) == 2u && memcmp((source).data + (start), "i8", 2u) == 0) \
        ? (uintptr_t)6u : \
     ((span_length) == 2u && memcmp((source).data + (start), "u8", 2u) == 0) \
        ? (uintptr_t)7u : \
     ((span_length) == 3u && memcmp((source).data + (start), "i16", 3u) == 0) \
        ? (uintptr_t)8u : \
     ((span_length) == 3u && memcmp((source).data + (start), "u16", 3u) == 0) \
        ? (uintptr_t)9u : \
     ((span_length) == 3u && memcmp((source).data + (start), "i32", 3u) == 0) \
        ? (uintptr_t)10u : \
     ((span_length) == 3u && memcmp((source).data + (start), "u32", 3u) == 0) \
        ? (uintptr_t)11u : \
     ((span_length) == 3u && memcmp((source).data + (start), "i64", 3u) == 0) \
        ? (uintptr_t)12u : \
     ((span_length) == 3u && memcmp((source).data + (start), "u64", 3u) == 0) \
        ? (uintptr_t)13u : \
     ((span_length) == 3u && memcmp((source).data + (start), "f32", 3u) == 0) \
        ? (uintptr_t)16u : \
     ((span_length) == 3u && memcmp((source).data + (start), "f64", 3u) == 0) \
        ? (uintptr_t)17u : \
     ((span_length) == 4u && memcmp((source).data + (start), "void", 4u) == 0) \
        ? (uintptr_t)1u : \
     ((span_length) == 4u && memcmp((source).data + (start), "bool", 4u) == 0) \
        ? (uintptr_t)2u : \
     ((span_length) == 4u && memcmp((source).data + (start), "byte", 4u) == 0) \
        ? (uintptr_t)3u : \
     ((span_length) == 4u && memcmp((source).data + (start), "text", 4u) == 0) \
        ? (uintptr_t)4u : \
     ((span_length) == 5u && memcmp((source).data + (start), "isize", 5u) == 0) \
        ? (uintptr_t)14u : \
     ((span_length) == 5u && memcmp((source).data + (start), "usize", 5u) == 0) \
        ? (uintptr_t)15u : \
     ((span_length) == 6u && memcmp((source).data + (start), "status", 6u) == 0) \
        ? (uintptr_t)5u : (uintptr_t)0u)
#define ocb_compiler_semantic_derived_type( \
    type_data, types, kind, element, array_length, \
    const_qualified, preserve_name) \
    ocb_compiler_semantic_derived_type_impl( \
        (type_data), &(types)->length, (kind), (element), (array_length), \
        (const_qualified), (preserve_name))
#define ocb_compiler_flow_statement_kind(kind) \
    ((uintptr_t)(kind) >= 11u && (uintptr_t)(kind) <= 25u)
#define ocb_compiler_flow_expression_kind(kind) \
    ((uintptr_t)(kind) >= 27u && (uintptr_t)(kind) <= 51u)
#define ocb_compiler_resolution_expression_kind(kind) \
    ((uintptr_t)(kind) >= 27u && (uintptr_t)(kind) <= 52u && \
     (uintptr_t)(kind) != 28u)
#define ocb_compiler_flow_node_operator( \
    source, syntax_data, node, expected) \
    ocb_compiler_span_equals_ascii( \
        (source), ocb_compiler_read_record_field((syntax_data), (node), 3u), \
        ocb_compiler_read_record_field((syntax_data), (node), 4u), (expected))
#define ocb_compiler_ir_type_element(context, type_id) \
    ((type_id) >= (context)->types.length ? (uintptr_t)0u : \
     ocb_compiler_read_record_field((context)->type_data, (type_id), 1u))
#define ocb_compiler_acceptance_kind(context, type_id) \
    ((type_id) >= (context)->types.length ? (uintptr_t)0u : \
     ocb_compiler_read_record_field((context)->type_data, (type_id), 0u))
#define ocb_compiler_acceptance_integer(context, type_id) \
    (ocb_compiler_acceptance_kind((context), (type_id)) == 2u || \
     ocb_compiler_acceptance_kind((context), (type_id)) == 3u || \
     ocb_compiler_acceptance_kind((context), (type_id)) == 6u)
#define ocb_compiler_flow_phase_name() ((uintptr_t)1u)
#define ocb_compiler_flow_phase_type() ((uintptr_t)2u)
#define ocb_compiler_flow_phase_flow() ((uintptr_t)3u)
#define ocb_compiler_flow_phase_ownership() ((uintptr_t)4u)
#define ocb_compiler_flow_phase_borrow() ((uintptr_t)5u)
#define ocb_compiler_flow_phase_unsafe() ((uintptr_t)6u)
#define ocb_compiler_flow_rule_safe_init() ((uintptr_t)1u)
#define ocb_compiler_flow_rule_status_duplicate() ((uintptr_t)2u)
#define ocb_compiler_flow_rule_status_code() ((uintptr_t)3u)
#define ocb_compiler_flow_rule_out_status() ((uintptr_t)4u)
#define ocb_compiler_flow_rule_out_carrier() ((uintptr_t)5u)
#define ocb_compiler_flow_rule_out_function_status() ((uintptr_t)6u)
#define ocb_compiler_flow_rule_out_return() ((uintptr_t)7u)
#define ocb_compiler_flow_rule_own_exit() ((uintptr_t)8u)
#define ocb_compiler_flow_rule_own_overwrite() ((uintptr_t)9u)
#define ocb_compiler_flow_rule_resource_duplicate_owner() ((uintptr_t)10u)
#define ocb_compiler_flow_rule_scope_owner_state() ((uintptr_t)11u)
#define ocb_compiler_flow_rule_own_cleanup_reserved() ((uintptr_t)12u)
#define ocb_compiler_flow_rule_own_double_discharge() ((uintptr_t)13u)
#define ocb_compiler_flow_rule_own_use_destroy() ((uintptr_t)14u)
#define ocb_compiler_flow_rule_own_use_move() ((uintptr_t)15u)
#define ocb_compiler_flow_rule_lifetime_use_destroy() ((uintptr_t)16u)
#define ocb_compiler_flow_rule_borrow_move() ((uintptr_t)17u)
#define ocb_compiler_flow_rule_borrow_conflict() ((uintptr_t)18u)
#define ocb_compiler_flow_rule_scope_action() ((uintptr_t)19u)
#define ocb_compiler_flow_rule_scope_nofail() ((uintptr_t)20u)
#define ocb_compiler_flow_rule_pointer_onepast() ((uintptr_t)21u)
#define ocb_compiler_flow_rule_pointer_address() ((uintptr_t)22u)
#define ocb_compiler_flow_rule_pointer_deref() ((uintptr_t)23u)
#define ocb_compiler_flow_rule_pointer_arithmetic() ((uintptr_t)24u)
#define ocb_compiler_flow_rule_reinterpret() ((uintptr_t)25u)
#define ocb_compiler_flow_rule_unsafe_required() ((uintptr_t)26u)
#define ocb_compiler_flow_rule_unsafe_call() ((uintptr_t)27u)
/* Bootstrap compatibility for the first prefix-recognition generation. */
#define ocb_compiler_flow_rule_text oc_openc_selfhost_main_flow_rule_text
#define ocb_compiler_ir_add_block(context, name_code) \
    (ocb_compiler_write_record_field( \
        (context)->block_data, (context)->blocks.length, 0u, \
        (context)->blocks.length), \
     ocb_compiler_write_record_field( \
        (context)->block_data, (context)->blocks.length, 1u, (name_code)), \
     (context)->blocks.length++)
#define ocb_compiler_ir_add_operand( \
    context, value, immediate_kind, immediate_one, immediate_two) \
    (ocb_compiler_write_record_field( \
        (context)->operand_data, (context)->operands.length, 0u, (value)), \
     ocb_compiler_write_record_field( \
        (context)->operand_data, (context)->operands.length, 1u, \
        (immediate_kind)), \
     ocb_compiler_write_record_field( \
        (context)->operand_data, (context)->operands.length, 2u, \
        (immediate_one)), \
     ocb_compiler_write_record_field( \
        (context)->operand_data, (context)->operands.length, 3u, \
        (immediate_two)), \
     (context)->operands.length++)
#define ocb_compiler_ir_operand_empty(context, value) \
    ocb_compiler_ir_add_operand((context), (value), 0u, 0u, 0u)
#define ocb_compiler_ir_operand_block(context, block) \
    ocb_compiler_ir_add_operand((context), 0u, 1u, (block), 0u)
#define ocb_compiler_ir_emit_instruction( \
    context, opcode, type_id, start, span_length, text_kind, text_one, text_two, \
    operand_first, operand_count, has_result) \
    (ocb_compiler_write_record_field( \
        (context)->instruction_data, (context)->instructions.length, 0u, \
        (context)->current_block), \
     ocb_compiler_write_record_field( \
        (context)->instruction_data, (context)->instructions.length, 1u, \
        (has_result) ? (context)->next_value : 0u), \
     ocb_compiler_write_record_field( \
        (context)->instruction_data, (context)->instructions.length, 2u, \
        (opcode)), \
     ocb_compiler_write_record_field( \
        (context)->instruction_data, (context)->instructions.length, 3u, \
        (type_id)), \
     ocb_compiler_write_record_field( \
        (context)->instruction_data, (context)->instructions.length, 4u, \
        ocb_compiler_pack_span((start), (span_length))), \
     ocb_compiler_write_record_field( \
        (context)->instruction_detail, (context)->instructions.length, 0u, \
        (text_kind)), \
     ocb_compiler_write_record_field( \
        (context)->instruction_detail, (context)->instructions.length, 1u, \
        (text_one)), \
     ocb_compiler_write_record_field( \
        (context)->instruction_detail, (context)->instructions.length, 2u, \
        (text_two)), \
     ocb_compiler_write_record_field( \
        (context)->instruction_detail, (context)->instructions.length, 3u, \
        (operand_first)), \
     ocb_compiler_write_record_field( \
        (context)->instruction_detail, (context)->instructions.length, 4u, \
        (operand_count)), \
     (context)->instructions.length++, \
     (has_result) ? (context)->next_value++ : 0u)
#define ocb_compiler_ir_emit_value( \
    context, opcode, type_id, node, text_kind, text_one, text_two, \
    operand_first, operand_count) \
    ocb_compiler_ir_emit_instruction( \
        (context), (opcode), (type_id), \
        ocb_compiler_read_record_field((context)->syntax_data, (node), 1u), \
        ocb_compiler_read_record_field((context)->syntax_data, (node), 2u), \
        (text_kind), (text_one), (text_two), (operand_first), \
        (operand_count), true)
#define ocb_compiler_ir_emit_void( \
    context, opcode, node, text_kind, text_one, text_two, operand_first, \
    operand_count) \
    ocb_compiler_ir_emit_instruction( \
        (context), (opcode), ocb_compiler_semantic_type_void(), \
        ocb_compiler_read_record_field((context)->syntax_data, (node), 1u), \
        ocb_compiler_read_record_field((context)->syntax_data, (node), 2u), \
        (text_kind), (text_one), (text_two), (operand_first), \
        (operand_count), false)
#define ocb_compiler_ir_block_parent(context, node) \
    ((context)->block_parent_cache != NULL && \
     (node) < (context)->syntax.length && \
     ocb_compiler_read_usize( \
        (context)->block_parent_cache, (node) * sizeof(uintptr_t)) <= \
        (context)->syntax.length \
        ? ocb_compiler_read_usize( \
            (context)->block_parent_cache, (node) * sizeof(uintptr_t)) \
        : oc_openc_selfhost_main_ir_block_parent((context), (node)))
#define ocb_compiler_ir_control_parent(context, node) \
    ((context)->control_parent_cache != NULL && \
     (node) < (context)->syntax.length && \
     ocb_compiler_read_usize( \
        (context)->control_parent_cache, (node) * sizeof(uintptr_t)) <= \
        (context)->syntax.length \
        ? ocb_compiler_read_usize( \
            (context)->control_parent_cache, (node) * sizeof(uintptr_t)) \
        : oc_openc_selfhost_main_ir_control_parent((context), (node)))
#define ocb_compiler_ir_function_cache_valid(context, node) \
    ((node) < (context)->syntax.length && \
     (context)->function_node < (context)->syntax.length && \
     ocb_compiler_read_record_field( \
        (context)->syntax_data, (context)->function_node, 0u) == 2u && \
     ocb_compiler_node_contains( \
        (context)->syntax_data, (context)->function_node, (node)))
#define ocb_compiler_ir_resolve_name(context, node) \
    ((context)->name_cache != NULL && \
     ocb_compiler_ir_function_cache_valid((context), (node)) && \
     ocb_compiler_read_usize( \
        (context)->name_cache, (node) * sizeof(uintptr_t)) != 0u \
        ? ocb_compiler_read_usize( \
            (context)->name_cache, (node) * sizeof(uintptr_t)) - 1u \
        : oc_openc_selfhost_main_ir_resolve_name((context), (node)))
#define ocb_compiler_ir_select_call(context, node) \
    ((context)->call_cache != NULL && \
     ocb_compiler_ir_function_cache_valid((context), (node)) && \
     ocb_compiler_read_usize( \
        (context)->call_cache, (node) * sizeof(uintptr_t)) != 0u \
        ? ocb_compiler_read_usize( \
            (context)->call_cache, (node) * sizeof(uintptr_t)) - 1u \
        : oc_openc_selfhost_main_ir_select_call((context), (node)))
#define ocb_compiler_ir_node_type(context, node, expected_type) \
    ((expected_type) == 0u && (context)->type_cache != NULL && \
     (node) < (context)->syntax.length && \
     ocb_compiler_read_usize( \
        (context)->type_cache, (node) * sizeof(uintptr_t)) != 0u \
        ? ocb_compiler_read_usize( \
            (context)->type_cache, (node) * sizeof(uintptr_t)) - 1u \
        : oc_openc_selfhost_main_ir_node_type( \
            (context), (node), (expected_type)))
#define ocb_compiler_ir_left_expression(context, parent, operator_start) \
    ((context)->left_expression_cache != NULL && \
     (parent) < (context)->syntax.length && \
     ocb_compiler_read_usize( \
        (context)->left_expression_cache, \
        (parent) * sizeof(uintptr_t)) <= (context)->syntax.length \
        ? ocb_compiler_read_usize( \
            (context)->left_expression_cache, \
            (parent) * sizeof(uintptr_t)) \
        : oc_openc_selfhost_main_ir_left_expression( \
            (context), (parent), (operator_start)))
#define ocb_compiler_ir_right_expression(context, parent, operator_end) \
    ((context)->right_expression_cache != NULL && \
     (parent) < (context)->syntax.length && \
     ocb_compiler_read_usize( \
        (context)->right_expression_cache, \
        (parent) * sizeof(uintptr_t)) <= (context)->syntax.length \
        ? ocb_compiler_read_usize( \
            (context)->right_expression_cache, \
            (parent) * sizeof(uintptr_t)) \
         : oc_openc_selfhost_main_ir_right_expression( \
             (context), (parent), (operator_end)))
#define ocb_compiler_ir_root_in_bounds(context, start, end) \
    ocb_compiler_ir_root_in_bounds_impl( \
        (context)->syntax_data, (context)->syntax.length, \
        (context)->expression_nodes, (context)->expression_count, \
        (context)->expression_start_heads, \
        (context)->expression_start_next, \
        (context)->expression_start_capacity, \
        (context)->expression_next_start, \
        &(context)->profile_expression_positions, (start), (end))
#define ocb_compiler_ir_first_name(context, event) \
    ocb_compiler_ir_first_name_impl( \
        (context)->syntax_data, (context)->syntax.length, \
        (context)->expression_start_heads, \
        (context)->expression_start_next, \
        (context)->expression_start_capacity, \
        (context)->expression_next_start, \
        &(context)->profile_expression_positions, \
        (context)->name_nodes, (context)->name_count, (event))

void ocb_io_print_text(oc_text value);
void ocb_io_print_i64(int64_t value);
void ocb_io_print_u64(uint64_t value);
void ocb_io_print_bool(bool value);
void ocb_io_println_text(oc_text value);
void ocb_io_println_i64(int64_t value);
void ocb_io_println_u64(uint64_t value);
void ocb_io_println_bool(bool value);
void ocb_io_error(oc_text value);

uintptr_t ocb_text_byte_length(oc_text value);
uint8_t ocb_text_byte_at_unchecked(oc_text value, uintptr_t index);
oc_text ocb_text_from_utf8(void *data, uintptr_t length);
oc_status ocb_text_slice(
    oc_text value,
    uintptr_t lower,
    uintptr_t upper,
    oc_text *result
);
bool ocb_text_equal(oc_text left, oc_text right);
int32_t ocb_text_compare(oc_text left, oc_text right);

oc_status ocb_file_read_text(oc_text path, oc_text *value);
oc_status ocb_file_read_text_cached(oc_text path, oc_text *value);
oc_status ocb_file_write_text(oc_text path, oc_text value);

oc_text ocb_path_join(oc_text left, oc_text right);
oc_text ocb_path_directory(oc_text value);

uintptr_t ocb_process_argument_count(void);
uintptr_t ocb_process_monotonic_milliseconds(void);
oc_text ocb_process_argument(uintptr_t index);
oc_text ocb_process_executable_directory(void);
oc_status ocb_process_run(
    oc_text command,
    int32_t *exit_code,
    oc_text *output
);

_Noreturn void ocb_checked_failure(oc_text message);
_Noreturn void ocb_target_fault(oc_text message);

/*
 * The native compiler backend emits checked arithmetic over SSA temporaries.
 * TinyCC does not inline the generic runtime functions, so record addressing
 * and loop increments otherwise cross the DLL boundary millions of times.
 * These private macros preserve the exact checked semantics while keeping the
 * successful usize path in the generated translation unit. Each argument is
 * an emitted SSA temporary and therefore has no side effects.
 */
#define oc_checked_add_usize(a, b, span_id) \
    (((uintptr_t)(a) > UINTPTR_MAX - (uintptr_t)(b)) \
        ? (oc_checked_failure( \
            OC_STATUS_INTEGER_OVERFLOW, \
            "OPENC-ARITH-RUNTIME-OVERFLOW-001", \
            "unsigned addition overflow", (span_id) \
        ), (uintptr_t)0) \
        : (uintptr_t)((uintptr_t)(a) + (uintptr_t)(b)))

#define oc_checked_sub_usize(a, b, span_id) \
    (((uintptr_t)(a) < (uintptr_t)(b)) \
        ? (oc_checked_failure( \
            OC_STATUS_INTEGER_OVERFLOW, \
            "OPENC-ARITH-RUNTIME-OVERFLOW-001", \
            "unsigned subtraction underflow", (span_id) \
        ), (uintptr_t)0) \
        : (uintptr_t)((uintptr_t)(a) - (uintptr_t)(b)))

#define oc_checked_mul_usize(a, b, span_id) \
    (((uintptr_t)(b) != 0u && \
        (uintptr_t)(a) > UINTPTR_MAX / (uintptr_t)(b)) \
        ? (oc_checked_failure( \
            OC_STATUS_INTEGER_OVERFLOW, \
            "OPENC-ARITH-RUNTIME-OVERFLOW-001", \
            "unsigned multiplication overflow", (span_id) \
        ), (uintptr_t)0) \
        : (uintptr_t)((uintptr_t)(a) * (uintptr_t)(b)))

#define oc_checked_div_usize(a, b, span_id) \
    (((uintptr_t)(b) == 0u) \
        ? (oc_checked_failure( \
            OC_STATUS_DIVISION_BY_ZERO, \
            "OPENC-ARITH-DIVZERO-001", \
            "division by zero", (span_id) \
        ), (uintptr_t)0) \
        : (uintptr_t)((uintptr_t)(a) / (uintptr_t)(b)))

#define oc_checked_rem_usize(a, b, span_id) \
    (((uintptr_t)(b) == 0u) \
        ? (oc_checked_failure( \
            OC_STATUS_DIVISION_BY_ZERO, \
            "OPENC-ARITH-DIVZERO-001", \
            "remainder by zero", (span_id) \
        ), (uintptr_t)0) \
        : (uintptr_t)((uintptr_t)(a) % (uintptr_t)(b)))

#define oc_checked_shl_usize(a, b, span_id) \
    (((uintptr_t)(b) >= (uintptr_t)(sizeof(uintptr_t) * CHAR_BIT) || \
        (uintptr_t)(a) > (UINTPTR_MAX >> (unsigned)(b))) \
        ? (oc_checked_failure( \
            ((uintptr_t)(b) >= (uintptr_t)(sizeof(uintptr_t) * CHAR_BIT)) \
                ? OC_STATUS_INVALID_SHIFT : OC_STATUS_INTEGER_OVERFLOW, \
            ((uintptr_t)(b) >= (uintptr_t)(sizeof(uintptr_t) * CHAR_BIT)) \
                ? "OPENC-ARITH-SHIFT-RANGE-001" \
                : "OPENC-ARITH-RUNTIME-OVERFLOW-001", \
            ((uintptr_t)(b) >= (uintptr_t)(sizeof(uintptr_t) * CHAR_BIT)) \
                ? "shift count outside type width" \
                : "left shift overflow", (span_id) \
        ), (uintptr_t)0) \
        : (uintptr_t)((uintptr_t)(a) << (unsigned)(b)))

#define oc_checked_shr_usize(a, b, span_id) \
    (((uintptr_t)(b) >= (uintptr_t)(sizeof(uintptr_t) * CHAR_BIT)) \
        ? (oc_checked_failure( \
            OC_STATUS_INVALID_SHIFT, \
            "OPENC-ARITH-SHIFT-RANGE-001", \
            "shift count outside type width", (span_id) \
        ), (uintptr_t)0) \
        : (uintptr_t)((uintptr_t)(a) >> (unsigned)(b)))

#ifdef __cplusplus
}
#endif

#endif
