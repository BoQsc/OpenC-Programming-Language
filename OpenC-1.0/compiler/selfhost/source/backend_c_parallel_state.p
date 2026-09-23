import system.io;
import system.memory;

unsafe IrContext c_parallel_base(ref IrContext base) {
    IrContext worker = backend_base_context(
        base.project_source,
        base.project_root,
        base.module_data,
        base.modules,
        base.source_data,
        base.type_data,
        base.types,
        base.symbol_data,
        base.detail_data,
        base.symbols,
        base.next_value
    );
    worker.function_bucket_heads = base.function_bucket_heads;
    worker.function_bucket_capacity = base.function_bucket_capacity;
    worker.function_bucket_next = base.function_bucket_next;
    worker.function_parameter_first = base.function_parameter_first;
    worker.function_parameter_count = base.function_parameter_count;
    worker.parameter_next = base.parameter_next;
    worker.function_local_range_first = base.function_local_range_first;
    worker.function_local_range_end = base.function_local_range_end;
    worker.type_aggregate_symbols = base.type_aggregate_symbols;
    worker.aggregate_field_first = base.aggregate_field_first;
    worker.field_next = base.field_next;
    worker.enum_item_value = base.enum_item_value;
    worker.symbol_export_cache = base.symbol_export_cache;
    worker.native_layout_size_cache = base.native_layout_size_cache;
    worker.native_layout_alignment_cache = base.native_layout_alignment_cache;
    worker.native_layout_state_cache = base.native_layout_state_cache;
    return worker;
}

unsafe CParallelChunk c_parallel_chunk(
    ref IrContext base,
    usize first,
    usize end,
    usize capacity
) {
    return CParallelChunk{
        base = c_parallel_base(base),
        output = d_buffer_create(capacity),
        timings = build_timings_empty(),
        owned_type_data = null,
        owned_export_cache = null,
        owned_layout_sizes = null,
        owned_layout_alignments = null,
        owned_layout_states = null,
        first = first,
        end = end,
        result = 1
    };
}

unsafe bool c_parallel_chunk_passed(ref CParallelChunk chunk) {
    return chunk.result == 0 && chunk.output.ok;
}

unsafe void c_parallel_chunk_append(
    ref DBuffer output,
    ref BuildTimings timings,
    ref CParallelChunk chunk
) {
    d_put(output, d_buffer_text(chunk.output));
    c_merge_worker_timings(timings, chunk.timings);
}

unsafe void c_parallel_chunk_destroy(ref CParallelChunk chunk) {
    d_buffer_destroy(chunk.output);
    if chunk.owned_layout_states != null {
        memory.free(chunk.owned_layout_states);
    }
    if chunk.owned_layout_alignments != null {
        memory.free(chunk.owned_layout_alignments);
    }
    if chunk.owned_layout_sizes != null {
        memory.free(chunk.owned_layout_sizes);
    }
    if chunk.owned_export_cache != null {
        memory.free(chunk.owned_export_cache);
    }
    if chunk.owned_type_data != null {
        memory.free(chunk.owned_type_data);
    }
}

unsafe CParallelState c_parallel_state_create(
    ref IrContext base,
    usize cut_one,
    usize cut_two,
    usize cut_three,
    usize cut_four,
    usize cut_five,
    usize cut_six,
    usize cut_seven,
    usize source_count,
    usize chunk_capacity,
    usize entry_module
) {
    return CParallelState{
        chunk_one = c_parallel_chunk(base, 0, cut_one, chunk_capacity),
        chunk_two = c_parallel_chunk(base, cut_one, cut_two, chunk_capacity),
        chunk_three = c_parallel_chunk(base, cut_two, cut_three, chunk_capacity),
        chunk_four = c_parallel_chunk(base, cut_three, cut_four, chunk_capacity),
        chunk_five = c_parallel_chunk(base, cut_four, cut_five, chunk_capacity),
        chunk_six = c_parallel_chunk(base, cut_five, cut_six, chunk_capacity),
        chunk_seven = c_parallel_chunk(base, cut_six, cut_seven, chunk_capacity),
        chunk_eight = c_parallel_chunk(base, cut_seven, source_count, chunk_capacity),
        entry_module = entry_module,
        frozen_type_count = base.types.length
    };
}

unsafe bool c_parallel_state_passed(
    ref CParallelState state,
    i32 parallel_result
) {
    return parallel_result == 0 &&
        c_parallel_chunk_passed(state.chunk_one) &&
        c_parallel_chunk_passed(state.chunk_two) &&
        c_parallel_chunk_passed(state.chunk_three) &&
        c_parallel_chunk_passed(state.chunk_four) &&
        c_parallel_chunk_passed(state.chunk_five) &&
        c_parallel_chunk_passed(state.chunk_six) &&
        c_parallel_chunk_passed(state.chunk_seven) &&
        c_parallel_chunk_passed(state.chunk_eight);
}

unsafe void c_parallel_state_append(
    ref DBuffer output,
    ref BuildTimings timings,
    ref CParallelState state
) {
    usize required = output.length + state.chunk_one.output.length +
        state.chunk_two.output.length + state.chunk_three.output.length +
        state.chunk_four.output.length + state.chunk_five.output.length +
        state.chunk_six.output.length + state.chunk_seven.output.length +
        state.chunk_eight.output.length + 65536;
    if output.ok && required > output.capacity {
        DBuffer combined = d_buffer_create(required);
        d_put(combined, d_buffer_text(output));
        d_buffer_destroy(output);
        output = combined;
    }
    c_parallel_chunk_append(output, timings, state.chunk_one);
    c_parallel_chunk_append(output, timings, state.chunk_two);
    c_parallel_chunk_append(output, timings, state.chunk_three);
    c_parallel_chunk_append(output, timings, state.chunk_four);
    c_parallel_chunk_append(output, timings, state.chunk_five);
    c_parallel_chunk_append(output, timings, state.chunk_six);
    c_parallel_chunk_append(output, timings, state.chunk_seven);
    c_parallel_chunk_append(output, timings, state.chunk_eight);
}

unsafe void c_parallel_state_destroy(ref CParallelState state) {
    c_parallel_chunk_destroy(state.chunk_eight);
    c_parallel_chunk_destroy(state.chunk_seven);
    c_parallel_chunk_destroy(state.chunk_six);
    c_parallel_chunk_destroy(state.chunk_five);
    c_parallel_chunk_destroy(state.chunk_four);
    c_parallel_chunk_destroy(state.chunk_three);
    c_parallel_chunk_destroy(state.chunk_two);
    c_parallel_chunk_destroy(state.chunk_one);
}

unsafe void c_parallel_state_report_failure(
    ref CParallelState state,
    i32 parallel_result
) {
    io.print("OPENC-C-BACKEND-PARALLEL-FAILED runtime=");
    io.print(parallel_result);
    io.print(" workers=");
    io.print(state.chunk_one.result); io.print(",");
    io.print(state.chunk_two.result); io.print(",");
    io.print(state.chunk_three.result); io.print(",");
    io.print(state.chunk_four.result); io.print(",");
    io.print(state.chunk_five.result); io.print(",");
    io.print(state.chunk_six.result); io.print(",");
    io.print(state.chunk_seven.result); io.print(",");
    io.println(state.chunk_eight.result);
}

unsafe bool c_emit_sources_parallel(
    ref IrContext base,
    ref DBuffer output,
    usize output_capacity,
    usize entry_module,
    ref BuildTimings timings
) {
    CParallelPartitions partitions = c_parallel_partitions(
        base, timings.source_bytes
    );
    if !partitions.valid { return false; }
    // Workers own their output buffers. Do not retain a worst-case whole-
    // project reservation while their parser/IR arenas are live. Recombine
    // with the exact measured byte count after workers have finished.
    if output.ok && output.capacity > output.length + 65536 {
        DBuffer header = d_buffer_create(output.length + 65536);
        d_put(header, d_buffer_text(output));
        d_buffer_destroy(output);
        output = header;
    }
    usize chunk_capacity = timings.source_bytes / 2 + 524288;
    CParallelState state = c_parallel_state_create(
        base, partitions.cut_one, partitions.cut_two,
        partitions.cut_three, partitions.cut_four,
        partitions.cut_five, partitions.cut_six,
        partitions.cut_seven, partitions.source_count,
        chunk_capacity, entry_module
    );
    i32 parallel_result = c_parallel_jobs(state, 8, null);
    bool passed = c_parallel_state_passed(state, parallel_result);
    if passed { c_parallel_state_append(output, timings, state); }
    c_parallel_state_destroy(state);
    if !passed { c_parallel_state_report_failure(state, parallel_result); }
    return passed;
}

unsafe CParallelChunk c_native_source_chunk(
    ref IrContext base,
    usize first,
    usize end,
    usize capacity
) {
    CParallelChunk chunk = c_parallel_chunk(base, first, end, capacity);
    chunk.timings.emission_mode = 2;
    usize type_bytes = base.types.capacity * record_stride();
    chunk.owned_type_data = memory.alloc(type_bytes);
    usize type_word = 0;
    while type_word < base.types.length * 5 {
        write_usize(
            chunk.owned_type_data, type_word * size_of(usize),
            read_usize(base.type_data, type_word * size_of(usize))
        );
        type_word = type_word + 1;
    }
    chunk.base.type_data = ir_pointer_alias(chunk.owned_type_data);

    usize export_bytes = (base.symbols.length + 1) * size_of(usize);
    chunk.owned_export_cache = memory.alloc(export_bytes);
    usize symbol = 0;
    while symbol <= base.symbols.length {
        write_usize(
            chunk.owned_export_cache, symbol * size_of(usize), 0
        );
        symbol = symbol + 1;
    }
    chunk.base.symbol_export_cache = ir_pointer_alias(
        chunk.owned_export_cache
    );

    usize layout_bytes = (base.types.capacity + 1) * size_of(usize);
    chunk.owned_layout_sizes = memory.alloc(layout_bytes);
    chunk.owned_layout_alignments = memory.alloc(layout_bytes);
    chunk.owned_layout_states = memory.alloc(layout_bytes);
    usize type_id = 0;
    while type_id <= base.types.capacity {
        write_usize(
            chunk.owned_layout_states, type_id * size_of(usize), 0
        );
        type_id = type_id + 1;
    }
    chunk.base.native_layout_size_cache = ir_pointer_alias(
        chunk.owned_layout_sizes
    );
    chunk.base.native_layout_alignment_cache = ir_pointer_alias(
        chunk.owned_layout_alignments
    );
    chunk.base.native_layout_state_cache = ir_pointer_alias(
        chunk.owned_layout_states
    );
    return chunk;
}

unsafe CNativeChunkState c_native_chunk_state_create(
    ref IrContext base,
    usize source_count,
    usize chunk_capacity,
    usize entry_module,
    ptr byte validation_source_ms,
    ptr byte parsed_source_cache
) {
    usize cut_one = source_count / 4;
    usize cut_two = source_count / 2;
    usize cut_three = source_count * 3 / 4;
    return CNativeChunkState{
        chunk_one = c_native_source_chunk(
            base, 0, cut_one, chunk_capacity
        ),
        chunk_two = c_native_source_chunk(
            base, cut_one, cut_two, chunk_capacity
        ),
        chunk_three = c_native_source_chunk(
            base, cut_two, cut_three, chunk_capacity
        ),
        chunk_four = c_native_source_chunk(
            base, cut_three, source_count, chunk_capacity
        ),
        entry_module = entry_module,
        frozen_type_count = base.types.length,
        validation_source_ms = ir_pointer_alias(validation_source_ms),
        parsed_source_cache = ir_pointer_alias(parsed_source_cache)
    };
}

unsafe i32 c_native_chunk_run(
    ref CParallelChunk chunk,
    ref CNativeChunkState state
) {
    i32 result = c_emit_source_range_validating(
        chunk.base, chunk.output, chunk.first, chunk.end,
        state.entry_module, chunk.timings,
        state.validation_source_ms, state.parsed_source_cache
    );
    if chunk.base.types.length != state.frozen_type_count { result = 2; }
    if !chunk.output.ok { result = 3; }
    chunk.result = result;
    return result;
}

unsafe void c_native_chunk_state_destroy(ref CNativeChunkState state) {
    c_parallel_chunk_destroy(state.chunk_four);
    c_parallel_chunk_destroy(state.chunk_three);
    c_parallel_chunk_destroy(state.chunk_two);
    c_parallel_chunk_destroy(state.chunk_one);
}

unsafe bool c_emit_native_sources_chunked(
    ref IrContext base,
    ref DBuffer output,
    usize output_capacity,
    usize entry_module,
    ref BuildTimings timings,
    ptr byte validation_source_ms,
    ptr byte parsed_source_cache
) {
    usize source_count = c_project_source_count(base);
    if source_count < 4 { return false; }
    if output.ok && output.capacity > output.length + 65536 {
        DBuffer header = d_buffer_create(output.length + 65536);
        d_put(header, d_buffer_text(output));
        d_buffer_destroy(output);
        output = header;
    }
    CNativeChunkState state = c_native_chunk_state_create(
        base, source_count, output_capacity + 65536,
        entry_module, validation_source_ms, parsed_source_cache
    );
    bool passed = c_native_chunk_run(state.chunk_one, state) == 0;
    if passed { passed = c_native_chunk_run(state.chunk_two, state) == 0; }
    if passed { passed = c_native_chunk_run(state.chunk_three, state) == 0; }
    if passed { passed = c_native_chunk_run(state.chunk_four, state) == 0; }
    if passed {
        usize required = output.length + state.chunk_one.output.length +
            state.chunk_two.output.length +
            state.chunk_three.output.length +
            state.chunk_four.output.length + 65536;
        DBuffer combined = d_buffer_create(required);
        d_put(combined, d_buffer_text(output));
        d_buffer_destroy(output);
        output = combined;
        c_parallel_chunk_append(output, timings, state.chunk_one);
        c_parallel_chunk_append(output, timings, state.chunk_two);
        c_parallel_chunk_append(output, timings, state.chunk_three);
        c_parallel_chunk_append(output, timings, state.chunk_four);
        passed = output.ok;
    }
    c_native_chunk_state_destroy(state);
    return passed;
}
