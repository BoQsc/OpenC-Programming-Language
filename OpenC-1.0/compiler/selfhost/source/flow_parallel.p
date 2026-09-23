import system.io;
import system.memory;
import system.process;

// Native artifact builds can validate independent source records on private
// error buffers. The ordinary build/check paths keep their serial behavior.
struct FlowParallelChunk {
    usize first;
    usize end;
    ptr byte error_data;
    PackedBuffer errors;
    BuildTimings timings;
    i32 result;
}

struct FlowParallelState {
    FlowParallelChunk chunk_one;
    FlowParallelChunk chunk_two;
    FlowParallelChunk chunk_three;
    FlowParallelChunk chunk_four;
    text project_source;
    text project_root;
    ptr byte module_data;
    PackedBuffer modules;
    ptr byte source_data;
    ptr byte type_data;
    ptr byte symbol_data;
    ptr byte detail_data;
    PackedBuffer symbols;
    bool project_has_pointer_symbol;
    bool project_has_unsafe_function;
    ptr byte parsed_source_cache;
    ptr byte validation_source_ms;
}

unsafe FlowParallelChunk flow_parallel_chunk(
    usize first, usize end, usize error_capacity
) {
    usize bytes = error_capacity * record_stride();
    ptr byte private_errors = memory.alloc(bytes);
    BuildTimings initial_timings = build_timings_empty();
    return FlowParallelChunk{
        first = first,
        end = end,
        error_data = ir_pointer_alias(private_errors),
        errors = PackedBuffer{ length = 0, capacity = error_capacity },
        timings = initial_timings,
        result = -1
    };
}

unsafe FlowParallelChunk flow_parallel_empty_chunk(usize source_count) {
    return FlowParallelChunk{
        first = source_count,
        end = source_count,
        error_data = null,
        errors = PackedBuffer{ length = 0, capacity = 0 },
        timings = build_timings_empty(),
        result = 0
    };
}

unsafe i32 flow_parallel_chunk_run(
    ref FlowParallelChunk chunk, ref FlowParallelState state
) {
    usize source_record = chunk.first;
    while source_record < chunk.end {
        usize module_index = semantic_source_module(
            state.module_data, state.modules, source_record
        );
        usize source_started = process.monotonic_milliseconds();
        flow_validate_source(
            state.project_source, state.project_root,
            state.module_data, state.modules, state.source_data,
            module_index, source_record,
            state.type_data, state.symbol_data, state.detail_data,
            state.symbols, state.project_has_pointer_symbol,
            state.project_has_unsafe_function,
            state.parsed_source_cache,
            chunk.error_data, chunk.errors, chunk.timings
        );
        write_usize(
            state.validation_source_ms,
            source_record * size_of(usize),
            process.monotonic_milliseconds() - source_started
        );
        usize live = compiler_live_allocation_bytes();
        if live > chunk.timings.validation_peak_live_bytes {
            chunk.timings.validation_peak_live_bytes = live;
            chunk.timings.validation_peak_source_record = source_record;
        }
        if live > 402653184 {
            chunk.result = 2;
            return 2;
        }
        source_record = source_record + 1;
    }
    chunk.result = 0;
    return 0;
}

unsafe u32 flow_parallel_thread_entry_one(ref FlowParallelState state) {
    return cast(u32, flow_parallel_chunk_run(state.chunk_one, state));
}
unsafe u32 flow_parallel_thread_entry_two(ref FlowParallelState state) {
    return cast(u32, flow_parallel_chunk_run(state.chunk_two, state));
}
unsafe u32 flow_parallel_thread_entry_three(ref FlowParallelState state) {
    return cast(u32, flow_parallel_chunk_run(state.chunk_three, state));
}
unsafe u32 flow_parallel_thread_entry_four(ref FlowParallelState state) {
    return cast(u32, flow_parallel_chunk_run(state.chunk_four, state));
}

unsafe i32 flow_parallel_jobs(ptr FlowParallelState state) { return 3; }
unsafe i32 flow_parallel_jobs_two(ptr FlowParallelState state) { return 3; }

unsafe void flow_parallel_merge_timings(
    ref BuildTimings target, ref BuildTimings worker
) {
    target.validation_flow_parse_ms = target.validation_flow_parse_ms +
        worker.validation_flow_parse_ms;
    target.validation_flow_initialization_ms =
        target.validation_flow_initialization_ms +
        worker.validation_flow_initialization_ms;
    target.validation_flow_status_out_ms =
        target.validation_flow_status_out_ms +
        worker.validation_flow_status_out_ms;
    target.validation_flow_ownership_ms =
        target.validation_flow_ownership_ms +
        worker.validation_flow_ownership_ms;
    target.validation_flow_borrows_ms = target.validation_flow_borrows_ms +
        worker.validation_flow_borrows_ms;
    target.validation_flow_cleanup_ms = target.validation_flow_cleanup_ms +
        worker.validation_flow_cleanup_ms;
    target.validation_flow_pointer_facts_ms =
        target.validation_flow_pointer_facts_ms +
        worker.validation_flow_pointer_facts_ms;
    target.validation_flow_unsafe_function_ms =
        target.validation_flow_unsafe_function_ms +
        worker.validation_flow_unsafe_function_ms;
    target.validation_flow_pointer_arithmetic_ms =
        target.validation_flow_pointer_arithmetic_ms +
        worker.validation_flow_pointer_arithmetic_ms;
    target.validation_flow_scope_actions_ms =
        target.validation_flow_scope_actions_ms +
        worker.validation_flow_scope_actions_ms;
    target.validation_flow_unsafe_calls_ms =
        target.validation_flow_unsafe_calls_ms +
        worker.validation_flow_unsafe_calls_ms;
    if worker.validation_peak_live_bytes > target.validation_peak_live_bytes {
        target.validation_peak_live_bytes = worker.validation_peak_live_bytes;
        target.validation_peak_source_record =
            worker.validation_peak_source_record;
    }
}

unsafe bool flow_parallel_append_chunk(
    ptr byte error_data, ref PackedBuffer errors,
    ref BuildTimings timings, ref FlowParallelChunk chunk
) {
    if errors.length + chunk.errors.length > errors.capacity { return false; }
    usize record = 0;
    while record < chunk.errors.length {
        usize field = 0;
        while field < 5 {
            write_record_field(
                error_data, errors.length + record, field,
                read_record_field(chunk.error_data, record, field)
            );
            field = field + 1;
        }
        record = record + 1;
    }
    errors.length = errors.length + chunk.errors.length;
    flow_parallel_merge_timings(timings, chunk.timings);
    return true;
}

unsafe void flow_parallel_destroy(ref FlowParallelState state) {
    if state.chunk_four.error_data != null {
        memory.free(state.chunk_four.error_data);
    }
    if state.chunk_three.error_data != null {
        memory.free(state.chunk_three.error_data);
    }
    memory.free(state.chunk_two.error_data);
    memory.free(state.chunk_one.error_data);
}

unsafe bool flow_validate_project_parallel(
    text project_source, text project_root,
    ptr byte module_data, ref PackedBuffer modules,
    ptr byte source_data, ref PackedBuffer sources,
    ptr byte type_data, ptr byte symbol_data, ptr byte detail_data,
    ref PackedBuffer symbols,
    bool project_has_pointer_symbol,
    bool project_has_unsafe_function,
    ptr byte parsed_source_cache,
    ptr byte validation_source_ms,
    ptr byte error_data, ref PackedBuffer errors,
    ref BuildTimings timings, usize worker_count
) {
    usize source_count = sources.length;
    usize error_capacity = errors.capacity;
    usize cut_one = source_count / worker_count;
    usize cut_two = source_count * 2 / worker_count;
    usize cut_three = source_count * 3 / worker_count;
    usize second_end = cut_two;
    FlowParallelChunk third = flow_parallel_empty_chunk(source_count);
    FlowParallelChunk fourth = flow_parallel_empty_chunk(source_count);
    if worker_count == 2 {
        second_end = source_count;
    } else {
        third = flow_parallel_chunk(cut_two, cut_three, error_capacity);
        fourth = flow_parallel_chunk(cut_three, source_count, error_capacity);
    }
    FlowParallelChunk first = flow_parallel_chunk(
        0, cut_one, error_capacity
    );
    FlowParallelChunk second = flow_parallel_chunk(
        cut_one, second_end, error_capacity
    );
    FlowParallelState state = FlowParallelState{
        chunk_one = first,
        chunk_two = second,
        chunk_three = third,
        chunk_four = fourth,
        project_source = project_source,
        project_root = project_root,
        module_data = ir_pointer_alias(module_data),
        modules = modules,
        source_data = ir_pointer_alias(source_data),
        type_data = ir_pointer_alias(type_data),
        symbol_data = ir_pointer_alias(symbol_data),
        detail_data = ir_pointer_alias(detail_data),
        symbols = symbols,
        project_has_pointer_symbol = project_has_pointer_symbol,
        project_has_unsafe_function = project_has_unsafe_function,
        parsed_source_cache = ir_pointer_alias(parsed_source_cache),
        validation_source_ms = ir_pointer_alias(validation_source_ms)
    };
    // Nested PackedBuffer initializers are not copied correctly by the
    // current native aggregate writer; assign their words explicitly.
    state.modules.length = modules.length;
    state.modules.capacity = modules.capacity;
    state.symbols.length = symbols.length;
    state.symbols.capacity = symbols.capacity;
    i32 launch_result = 3;
    if worker_count == 2 {
        launch_result = flow_parallel_jobs_two(&state);
    } else {
        launch_result = flow_parallel_jobs(&state);
    }
    timings.flow_threads_launched = launch_result == 0;
    if state.chunk_one.result == -1 {
        flow_parallel_chunk_run(state.chunk_one, state);
    }
    if state.chunk_two.result == -1 {
        flow_parallel_chunk_run(state.chunk_two, state);
    }
    if state.chunk_three.result == -1 {
        flow_parallel_chunk_run(state.chunk_three, state);
    }
    if state.chunk_four.result == -1 {
        flow_parallel_chunk_run(state.chunk_four, state);
    }
    bool passed = (launch_result == 0 || launch_result == 3) &&
        state.chunk_one.result == 0 && state.chunk_two.result == 0 &&
        state.chunk_three.result == 0 && state.chunk_four.result == 0;
    if passed {
        passed = flow_parallel_append_chunk(
            error_data, errors, timings, state.chunk_one
        ) && flow_parallel_append_chunk(
            error_data, errors, timings, state.chunk_two
        ) && flow_parallel_append_chunk(
            error_data, errors, timings, state.chunk_three
        ) && flow_parallel_append_chunk(
            error_data, errors, timings, state.chunk_four
        );
    }
    if !passed {
        io.error("error[OPENC-FLOW-PARALLEL]: source validation failed or exceeded memory budget\n");
    }
    flow_parallel_destroy(state);
    timings.validation_file_cache_hits = compiler_file_cache_hits();
    timings.validation_file_cache_misses = compiler_file_cache_misses();
    timings.validation_path_cache_hits = compiler_path_cache_hits();
    timings.validation_path_cache_misses = compiler_path_cache_misses();
    return passed;
}
