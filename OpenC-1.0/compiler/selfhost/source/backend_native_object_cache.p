import system.file;
import system.memory;
import system.text;

// Compiler-private native objects retain the direct PE linker's function
// records. Their keys bind function IDs and the complete resolved type table;
// they never rely on project-global IDs remaining stable after an edit.
unsafe bool native_object_cache_valid(
    ref IrContext context, ref DBuffer object,
    usize partition, usize partitions, usize entry_module
) {
    usize source_count = c_project_source_count(context);
    usize first = source_count * partition / partitions;
    usize end = source_count * (partition + 1) / partitions;
    if !object.ok || object.length < 16 ||
        object.length > coff_link_bundle_limit() - 4 ||
        native_read_u32(object, 0) != 1330529103 ||
        native_read_u32(object, 4) != 1 ||
        native_read_u32(object, 8) != first ||
        native_read_u32(object, 12) != end { return false; }
    usize cursor = 16;
    usize previous = 0;
    usize previous_source = first;
    bool have_previous = false;
    while cursor < object.length {
        if object.length - cursor < 24 { return false; }
        usize symbol = native_read_u32(object, cursor);
        usize entry_flag = native_read_u32(object, cursor + 4);
        usize code = native_read_u32(object, cursor + 8);
        usize unwind = native_read_u32(object, cursor + 12);
        usize relocations = native_read_u32(object, cursor + 16);
        usize constants = native_read_u32(object, cursor + 20);
        if symbol >= context.symbols.length || entry_flag > 1 || code == 0 ||
            relocations > 65535 || unwind < 4 ||
            read_record_field(context.symbol_data, symbol, 0) != resolution_symbol_function() {
            return false;
        }
        usize source = read_record_field(context.symbol_data, symbol, 1);
        if source < first || source >= end ||
            (have_previous && (source < previous_source ||
                (source == previous_source && symbol <= previous))) { return false; }
        if c_function_is_entry(context, symbol, entry_module) != (entry_flag == 1) {
            return false;
        }
        previous = symbol;
        previous_source = source;
        have_previous = true;
        usize after_code = cursor + 24;
        if code > object.length - after_code { return false; }
        after_code = after_code + code;
        if unwind > object.length - after_code { return false; }
        usize after_unwind = after_code + unwind;
        if relocations * 8 > object.length - after_unwind { return false; }
        usize after_relocations = after_unwind + relocations * 8;
        if constants > object.length - after_relocations { return false; }
        u8 version = cast(u8, *(object.data + after_code));
        usize unwind_codes = cast(usize, cast(u8, *(object.data + after_code + 2)));
        if (version & 7) != 1 || x64_align_up(4 + unwind_codes * 2, 4) > unwind {
            return false;
        }
        usize relocation = 0;
        while relocation < relocations {
            usize offset = native_read_u32(object, after_unwind + relocation * 8);
            usize target = native_read_u32(object, after_unwind + relocation * 8 + 4);
            if offset > code || code - offset < 4 { return false; }
            if target == cast(usize, 4294967295) || target == cast(usize, 4294967294) {
                // Shared checked-failure and unsupported-target routines.
            } else if target >= cast(usize, 3221225472) {
                if target - cast(usize, 3221225472) >= 96 { return false; }
            } else if target >= cast(usize, 2147483648) {
                if target - cast(usize, 2147483648) > constants { return false; }
            } else if target >= cast(usize, 1073741824) {
                if target - cast(usize, 1073741824) >= pe32_import_count() { return false; }
            } else if target >= context.symbols.length ||
                read_record_field(context.symbol_data, target, 0) != resolution_symbol_function() {
                return false;
            }
            relocation = relocation + 1;
        }
        cursor = after_relocations + constants;
    }
    return object.ok && cursor == object.length;
}

// One atomic bundle avoids two filesystem publications per source group and
// keeps ordinary-build disk usage bounded to the latest generation. Entries
// contain the independently checked key/hash and a contiguous object extent.
unsafe bool native_object_cache_load(
    text prefix, usize partitions, usize source_count, ref ModuleCacheState cache
) {
    DBuffer path = d_buffer_create(text.byte_length(prefix) + 16);
    d_put(path, prefix); d_put(path, ".bundle");
    if !path.ok { d_buffer_destroy(path); return false; }
    ptr byte data;
    usize length;
    status loaded = cli_coff_read_bounded_object(d_buffer_text(path),
        coff_link_bundle_limit(), out data, out length);
    d_buffer_destroy(path);
    if !loaded.ok { return false; }
    d_buffer_destroy(cache.saved);
    cache.saved = DBuffer{data = data, length = length, capacity = length, ok = true};
    bool ok = length >= 16 + partitions * 136 &&
        native_read_u32(cache.saved, 0) == 1112425295 &&
        native_read_u32(cache.saved, 4) == 1 &&
        native_read_u32(cache.saved, 8) == partitions &&
        native_read_u32(cache.saved, 12) == source_count;
    usize expected = 16 + partitions * 136;
    usize partition = 0;
    while partition < partitions && ok {
        usize slot = 16 + partition * 136;
        usize offset = native_read_u32(cache.saved, slot + 128);
        usize bytes = native_read_u32(cache.saved, slot + 132);
        ok = offset == expected && offset <= length && bytes >= 16;
        if ok { ok = bytes <= length - offset; }
        if ok { expected = offset + bytes; }
        partition = partition + 1;
    }
    ok = ok && expected == length;
    if !ok {
        // The eviction policy uses logical length. Retaining a rejected
        // multi-megabyte allocation with length zero bypasses that policy
        // and keeps its resident pages alive across all native workers.
        d_buffer_destroy(cache.saved);
        cache.saved = DBuffer{data = null, length = 0, capacity = 0, ok = true};
    }
    return ok;
}

unsafe bool native_object_cache_read_hit(
    text prefix, usize partition, usize partitions,
    ref IrContext context, usize entry_module, ref ModuleCacheState cache
) {
    if cache.saved.length < 16 + partitions * 136 { return false; }
    usize slot = 16 + partition * 136;
    usize digit = 0;
    while digit < 64 {
        if *(cache.saved.data + slot + digit) !=
            *(cache.keys.data + partition * 64 + digit) { return false; }
        digit = digit + 1;
    }
    usize offset = native_read_u32(cache.saved, slot + 128);
    usize length = native_read_u32(cache.saved, slot + 132);
    DBuffer view = DBuffer{data = cache.saved.data + offset,
        length = length, capacity = length, ok = true};
    DBuffer digest = d_buffer_create(65);
    if digest.data == null { d_buffer_destroy(digest); return false; }
    module_cache_digest(view.data, length, digest);
    bool ok = digest.ok && digest.length == 64;
    digit = 0;
    while digit < 64 && ok {
        ok = *(digest.data + digit) == *(cache.saved.data + slot + 64 + digit);
        digit = digit + 1;
    }
    if ok { ok = native_object_cache_valid(context, view, partition, partitions, entry_module); }
    if ok {
        write_usize(cache.offsets, partition * size_of(usize), offset + 1);
        write_usize(cache.stable_offsets, partition * size_of(usize), length);
    }
    d_buffer_destroy(digest);
    return ok;
}

// Native workers merge contiguous source ranges in source order. Index that
// stream once instead of scanning every record twice for each partition.
unsafe bool native_object_cache_index_fresh(
    ref IrContext context, ref DBuffer objects,
    usize partitions, ptr byte starts
) {
    usize cursor = 0;
    usize next = 0;
    usize previous_source = 0;
    usize source_count = c_project_source_count(context);
    while cursor < objects.length {
        if objects.length - cursor < 24 { return false; }
        usize symbol = native_read_u32(objects, cursor);
        usize code = native_read_u32(objects, cursor + 8);
        usize unwind = native_read_u32(objects, cursor + 12);
        usize relocations = native_read_u32(objects, cursor + 16);
        usize constants = native_read_u32(objects, cursor + 20);
        if symbol >= context.symbols.length || relocations > 65535 { return false; }
        usize size = 24 + code + unwind + relocations * 8 + constants;
        if size > objects.length - cursor { return false; }
        usize source = read_record_field(context.symbol_data, symbol, 1);
        if source >= source_count || source < previous_source { return false; }
        previous_source = source;
        usize partition = source_partition_index(source, source_count, partitions);
        while next <= partition {
            write_usize(starts, next * size_of(usize), cursor);
            next = next + 1;
        }
        cursor = cursor + size;
    }
    while next <= partitions {
        write_usize(starts, next * size_of(usize), cursor);
        next = next + 1;
    }
    return objects.ok && cursor == objects.length;
}

// Publication borrows only the immutable encoded bundle/path. The parent
// owns linking and its context/options. Both callbacks finish before any
// borrowed owner can be released; unavailable pool setup runs both serially.
struct NativeCachePublication {
    ptr byte context;
    ptr byte objects;
    ptr byte options;
    text output_path;
    text cache_path;
    ptr byte data;
    usize length;
    bool published;
    status written;
}

unsafe i32 native_object_cache_publish_link_jobs(ptr NativeCachePublication work) { return 3; }

unsafe void native_object_cache_publish_pool(
    ptr byte instance, ref NativeCachePublication publication, ptr byte work
) {
    publication.published = module_cache_publish(
        publication.cache_path, publication.data, publication.length);
}

unsafe void native_object_cache_link_main(ref NativeCachePublication publication) {
    ref IrContext context = *(reinterpret(ptr IrContext, publication.context));
    ref DBuffer objects = *(reinterpret(ptr DBuffer, publication.objects));
    ref NativeArtifactOptions options = *(reinterpret(ptr NativeArtifactOptions, publication.options));
    publication.written = native_write_image_options(
        context, objects, publication.output_path, options);
}

unsafe void native_object_cache_frontend_pool(
    ptr byte instance, ref NativeCachePublication publication, ptr byte work
) {
    ref IrContext context = *(reinterpret(ptr IrContext, publication.context));
    ref NativeArtifactOptions options = *(reinterpret(ptr NativeArtifactOptions, publication.options));
    if options.frontend_state == null { return; }
    ref NativeFrontendState frontend = *(reinterpret(ptr NativeFrontendState, options.frontend_state));
    PackedBuffer semantic_types = context.types;
    if options.cache_type_count == 0 || options.cache_type_count > semantic_types.length { return; }
    semantic_types.length = options.cache_type_count;
    frontend.prepare_parallel = true;
    // Only the frozen semantic prefix belongs in the frontend snapshot.
    // Linking may use derived closed types, never mutate that prefix.
    native_frontend_prepare_publish(frontend, options.cache_prefix,
        context.type_data, semantic_types, context.symbol_data, context.detail_data, context.symbols);
}

unsafe status native_object_cache_write_image(
    ref IrContext context, ref DBuffer objects, text output_path,
    ref NativeArtifactOptions options, ref ModuleCacheState cache,
    ref BuildTimings timings
) {
    usize partitions = options.source_partitions;
    usize source_count = c_project_source_count(context);
    ptr byte starts = memory.alloc((partitions + 1) * size_of(usize));
    scope memory.free(starts);
    if starts == null || !native_object_cache_index_fresh(context, objects, partitions, starts) {
        options.cache_retry_required = true;
        return status{code = 1};
    }
    usize merged_bytes = objects.length;
    usize partition = 0;
    bool has_hits = false;
    bool has_misses = false;
    while partition < partitions {
        if read_usize(cache.offsets, partition * size_of(usize)) != 0 {
            usize length = read_usize(cache.stable_offsets, partition * size_of(usize));
            if length < 16 || length - 16 > coff_link_bundle_limit() ||
                merged_bytes > coff_link_bundle_limit() - (length - 16) {
                options.cache_retry_required = true;
                return status{code = 1};
            }
            merged_bytes = merged_bytes + length - 16;
            has_hits = true;
        } else { has_misses = true; }
        partition = partition + 1;
    }
    usize bundle_bytes = 16 + partitions * 152 + merged_bytes;
    if bundle_bytes > coff_link_bundle_limit() {
        options.cache_retry_required = true;
        return status{code = 1};
    }
    usize entry_module = ir_entry_module(context.project_source, context.project_root,
        context.source_data, context.symbol_data, context.detail_data,
        context.symbols, context.modules.length);
    bool ok = true;
    bool retained = cache.saved.length != 0;
    if has_hits && !retained {
        // Authenticate the reloaded snapshot before allocating either merged
        // stream. A failed read must not touch a full object-sized destination
        // only to discard it and start a complete validating compilation.
        bool loaded = native_object_cache_load(
            options.cache_prefix, partitions, source_count, cache);
        partition = 0;
        while partition < partitions && loaded {
            if read_usize(cache.offsets, partition * size_of(usize)) != 0 {
                ok = native_object_cache_read_hit(options.cache_prefix,
                    partition, partitions, context, entry_module, cache);
                loaded = ok;
            }
            partition = partition + 1;
        }
        if !loaded {
            options.cache_retry_required = true;
            d_buffer_destroy(cache.saved);
            cache.saved = DBuffer{data = null, length = 0, capacity = 0, ok = true};
            return status{code = 1};
        }
    }
    DBuffer merged = d_buffer_create(1);
    if has_hits {
        d_buffer_destroy(merged);
        merged = d_buffer_create(merged_bytes + 1);
    }
    ok = merged.ok;
    if merged.data == null {
        options.cache_retry_required = true;
        d_buffer_destroy(merged);
        return status{code = 1};
    }
    DBuffer next = d_buffer_create(1);
    if has_misses {
        d_buffer_destroy(next);
        next = d_buffer_create(bundle_bytes);
        if next.data == null {
            options.cache_retry_required = true;
            d_buffer_destroy(next); d_buffer_destroy(merged);
            return status{code = 1};
        }
        pe32_put_u32(next, 1112425295); pe32_put_u32(next, 1);
        pe32_put_u32(next, partitions); pe32_put_u32(next, source_count);
        next.length = 16 + partitions * 136;
        ok = ok && next.ok;
    }
    partition = 0;
    while partition < partitions && ok {
        usize first = source_count * partition / partitions;
        usize end = source_count * (partition + 1) / partitions;
        usize object_start = next.length;
        if read_usize(cache.offsets, partition * size_of(usize)) != 0 {
            if ok {
                usize length = read_usize(cache.stable_offsets, partition * size_of(usize));
                usize offset = read_usize(cache.offsets, partition * size_of(usize)) - 1;
                native_copy_range(merged, cache.saved, offset + 16, length - 16);
                if has_misses { native_copy_range(next, cache.saved, offset, length); }
                ok = merged.ok;
            }
        } else {
            usize start = read_usize(starts, partition * size_of(usize));
            usize selected_bytes = read_usize(starts, (partition + 1) * size_of(usize)) - start;
            pe32_put_u32(next, 1330529103); pe32_put_u32(next, 1);
            pe32_put_u32(next, first); pe32_put_u32(next, end);
            native_copy_range(next, objects, start, selected_bytes);
            if has_hits { native_copy_range(merged, objects, start, selected_bytes); }
            ok = next.ok && merged.ok;
        }
        if ok && has_misses {
            usize slot = 16 + partition * 136;
            DBuffer digest = d_buffer_create(65);
            ok = digest.data != null;
            if ok { module_cache_digest(next.data + object_start, next.length - object_start, digest); }
            ok = ok && digest.ok && digest.length == 64;
            if !ok { options.cache_retry_required = true; }
            if ok {
                text.copy_utf8_unchecked(next.data + slot,
                    text.from_utf8(cache.keys.data + partition * 64, 64));
                text.copy_utf8_unchecked(next.data + slot + 64, d_buffer_text(digest));
                pe32_patch_u32(next, slot + 128, object_start);
                pe32_patch_u32(next, slot + 132, next.length - object_start);
            }
            d_buffer_destroy(digest);
        }
        partition = partition + 1;
    }
    // All borrowed extents have been copied. Neither publication nor PE
    // linking needs the saved bundle to remain resident beside those copies.
    if cache.saved.data != null {
        d_buffer_destroy(cache.saved);
        cache.saved = DBuffer{data = null, length = 0, capacity = 0, ok = true};
    }
    status written = status{code = 1};
    if ok {
        bool linked = false;
        if has_misses {
            DBuffer path = d_buffer_create(text.byte_length(options.cache_prefix) + 16);
            d_put(path, options.cache_prefix); d_put(path, ".bundle");
            bool published = false;
            if path.ok && next.ok && next.length == bundle_bytes &&
                (!has_hits || merged.length == merged_bytes) {
                ptr byte image_objects = reinterpret(ptr byte, &objects);
                if has_hits { image_objects = reinterpret(ptr byte, &merged); }
                NativeCachePublication publication = NativeCachePublication{
                    context = reinterpret(ptr byte, &context), objects = image_objects,
                    options = reinterpret(ptr byte, &options), output_path = output_path,
                    cache_path = d_buffer_text(path), data = next.data, length = next.length,
                    published = false, written = status{code = 1}};
                i32 launch = native_object_cache_publish_link_jobs(&publication);
                if launch != 0 {
                    publication.published = module_cache_publish(
                        publication.cache_path, publication.data, publication.length);
                    // Serial fallback need not retain the encoded bundle
                    // throughout linking once its write has finished.
                    d_buffer_destroy(next);
                    next = DBuffer{data = null, length = 0, capacity = 0, ok = true};
                    native_object_cache_link_main(publication);
                } else { timings.object_cache_publish_parallel = true; }
                published = publication.published;
                written = publication.written;
                linked = true;
            }
            if !published {
                timings.object_cache_publish_failures =
                    timings.object_cache_publish_failures + timings.object_cache_misses;
            }
            d_buffer_destroy(path);
        }
        // Publication and any joined link have finished. Release this owner
        // before a remaining serial link or the caller's frontend publication.
        if next.data != null { d_buffer_destroy(next); }
        next = DBuffer{data = null, length = 0, capacity = 0, ok = true};
        if !linked && has_hits {
            if merged.length == merged_bytes {
                written = native_write_image_options(context, merged, output_path, options);
            } else { options.cache_retry_required = true; }
        } else if !linked { written = native_write_image_options(context, objects, output_path, options); }
    }
    d_buffer_destroy(next);
    d_buffer_destroy(merged);
    return written;
}
