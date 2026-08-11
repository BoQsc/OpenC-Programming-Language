import system.file;
import system.io;
import system.memory;
import system.process;
import system.text;

struct CParallelChunk {
    IrContext base;
    DBuffer output;
    BuildTimings timings;
    usize first;
    usize end;
    i32 result;
}

struct CParallelState {
    CParallelChunk chunk_one;
    CParallelChunk chunk_two;
    CParallelChunk chunk_three;
    CParallelChunk chunk_four;
    CParallelChunk chunk_five;
    CParallelChunk chunk_six;
    CParallelChunk chunk_seven;
    CParallelChunk chunk_eight;
    usize entry_module;
    usize frozen_type_count;
}

unsafe i32 c_parallel_jobs(
    ref CParallelState state,
    usize worker_count,
    ptr byte callback
) {
    return 3;
}

unsafe usize c_project_source_count(ref IrContext base) {
    usize source_count = 0;
    usize module_index = 0;
    while module_index < base.modules.length {
        usize source_end = read_record_field(
            base.module_data, module_index, 2
        ) + read_record_field(base.module_data, module_index, 3);
        if source_end > source_count { source_count = source_end; }
        module_index = module_index + 1;
    }
    return source_count;
}

unsafe usize c_source_module(
    ref IrContext base,
    usize source_record
) {
    usize module_index = 0;
    while module_index < base.modules.length {
        usize source_first = read_record_field(
            base.module_data, module_index, 2
        );
        usize source_count = read_record_field(
            base.module_data, module_index, 3
        );
        if source_record >= source_first &&
            source_record - source_first < source_count {
            return module_index;
        }
        module_index = module_index + 1;
    }
    return base.modules.length;
}

unsafe bool c_parallel_partitions(
    ref IrContext base,
    usize source_bytes,
    out usize cut_one,
    out usize cut_two,
    out usize cut_three,
    out usize cut_four,
    out usize cut_five,
    out usize cut_six,
    out usize cut_seven,
    out usize source_count
) {
    source_count = c_project_source_count(base);
    cut_one = source_count;
    cut_two = source_count;
    cut_three = source_count;
    cut_four = source_count;
    cut_five = source_count;
    cut_six = source_count;
    cut_seven = source_count;
    usize accumulated = 0;
    usize source_record = 0;
    usize requested_cut = 1;
    while source_record < source_count {
        text source;
        status loaded = project_read_source_record(
            base.project_source, base.project_root, base.source_data,
            source_record, out source
        );
        if !loaded.ok { return false; }
        accumulated = accumulated + text.byte_length(source);
        if requested_cut <= 7 && accumulated >=
            (source_bytes / 8) * requested_cut {
            if requested_cut == 1 { cut_one = source_record + 1; }
            else if requested_cut == 2 { cut_two = source_record + 1; }
            else if requested_cut == 3 { cut_three = source_record + 1; }
            else if requested_cut == 4 { cut_four = source_record + 1; }
            else if requested_cut == 5 { cut_five = source_record + 1; }
            else if requested_cut == 6 { cut_six = source_record + 1; }
            else { cut_seven = source_record + 1; }
            requested_cut = requested_cut + 1;
        }
        source_record = source_record + 1;
    }
    return cut_one != 0 && cut_one < cut_two &&
        cut_two < cut_three && cut_three < cut_four &&
        cut_four < cut_five && cut_five < cut_six &&
        cut_six < cut_seven && cut_seven < source_count;
}

unsafe i32 c_emit_source_range(
    ref IrContext base,
    ref DBuffer output,
    usize source_first,
    usize source_end,
    usize entry_module,
    ref BuildTimings timings
) {
    usize source_record = source_first;
    while source_record < source_end {
        usize module_index = c_source_module(base, source_record);
        if module_index >= base.modules.length || !c_emit_source_record(
                base, output, module_index, source_record,
                entry_module, timings
            ) {
            return 1;
        }
        source_record = source_record + 1;
    }
    return 0;
}

unsafe i32 c_emit_parallel_chunk(
    ref CParallelChunk chunk,
    usize entry_module,
    usize frozen_type_count
) {
    i32 result = c_emit_source_range(
        chunk.base, chunk.output, chunk.first, chunk.end,
        entry_module, chunk.timings
    );
    if chunk.base.types.length != frozen_type_count { result = 2; }
    chunk.result = result;
    return result;
}

unsafe i32 c_emit_parallel_worker(
    ref CParallelState state,
    usize worker
) {
    if worker == 0 { return c_emit_parallel_chunk(
        state.chunk_one, state.entry_module, state.frozen_type_count
    ); }
    if worker == 1 { return c_emit_parallel_chunk(
        state.chunk_two, state.entry_module, state.frozen_type_count
    ); }
    if worker == 2 { return c_emit_parallel_chunk(
        state.chunk_three, state.entry_module, state.frozen_type_count
    ); }
    if worker == 3 { return c_emit_parallel_chunk(
        state.chunk_four, state.entry_module, state.frozen_type_count
    ); }
    if worker == 4 { return c_emit_parallel_chunk(
        state.chunk_five, state.entry_module, state.frozen_type_count
    ); }
    if worker == 5 { return c_emit_parallel_chunk(
        state.chunk_six, state.entry_module, state.frozen_type_count
    ); }
    if worker == 6 { return c_emit_parallel_chunk(
        state.chunk_seven, state.entry_module, state.frozen_type_count
    ); }
    if worker == 7 { return c_emit_parallel_chunk(
        state.chunk_eight, state.entry_module, state.frozen_type_count
    ); }
    return 1;
}
