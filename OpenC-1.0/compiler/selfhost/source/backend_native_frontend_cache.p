import system.file;
import system.memory;
import system.process;
import system.text;

// Source contributions are replayed in the original two ordered passes.
// Exact source bytes and the incoming type table/symbol count bind every
// numeric ID. Changed contributions run the ordinary parser and resolver.
struct NativeFrontendState {
    bool enabled;
    usize source_count;
    usize predecl_count;
    DBuffer saved;
    DBuffer rows;
    DBuffer projections;
    DBuffer identity;
    DBuffer compiler_hash;
    DBuffer type_identity;
    usize hashed_types;
    usize source_bytes;
    text project_source;
    text project_root;
    ptr byte source_data;
}

NativeFrontendState native_frontend_empty() {
    DBuffer empty = DBuffer{data = null, length = 0, capacity = 0, ok = true};
    return NativeFrontendState{enabled = false, source_count = 0,
        predecl_count = 0, saved = empty, rows = empty,
        projections = empty, identity = empty, compiler_hash = empty,
        type_identity = empty, hashed_types = 0, source_bytes = 0,
        project_source = "", project_root = "", source_data = null};
}

unsafe void native_frontend_destroy(ref NativeFrontendState state) {
    if state.saved.data != null { d_buffer_destroy(state.saved); }
    if state.rows.data != null { d_buffer_destroy(state.rows); }
    if state.projections.data != null { d_buffer_destroy(state.projections); }
    if state.identity.data != null { d_buffer_destroy(state.identity); }
    if state.compiler_hash.data != null { d_buffer_destroy(state.compiler_hash); }
    if state.type_identity.data != null { d_buffer_destroy(state.type_identity); }
}

unsafe bool native_frontend_equal(ptr byte left, ptr byte right, usize length) {
    usize index = 0;
    while index < length {
        if *(left + index) != *(right + index) { return false; }
        index = index + 1;
    }
    return true;
}

unsafe bool native_frontend_hash(ptr byte data, usize length, ptr byte destination) {
    DBuffer hash = d_buffer_create(65);
    if hash.data == null { d_buffer_destroy(hash); return false; }
    // Contribution prefixes are often small. Batch work through the same
    // optional platform SHA service, retaining the exact OpenC fallback.
    module_cache_compiler_hash(data, length, hash);
    bool ok = hash.ok && hash.length == 64;
    if ok { text.copy_utf8_unchecked(destination, d_buffer_text(hash)); }
    d_buffer_destroy(hash);
    return ok;
}

unsafe bool native_frontend_type_hash(
    ref NativeFrontendState state, ptr byte type_data,
    ref PackedBuffer types, ptr byte destination
) {
    // Types are append-only during both frontend passes. A cached prefix
    // digest includes named-type spelling, not only source spans: a same-
    // length type rename must invalidate later resolution contributions.
    if state.hashed_types != types.length {
        DBuffer identity = d_buffer_create(types.length * 48 + state.source_bytes + 1);
        scope d_buffer_destroy(identity);
        if identity.data == null { return false; }
        d_put_raw(identity, type_data, types.length * record_stride());
        usize type = 19;
        while type < types.length {
            usize flags = read_record_field(type_data, type, 4);
            if read_record_field(type_data, type, 0) == 9 && (flags / 8) % 2 == 0 {
                text source;
                status loaded = project_read_source_record(state.project_source,
                    state.project_root, state.source_data,
                    read_record_field(type_data, type, 1), out source);
                if !loaded.ok { return false; }
                usize start = read_record_field(type_data, type, 2);
                usize length = read_record_field(type_data, type, 3);
                if start > text.byte_length(source) || length > text.byte_length(source) - start {
                    return false;
                }
                pe32_put_u64(identity, cast(u64, length));
                d_put_slice(identity, source, start, length);
            }
            type = type + 1;
        }
        if !identity.ok || !native_frontend_hash(identity.data, identity.length, state.type_identity.data) {
            return false;
        }
        state.type_identity.length = 64;
        state.hashed_types = types.length;
    }
    text.copy_utf8_unchecked(destination, d_buffer_text(state.type_identity));
    return true;
}

unsafe bool native_frontend_saved_valid(
    ref NativeFrontendState state, usize module_count
) {
    DBuffer bytes = state.saved;
    usize count = state.source_count;
    if bytes.length < 112 + count * 232 + 64 ||
        native_read_u32(bytes, 0) != 1179534159 ||
        native_read_u32(bytes, 4) != 1 ||
        native_read_u32(bytes, 8) != count ||
        !native_frontend_equal(bytes.data + 48, state.identity.data, 64) {
        return false;
    }
    DBuffer digest = d_buffer_create(65);
    if digest.data == null { d_buffer_destroy(digest); return false; }
    module_cache_compiler_hash(bytes.data, bytes.length - 64, digest);
    bool valid = digest.ok && digest.length == 64 &&
        native_frontend_equal(digest.data, bytes.data + bytes.length - 64, 64);
    d_buffer_destroy(digest);
    if !valid { return false; }
    usize types = native_read_u32(bytes, 12);
    usize symbols = native_read_u32(bytes, 16);
    usize predecl = native_read_u32(bytes, 20);
    usize type_offset = native_read_u32(bytes, 24);
    usize symbol_offset = native_read_u32(bytes, 28);
    usize detail_offset = native_read_u32(bytes, 32);
    usize projection_offset = native_read_u32(bytes, 36);
    usize projection_bytes = native_read_u32(bytes, 40);
    if types < 19 || types > 16384 || symbols > 16384 ||
        predecl < 19 || predecl > types || native_read_u32(bytes, 44) != 0 ||
        type_offset != 112 + count * 232 ||
        symbol_offset != type_offset + types * record_stride() ||
        detail_offset != symbol_offset + symbols * record_stride() ||
        projection_offset != detail_offset + symbols * record_stride() ||
        projection_offset > bytes.length - 64 ||
        projection_bytes != bytes.length - 64 - projection_offset { return false; }
    usize next_pre = 19;
    usize next_type = predecl;
    usize next_symbol = 0;
    usize next_projection = 0;
    usize source = 0;
    while source < count {
        usize row = 112 + source * 232;
        usize first = native_read_u32(bytes, row + 192);
        usize added = native_read_u32(bytes, row + 196);
        usize rfirst = native_read_u32(bytes, row + 200);
        usize radded = native_read_u32(bytes, row + 204);
        usize sfirst = native_read_u32(bytes, row + 208);
        usize sadded = native_read_u32(bytes, row + 212);
        usize pfirst = native_read_u32(bytes, row + 216);
        usize padded = native_read_u32(bytes, row + 220);
        usize length = native_read_u32(bytes, row + 224);
        usize syntax = native_read_u32(bytes, row + 228);
        if first != next_pre || first > predecl || added > predecl - first ||
            rfirst != next_type || rfirst > types || radded > types - rfirst ||
            sfirst != next_symbol || sfirst > symbols || sadded > symbols - sfirst ||
            pfirst != next_projection || pfirst > projection_bytes ||
            padded > projection_bytes - pfirst || length > 131072 ||
            syntax > length * 6 + 8 { return false; }
        usize symbol = sfirst;
        while symbol < sfirst + sadded {
            ptr byte data = bytes.data + symbol_offset;
            ptr byte details = bytes.data + detail_offset;
            usize kind = read_record_field(data, symbol, 0);
            usize start = read_record_field(data, symbol, 2);
            usize size = read_record_field(data, symbol, 3);
            usize span = read_record_field(details, symbol, 4);
            usize owner = read_record_field(details, symbol, 2);
            usize span_start = resolution_span_start(span);
            usize span_size = resolution_span_length(span);
            if kind < 1 || kind > 9 || read_record_field(data, symbol, 1) != source ||
                start > length || size > length - start ||
                read_record_field(data, symbol, 4) >= types ||
                read_record_field(details, symbol, 0) >= module_count ||
                read_record_field(details, symbol, 1) >= syntax ||
                owner > symbol ||
                read_record_field(details, symbol, 3) > 1 ||
                span_start > length || span_size > length - span_start { return false; }
            if owner != 0 && read_record_field(data, owner - 1, 1) != source { return false; }
            symbol = symbol + 1;
        }
        next_pre = first + added; next_type = rfirst + radded;
        next_symbol = sfirst + sadded; next_projection = pfirst + padded;
        source = source + 1;
    }
    if next_pre != predecl || next_type != types || next_symbol != symbols ||
        next_projection != projection_bytes { return false; }
    usize type = 0;
    while type < types {
        ptr byte data = bytes.data + type_offset;
        usize kind = read_record_field(data, type, 0);
        usize one = read_record_field(data, type, 1);
        usize two = read_record_field(data, type, 2);
        usize three = read_record_field(data, type, 3);
        usize flags = read_record_field(data, type, 4);
        if kind > 15 { return false; }
        if kind == 9 && (flags / 8) % 2 == 0 {
            if one >= count { return false; }
            usize length = native_read_u32(bytes, 112 + one * 232 + 224);
            if two > length || three > length - two { return false; }
        } else if kind >= 10 || (kind == 9 && (flags / 8) % 2 == 1) {
            if one >= type { return false; }
        }
        type = type + 1;
    }
    return bytes.ok;
}

unsafe NativeFrontendState native_frontend_open(
    text project, text root, text prefix, usize source_count,
    usize source_bytes, usize source_chunks, usize module_count,
    ptr byte source_data,
    ref BuildTimings timings
) {
    NativeFrontendState state = native_frontend_empty();
    if text.byte_length(prefix) == 0 || source_count < 2 || source_count > 512 ||
        source_bytes > 4194304 { return state; }
    state.source_count = source_count;
    state.source_bytes = source_bytes;
    state.project_source = project;
    state.project_root = root;
    state.source_data = source_data;
    state.rows = d_buffer_create(source_count * 232);
    state.projections = d_buffer_create(source_bytes + 1);
    state.identity = d_buffer_create(65);
    state.compiler_hash = d_buffer_create(65);
    state.type_identity = d_buffer_create(65);
    if state.rows.data == null || state.projections.data == null ||
        state.identity.data == null || state.compiler_hash.data == null ||
        state.type_identity.data == null { return state; }
    state.rows.length = source_count * 232;
    DBuffer key = d_buffer_create(text.byte_length(project) + text.byte_length(root) + 256);
    scope d_buffer_destroy(key);
    ptr byte compiler;
    usize compiler_bytes;
    status read = cli_coff_read_bounded_object(process.executable_path(), 33554432,
        out compiler, out compiler_bytes);
    if !read.ok { return state; }
    d_put(key, "openc-frontend-contributions-v2:windows-x86_64-llp64:");
    module_cache_compiler_hash(compiler, compiler_bytes, state.compiler_hash);
    d_put(key, d_buffer_text(state.compiler_hash));
    memory.free(compiler);
    d_put_usize(key, source_chunks); d_put(key, ":");
    d_put_usize(key, text.byte_length(root)); d_put(key, ":"); d_put(key, root);
    d_put(key, project);
    module_cache_compiler_hash(key.data, key.length, state.identity);
    if !key.ok || !state.identity.ok || state.identity.length != 64 { return state; }
    state.enabled = true;
    timings.frontend_cache_enabled = true;
    DBuffer path = d_buffer_create(text.byte_length(prefix) + 16);
    d_put(path, prefix); d_put(path, ".frontend");
    ptr byte data;
    usize length;
    status loaded = cli_coff_read_bounded_object(d_buffer_text(path), 8388608,
        out data, out length);
    d_buffer_destroy(path);
    if !loaded.ok { return state; }
    state.saved = DBuffer{data = data, length = length, capacity = length, ok = true};
    if !native_frontend_saved_valid(state, module_count) {
        d_buffer_destroy(state.saved);
        state.saved = DBuffer{data = null, length = 0, capacity = 0, ok = true};
    }
    return state;
}

unsafe bool native_frontend_predeclare_hit(
    ref NativeFrontendState state, usize source_record, text source,
    ptr byte type_data, ref PackedBuffer types, ref BuildTimings timings
) {
    if !state.enabled { return false; }
    usize row = source_record * 232;
    ptr byte source_representation = reinterpret(ptr byte, &source);
    ptr byte source_bytes = resolution_pointer_decode(read_usize(source_representation, 0));
    state.enabled = native_frontend_hash(
        source_bytes, text.byte_length(source), state.rows.data + row) &&
        native_frontend_type_hash(state, type_data, types, state.rows.data + row + 64);
    if !state.enabled { return false; }
    pe32_patch_u32(state.rows, row + 192, types.length);
    pe32_patch_u32(state.rows, row + 224, text.byte_length(source));
    usize old = 112 + row;
    if state.saved.length == 0 || !native_frontend_equal(state.rows.data + row,
            state.saved.data + old, 128) ||
        native_read_u32(state.saved, old + 192) != types.length { return false; }
    usize count = native_read_u32(state.saved, old + 196);
    if count > types.capacity - types.length { state.enabled = false; return false; }
    usize offset = native_read_u32(state.saved, 24) + types.length * record_stride();
    resolution_copy_records(type_data + types.length * record_stride(), state.saved.data + offset, count);
    types.length = types.length + count;
    pe32_patch_u32(state.rows, row + 196, count);
    pe32_patch_u32(state.rows, row + 228, native_read_u32(state.saved, old + 228));
    usize start = native_read_u32(state.saved, old + 216);
    usize length = native_read_u32(state.saved, old + 220);
    pe32_patch_u32(state.rows, row + 216, state.projections.length);
    pe32_patch_u32(state.rows, row + 220, length);
    native_copy_range(state.projections, state.saved,
        native_read_u32(state.saved, 36) + start, length);
    state.enabled = state.projections.ok && state.rows.ok;
    timings.frontend_predeclare_hits = timings.frontend_predeclare_hits + 1;
    return state.enabled;
}

unsafe void native_frontend_finish_predeclare(
    ref NativeFrontendState state, usize source_record, text source,
    ref PackedBuffer types, ref ResolutionParsedSource parsed
) {
    if !state.enabled { return; }
    usize row = source_record * 232;
    usize first = native_read_u32(state.rows, row + 192);
    pe32_patch_u32(state.rows, row + 196, types.length - first);
    pe32_patch_u32(state.rows, row + 228, parsed.syntax.length);
    usize start = state.projections.length;
    pe32_patch_u32(state.rows, row + 216, start);
    state.enabled = parsed.reusable && module_cache_source_projection(source, parsed, state.projections);
    pe32_patch_u32(state.rows, row + 220, state.projections.length - start);
    state.enabled = state.enabled && state.rows.ok && state.projections.ok;
}

unsafe bool native_frontend_resolution_hit(
    ref NativeFrontendState state, usize source_record,
    ptr byte type_data, ref PackedBuffer types, ptr byte symbol_data,
    ptr byte detail_data, ref PackedBuffer symbols, ref BuildTimings timings
) {
    if !state.enabled { return false; }
    usize row = source_record * 232;
    state.enabled = native_frontend_type_hash(state, type_data, types, state.rows.data + row + 128);
    if !state.enabled { return false; }
    pe32_patch_u32(state.rows, row + 200, types.length);
    pe32_patch_u32(state.rows, row + 208, symbols.length);
    usize old = 112 + row;
    if state.saved.length == 0 ||
        !native_frontend_equal(state.rows.data + row, state.saved.data + old, 64) ||
        !native_frontend_equal(state.rows.data + row + 128, state.saved.data + old + 128, 64) ||
        native_read_u32(state.saved, old + 200) != types.length ||
        native_read_u32(state.saved, old + 208) != symbols.length { return false; }
    usize type_count = native_read_u32(state.saved, old + 204);
    usize symbol_count = native_read_u32(state.saved, old + 212);
    if type_count > types.capacity - types.length || symbol_count > symbols.capacity - symbols.length {
        state.enabled = false; return false;
    }
    resolution_copy_records(type_data + types.length * record_stride(), state.saved.data +
        native_read_u32(state.saved, 24) + types.length * record_stride(), type_count);
    resolution_copy_records(symbol_data + symbols.length * record_stride(), state.saved.data +
        native_read_u32(state.saved, 28) + symbols.length * record_stride(), symbol_count);
    resolution_copy_records(detail_data + symbols.length * record_stride(), state.saved.data +
        native_read_u32(state.saved, 32) + symbols.length * record_stride(), symbol_count);
    types.length = types.length + type_count; symbols.length = symbols.length + symbol_count;
    pe32_patch_u32(state.rows, row + 204, type_count);
    pe32_patch_u32(state.rows, row + 212, symbol_count);
    timings.frontend_resolution_hits = timings.frontend_resolution_hits + 1;
    return state.rows.ok;
}

unsafe void native_frontend_finish_resolution(
    ref NativeFrontendState state, usize source_record,
    ref PackedBuffer types, ref PackedBuffer symbols
) {
    if !state.enabled { return; }
    usize row = source_record * 232;
    pe32_patch_u32(state.rows, row + 204, types.length - native_read_u32(state.rows, row + 200));
    pe32_patch_u32(state.rows, row + 212, symbols.length - native_read_u32(state.rows, row + 208));
    if types.length > 16384 || symbols.length > 16384 { state.enabled = false; }
}

unsafe bool native_frontend_publish(
    ref NativeFrontendState state, text prefix,
    ptr byte type_data, ref PackedBuffer types, ptr byte symbol_data,
    ptr byte detail_data, ref PackedBuffer symbols
) {
    if !state.enabled { return true; }
    usize type_offset = 112 + state.rows.length;
    usize symbol_offset = type_offset + types.length * record_stride();
    usize detail_offset = symbol_offset + symbols.length * record_stride();
    usize projection_offset = detail_offset + symbols.length * record_stride();
    usize size = projection_offset + state.projections.length + 64;
    if size > 8388608 { return false; }
    DBuffer output = d_buffer_create(size);
    scope d_buffer_destroy(output);
    if output.data == null { return false; }
    pe32_put_u32(output, 1179534159); pe32_put_u32(output, 1);
    pe32_put_u32(output, state.source_count); pe32_put_u32(output, types.length);
    pe32_put_u32(output, symbols.length); pe32_put_u32(output, state.predecl_count);
    pe32_put_u32(output, type_offset); pe32_put_u32(output, symbol_offset);
    pe32_put_u32(output, detail_offset); pe32_put_u32(output, projection_offset);
    pe32_put_u32(output, state.projections.length); pe32_put_u32(output, 0);
    d_put(output, d_buffer_text(state.identity));
    d_put(output, d_buffer_text(state.rows));
    d_put_raw(output, type_data, types.length * record_stride());
    d_put_raw(output, symbol_data, symbols.length * record_stride());
    d_put_raw(output, detail_data, symbols.length * record_stride());
    d_put(output, d_buffer_text(state.projections));
    DBuffer digest = d_buffer_create(65);
    scope d_buffer_destroy(digest);
    if digest.data == null { return false; }
    module_cache_compiler_hash(output.data, output.length, digest);
    d_put(output, d_buffer_text(digest));
    DBuffer path = d_buffer_create(text.byte_length(prefix) + 16);
    scope d_buffer_destroy(path);
    d_put(path, prefix); d_put(path, ".frontend");
    return output.ok && output.length == size && digest.ok && digest.length == 64 &&
        path.ok && module_cache_publish(d_buffer_text(path), output.data, output.length);
}
