import system.io;
import system.memory;
import system.process;
import system.text;

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
    worker.suppress_acceptance_diagnostics =
        base.suppress_acceptance_diagnostics;
    worker.profile_type_queries_enabled =
        base.profile_type_queries_enabled;
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
        elapsed_ms = 0,
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
    chunk.base.suppress_acceptance_diagnostics = true;
    chunk.timings.emission_mode = 2;
    chunk.result = -1;
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

unsafe CParallelChunk c_native_empty_chunk(
    ref IrContext base,
    usize source_count
) {
    CParallelChunk chunk = c_parallel_chunk(base, source_count,
        source_count, 1);
    chunk.timings.emission_mode = 2;
    chunk.result = 0;
    return chunk;
}

unsafe CNativeChunkState c_native_chunk_state_create(
    ref IrContext base,
    usize source_count,
    usize chunk_capacity,
    usize entry_module,
    ptr byte validation_source_ms,
    ptr byte parsed_source_cache,
    usize worker_count
) {
    if worker_count == 2 {
        usize half = source_count / 2;
        return CNativeChunkState{
            chunk_one = c_native_source_chunk(
                base, 0, half,
                c_native_chunk_output_capacity(base, 0, half, chunk_capacity)
            ),
            chunk_two = c_native_source_chunk(
                base, half, source_count,
                c_native_chunk_output_capacity(base, half, source_count,
                    chunk_capacity)
            ),
            chunk_three = c_native_empty_chunk(base, source_count),
            chunk_four = c_native_empty_chunk(base, source_count),
            entry_module = entry_module,
            frozen_type_count = base.types.length,
            validation_source_ms = ir_pointer_alias(validation_source_ms),
            parsed_source_cache = ir_pointer_alias(parsed_source_cache)
        };
    }
    usize cut_one = source_count / 4;
    usize cut_two = source_count / 2;
    usize cut_three = source_count * 3 / 4;
    return CNativeChunkState{
        chunk_one = c_native_source_chunk(
            base, 0, cut_one,
            c_native_chunk_output_capacity(base, 0, cut_one, chunk_capacity)
        ),
        chunk_two = c_native_source_chunk(
            base, cut_one, cut_two,
            c_native_chunk_output_capacity(base, cut_one, cut_two, chunk_capacity)
        ),
        chunk_three = c_native_source_chunk(
            base, cut_two, cut_three,
            c_native_chunk_output_capacity(base, cut_two, cut_three, chunk_capacity)
        ),
        chunk_four = c_native_source_chunk(
            base, cut_three, source_count,
            c_native_chunk_output_capacity(base, cut_three, source_count,
                chunk_capacity)
        ),
        entry_module = entry_module,
        frozen_type_count = base.types.length,
        validation_source_ms = ir_pointer_alias(validation_source_ms),
        parsed_source_cache = ir_pointer_alias(parsed_source_cache)
    };
}

unsafe usize c_native_chunk_output_capacity(
    ref IrContext base,
    usize first,
    usize end,
    usize ceiling
) {
    // The old proof gave every chunk the entire-project 8x output budget.
    // That committed four mostly empty buffers. Keep a 12x per-range budget
    // plus 128 KiB slack, never exceeding the established global ceiling.
    if ceiling <= 131072 { return ceiling; }
    usize limit = (ceiling - 131072) / 12;
    usize source_bytes = 0;
    usize source_record = first;
    while source_record < end {
        text source;
        status loaded = project_read_source_record(
            base.project_source, base.project_root, base.source_data,
            source_record, out source
        );
        if !loaded.ok { return ceiling; }
        usize length = text.byte_length(source);
        if length > limit - source_bytes { return ceiling; }
        source_bytes = source_bytes + length;
        source_record = source_record + 1;
    }
    return source_bytes * 12 + 131072;
}

unsafe i32 c_native_chunk_run(
    ref CParallelChunk chunk,
    ref CNativeChunkState state
) {
    usize started = process.monotonic_milliseconds();
    i32 result = c_emit_source_range_validating(
        chunk.base, chunk.output, chunk.first, chunk.end,
        state.entry_module, chunk.timings,
        state.validation_source_ms, state.parsed_source_cache
    );
    if chunk.base.types.length != state.frozen_type_count { result = 2; }
    if !chunk.output.ok { result = 3; }
    chunk.elapsed_ms = process.monotonic_milliseconds() - started;
    chunk.result = result;
    return result;
}

unsafe void c_record_native_critical_chunk(
    ref BuildTimings timings,
    ref CParallelChunk chunk
) {
    if chunk.elapsed_ms <= timings.native_critical_chunk_ms { return; }
    timings.native_critical_chunk_ms = chunk.elapsed_ms;
    timings.native_critical_chunk_first = chunk.first;
    timings.native_critical_chunk_end = chunk.end;
    timings.native_critical_lex_parse_ms = chunk.timings.lex_parse_ms;
    timings.native_critical_index_ms = chunk.timings.index_ms;
    timings.native_critical_acceptance_ms =
        chunk.timings.validation_acceptance_ms;
    timings.native_critical_expression_ms =
        chunk.timings.validation_acceptance_expressions_ms;
    timings.native_critical_assignment_ms =
        chunk.timings.validation_acceptance_assignments_ms;
    timings.native_critical_calls_ms =
        chunk.timings.validation_acceptance_calls_ms;
    timings.native_critical_ir_lower_ms = chunk.timings.ir_lower_ms;
    timings.native_critical_emit_ms = chunk.timings.c_emit_ms;
    timings.native_critical_type_queries =
        chunk.timings.validation_type_queries;
    timings.native_critical_type_cache_hits =
        chunk.timings.validation_type_cache_hits;
    timings.native_critical_type_uncached =
        chunk.timings.validation_type_uncached;
    timings.native_critical_type_failures =
        chunk.timings.validation_type_failures;
    timings.native_critical_assignment_type_queries =
        chunk.timings.validation_assignment_type_queries;
    timings.native_critical_assignment_type_cache_hits =
        chunk.timings.validation_assignment_type_cache_hits;
    timings.native_critical_assignment_type_uncached =
        chunk.timings.validation_assignment_type_uncached;
}

unsafe u32 c_native_chunk_thread_entry(ref CNativeChunkState state) {
    return cast(u32, c_native_chunk_run(state.chunk_one, state));
}

unsafe u32 c_native_chunk_thread_entry_two(ref CNativeChunkState state) {
    return cast(u32, c_native_chunk_run(state.chunk_two, state));
}

unsafe u32 c_native_chunk_thread_entry_three(ref CNativeChunkState state) {
    return cast(u32, c_native_chunk_run(state.chunk_three, state));
}

unsafe u32 c_native_chunk_thread_entry_four(ref CNativeChunkState state) {
    return cast(u32, c_native_chunk_run(state.chunk_four, state));
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
    ptr byte parsed_source_cache,
    usize worker_count
) {
    usize source_count = c_project_source_count(base);
    if worker_count != 2 && worker_count != 4 { return false; }
    if source_count < worker_count { return false; }
    if output.ok && output.capacity > output.length + 65536 {
        DBuffer header = d_buffer_create(output.length + 65536);
        d_put(header, d_buffer_text(output));
        d_buffer_destroy(output);
        output = header;
    }
    CNativeChunkState state = c_native_chunk_state_create(
        base, source_count, output_capacity + 65536,
        entry_module, validation_source_ms, parsed_source_cache,
        worker_count
    );
    usize workers_started = process.monotonic_milliseconds();
    i32 launch_result = 3;
    if worker_count == 2 {
        launch_result = c_native_parallel_jobs_two(&state);
    } else {
        launch_result = c_native_parallel_jobs(&state);
    }
    // A failed or unavailable launch returns only after joining the threads
    // already started; run precisely the chunks still marked unstarted.
    if state.chunk_one.result == -1 {
        c_native_chunk_run(state.chunk_one, state);
    }
    if state.chunk_two.result == -1 {
        c_native_chunk_run(state.chunk_two, state);
    }
    if state.chunk_three.result == -1 {
        c_native_chunk_run(state.chunk_three, state);
    }
    if state.chunk_four.result == -1 {
        c_native_chunk_run(state.chunk_four, state);
    }
    timings.native_workers_wall_ms =
        process.monotonic_milliseconds() - workers_started;
    timings.native_parallel_launch_completed = launch_result == 0;
    timings.native_chunk_one_wall_ms = state.chunk_one.elapsed_ms;
    timings.native_chunk_two_wall_ms = state.chunk_two.elapsed_ms;
    timings.native_chunk_three_wall_ms = state.chunk_three.elapsed_ms;
    timings.native_chunk_four_wall_ms = state.chunk_four.elapsed_ms;
    c_record_native_critical_chunk(timings, state.chunk_one);
    c_record_native_critical_chunk(timings, state.chunk_two);
    c_record_native_critical_chunk(timings, state.chunk_three);
    c_record_native_critical_chunk(timings, state.chunk_four);
    bool passed = (launch_result == 0 || launch_result == 3) &&
        state.chunk_one.result == 0 && state.chunk_two.result == 0 &&
        state.chunk_three.result == 0 && state.chunk_four.result == 0;
    bool has_errors = state.chunk_one.timings.validation_acceptance_errors != 0 ||
        state.chunk_two.timings.validation_acceptance_errors != 0 ||
        state.chunk_three.timings.validation_acceptance_errors != 0 ||
        state.chunk_four.timings.validation_acceptance_errors != 0;
    if passed && has_errors {
        // Speculative worker bytes are never merged after a deferred-rule
        // failure or incomplete coverage. Release all worker arenas first,
        // then replay the complete source set on the clean serial context.
        // Invalid input retains the legacy source-ordered diagnostics; a
        // conservative coverage miss instead produces a valid legacy image.
        c_merge_worker_timings(timings, state.chunk_one.timings);
        c_merge_worker_timings(timings, state.chunk_two.timings);
        c_merge_worker_timings(timings, state.chunk_three.timings);
        c_merge_worker_timings(timings, state.chunk_four.timings);
        c_native_chunk_state_destroy(state);
        DBuffer replay_output = d_buffer_create(output_capacity + 65536);
        d_put(replay_output, d_buffer_text(output));
        BuildTimings replay_timings = build_timings_empty();
        replay_timings.emission_mode = 2;
        i32 replay_result = c_emit_source_range_validating(
            base, replay_output, 0, source_count, entry_module,
            replay_timings, null, parsed_source_cache
        );
        d_buffer_destroy(output);
        output = replay_output;
        c_merge_worker_timings(timings, replay_timings);
        timings.validation_acceptance_errors =
            replay_timings.validation_acceptance_errors;
        timings.scalar_fast_sources = 0;
        return replay_result == 0 && output.ok;
    }
    if passed {
        usize merge_started = process.monotonic_milliseconds();
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
        timings.native_merge_ms =
            process.monotonic_milliseconds() - merge_started;
        passed = output.ok;
    }
    if !passed {
        io.print("OPENC-NATIVE-CHUNK-FAILED launch=");
        io.print(launch_result);
        io.print(" results=");
        io.print(state.chunk_one.result); io.print(",");
        io.print(state.chunk_two.result); io.print(",");
        io.print(state.chunk_three.result); io.print(",");
        io.print(state.chunk_four.result);
        io.print(" type_lengths=");
        io.print(state.chunk_one.base.types.length); io.print(",");
        io.print(state.chunk_two.base.types.length); io.print(",");
        io.print(state.frozen_type_count);
        io.print(" output_ok=");
        io.print(state.chunk_one.output.ok); io.print(",");
        io.print(state.chunk_two.output.ok);
        io.println("");
    }
    c_native_chunk_state_destroy(state);
    return passed;
}
