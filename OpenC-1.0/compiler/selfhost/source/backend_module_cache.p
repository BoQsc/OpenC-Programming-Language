import system.file;
import system.io;
import system.memory;
import system.process;
import system.text;

// Opt-in cache for the restricted native module-COFF boundary. Cache records
// are untrusted storage hints, never permission to skip source acceptance.
struct ModuleCacheState {
    bool enabled;
    DBuffer keys;
    DBuffer hashes;
    DBuffer saved;
    DBuffer entry;
    ptr byte offsets;
}

unsafe status cli_cache_write_exclusive(text path, ptr byte data, usize length) {
    return status{ code = 1 };
}
unsafe status cli_cache_atomic_replace(text temporary, text destination) {
    return status{ code = 1 };
}
unsafe bool cli_cache_sha256_runtime(ptr byte data, usize length, ptr byte digest) {
    return false;
}

// The platform acceleration is optional. The exact OpenC implementation is
// the fallback and remains the oracle for all source and object digests.
unsafe void module_cache_compiler_hash(ptr byte data, usize length, ref DBuffer output) {
    ptr byte digest = memory.alloc(32);
    scope memory.free(digest);
    if cli_cache_sha256_runtime(data, length, digest) {
        usize index = 0;
        while index < 32 {
            u8 value = cast(u8, *(digest + index));
            d_put(output, project_hex_digit(value / 16));
            d_put(output, project_hex_digit(value % 16));
            index = index + 1;
        }
    } else { winmd_sha256_hex(data, length, output); }
}

unsafe void module_cache_digest(ptr byte data, usize length, ref DBuffer output) {
    if length >= 4096 { module_cache_compiler_hash(data, length, output); }
    else { winmd_sha256_hex(data, length, output); }
}

ModuleCacheState module_cache_empty() {
    DBuffer empty = DBuffer{ data = null, length = 0, capacity = 0, ok = true };
    return ModuleCacheState{
        enabled = false, keys = empty, hashes = empty, saved = empty, entry = empty,
        offsets = null
    };
}
unsafe void module_cache_destroy(ref ModuleCacheState cache) {
    if cache.keys.data != null { d_buffer_destroy(cache.keys); }
    if cache.hashes.data != null { d_buffer_destroy(cache.hashes); }
    if cache.saved.data != null { d_buffer_destroy(cache.saved); }
    if cache.entry.data != null { d_buffer_destroy(cache.entry); }
    memory.free(cache.offsets);
}

unsafe void module_cache_path(
    ref DBuffer output, text prefix, text category,
    ref DBuffer hashes, usize index, text suffix
) {
    d_put(output, prefix); d_put(output, category);
    d_put_raw(output, hashes.data + index * 64, 64);
    d_put(output, suffix);
}

// Exclusive creation claims a temporary name. A collision never truncates
// another writer's temporary file. Only our successfully claimed name moves.
unsafe bool module_cache_publish(text destination, ptr byte data, usize length) {
    usize attempt = 0;
    while attempt < 8 {
        DBuffer temporary = d_buffer_create(text.byte_length(destination) + 80);
        d_put(temporary, destination); d_put(temporary, ".tmp.");
        d_put_usize(temporary, process.monotonic_milliseconds());
        d_put(temporary, "."); d_put_usize(temporary, attempt);
        status claimed = status{ code = 1 };
        if temporary.ok {
            claimed = cli_cache_write_exclusive(d_buffer_text(temporary), data, length);
        }
        if claimed.ok {
            status published = cli_cache_atomic_replace(
                d_buffer_text(temporary), destination
            );
            d_buffer_destroy(temporary);
            return published.ok;
        }
        d_buffer_destroy(temporary);
        attempt = attempt + 1;
    }
    return false;
}

// Hash all source bytes outside ordinary function bodies, including imports,
// attributes, constants, layouts and spelling. Any declaration/interface edit
// conservatively invalidates EVERY module. Body-only edits invalidate the
// owning module via its separate full-content hash. Conditional declarations
// fail closed rather than pretending this is a complete semantic projection.
unsafe bool module_cache_source_projection(
    text source, ref ResolutionParsedSource parsed, ref DBuffer output
) {
    if !parsed.reusable || text.byte_length(source) > 131072 { return false; }
    usize node = 0;
    while node < parsed.syntax.length {
        if read_record_field(parsed.syntax_data, node, 0) == 8 { return false; }
        node = node + 1;
    }
    usize cursor = 0;
    usize source_length = text.byte_length(source);
    usize function_end = 0;
    bool awaiting_body = false;
    node = 0;
    // Parser records the function, parameters, then outer body before nested
    // statements. Check containment/end invariants and reject any unfamiliar
    // shape instead of repeatedly rescanning all syntax for each function.
    while node < parsed.syntax.length {
        usize kind = read_record_field(parsed.syntax_data, node, 0);
        if kind == 2 {
            usize start = read_record_field(parsed.syntax_data, node, 1);
            usize length = read_record_field(parsed.syntax_data, node, 2);
            if awaiting_body || start < cursor || start > source_length ||
                length > source_length - start { return false; }
            function_end = start + length;
            awaiting_body = true;
        } else if kind == 11 && awaiting_body {
            usize start = read_record_field(parsed.syntax_data, node, 1);
            usize length = read_record_field(parsed.syntax_data, node, 2);
            if start < cursor || start > source_length ||
                length > source_length - start || start + length != function_end {
                return false;
            }
            if byte_at_or_zero(source, start) == 123 {
                d_put_slice(output, source, cursor, start - cursor);
                d_put(output, "{}\n"); cursor = start + length;
            }
            awaiting_body = false;
        }
        node = node + 1;
    }
    if awaiting_body { return false; }
    d_put_slice(output, source, cursor, source_length - cursor);
    return output.ok;
}

unsafe bool module_cache_read_hit(
    text prefix, usize module_index, ref ModuleCacheState cache
) {
    DBuffer record_path = d_buffer_create(text.byte_length(prefix) + 100);
    module_cache_path(record_path, prefix, ".k.", cache.keys, module_index, ".record");
    ptr byte data;
    usize length;
    status loaded = cli_coff_read_bounded_object(
        d_buffer_text(record_path), 130, out data, out length
    );
    d_buffer_destroy(record_path);
    if !loaded.ok { return false; }
    bool ok = length == 130;
    usize digit = 0;
    while digit < 64 && ok {
        u8 value = cast(u8, *(data + 65 + digit));
        ok = *(data + digit) == *(cache.keys.data + module_index * 64 + digit) &&
            ((value >= 48 && value <= 57) || (value >= 97 && value <= 102));
        digit = digit + 1;
    }
    if ok { ok = *(data + 64) == 10 && *(data + 129) == 10; }
    if ok {
        digit = 0;
        while digit < 64 {
            *(cache.hashes.data + module_index * 64 + digit) = *(data + 65 + digit);
            digit = digit + 1;
        }
    }
    memory.free(data);
    if !ok { return false; }
    DBuffer object_path = d_buffer_create(text.byte_length(prefix) + 100);
    module_cache_path(object_path, prefix, ".o.", cache.hashes, module_index, ".obj");
    DBuffer hash = d_buffer_create(65);
    d_put_raw(hash, cache.hashes.data + module_index * 64, 64);
    usize saved_start = cache.saved.length;
    ok = coff_link_append_published_object_mode(
        cache.saved, d_buffer_text(object_path), d_buffer_text(hash), 0, true
    );
    if ok {
        usize bytes = native_read_u32(cache.saved, saved_start);
        DBuffer view = DBuffer{
            data = cache.saved.data + saved_start + 4,
            length = bytes, capacity = bytes, ok = true
        };
        CoffLinkObject object = coff_link_parse(view);
        ok = object.ok;
    }
    if ok { write_usize(cache.offsets, module_index * size_of(usize), saved_start + 1); }
    else { cache.saved.length = saved_start; }
    d_buffer_destroy(hash);
    d_buffer_destroy(object_path);
    return ok;
}

unsafe bool module_cache_prepare(
    ref IrContext context, ptr byte parsed_source_cache,
    text prefix, usize entry_module, ref ModuleCacheState cache, ref BuildTimings timings
) {
    if context.modules.length == 0 || context.modules.length > 64 ||
        timings.source_bytes > 4194304 || context.symbols.length > 4096 {
        return false;
    }
    usize name_index = 0;
    while name_index < context.modules.length {
        text name = interface_module_name(context.project_source, context.module_data, name_index);
        if text.byte_length(name) == 0 || text.byte_length(name) > 1024 { return false; }
        if name_index != 0 && name == interface_module_name(
            context.project_source, context.module_data, name_index - 1
        ) { return false; }
        name_index = name_index + 1;
    }
    cache.keys = d_buffer_create(context.modules.length * 64 + 1);
    cache.hashes = d_buffer_create(context.modules.length * 64 + 1);
    cache.saved = d_buffer_create(1024);
    cache.entry = d_buffer_create(80);
    cache.offsets = memory.alloc((context.modules.length + 1) * size_of(usize));
    DBuffer contents = d_buffer_create(context.modules.length * 64 + 1);
    DBuffer interfaces = d_buffer_create(
        text.byte_length(context.project_source) + timings.source_files * 80 + 1024
    );
    d_put(interfaces, "openc-module-cache-v1:windows-x86_64-llp64:stable-coff:serial\n");
    d_put(interfaces, context.project_source);
    ptr byte compiler_data;
    usize compiler_length;
    status compiler_loaded = cli_coff_read_bounded_object(
        process.executable_path(), 33554432, out compiler_data, out compiler_length
    );
    if !compiler_loaded.ok {
        d_buffer_destroy(contents); d_buffer_destroy(interfaces);
        return false;
    }
    bool ok = true;
    DBuffer compiler_hash = d_buffer_create(65);
    module_cache_compiler_hash(compiler_data, compiler_length, compiler_hash);
    memory.free(compiler_data);
    d_put(interfaces, d_buffer_text(compiler_hash));
    ok = compiler_hash.ok;
    d_buffer_destroy(compiler_hash);
    usize module_index = 0;
    while module_index < context.modules.length && ok {
        write_usize(cache.offsets, module_index * size_of(usize), 0);
        DBuffer module_content = d_buffer_create(timings.source_bytes + 8192);
        text module_name = interface_module_name(
            context.project_source, context.module_data, module_index
        );
        d_put_usize(module_content, text.byte_length(module_name));
        d_put(module_content, ":"); d_put(module_content, module_name);
        d_put(module_content, "\n");
        usize first = read_record_field(context.module_data, module_index, 2);
        usize count = read_record_field(context.module_data, module_index, 3);
        usize source_index = 0;
        while source_index < count && ok {
            text source;
            status loaded = project_read_source_record(
                context.project_source, context.project_root,
                context.source_data, first + source_index, out source
            );
            if !loaded.ok {
                d_buffer_destroy(module_content); d_buffer_destroy(contents);
                d_buffer_destroy(interfaces); return false;
            }
            ok = text.byte_length(source) <= 131072;
            DBuffer projected = d_buffer_create(text.byte_length(source) + 8192);
            ResolutionParsedSource parsed = resolution_cached_parsed_source(
                parsed_source_cache, first + source_index
            );
            if ok { ok = module_cache_source_projection(source, parsed, projected); }
            DBuffer source_hash = d_buffer_create(65);
            if ok {
                module_cache_digest(projected.data, projected.length, source_hash);
                d_put(interfaces, d_buffer_text(source_hash)); d_put(interfaces, "\n");
                d_put_usize(module_content, text.byte_length(source));
                d_put(module_content, ":"); d_put(module_content, source);
                ok = source_hash.ok && interfaces.ok && module_content.ok;
            }
            d_buffer_destroy(source_hash); d_buffer_destroy(projected);
            source_index = source_index + 1;
        }
        if ok { module_cache_digest(module_content.data, module_content.length, contents); }
        d_buffer_destroy(module_content);
        module_index = module_index + 1;
    }
    DBuffer interface_hash = d_buffer_create(65);
    if ok { winmd_sha256_hex(interfaces.data, interfaces.length, interface_hash); }
    module_index = 0;
    while module_index < context.modules.length && ok {
        DBuffer key = d_buffer_create(256);
        d_put(key, d_buffer_text(interface_hash));
        d_put_raw(key, contents.data + module_index * 64, 64);
        winmd_sha256_hex(key.data, key.length, cache.keys);
        d_put(cache.hashes, "0000000000000000000000000000000000000000000000000000000000000000");
        d_buffer_destroy(key);
        ok = cache.keys.ok && cache.hashes.ok;
        module_index = module_index + 1;
    }
    d_buffer_destroy(interface_hash); d_buffer_destroy(interfaces);
    d_buffer_destroy(contents);
    // Only the entry's stable identity is needed by a saved-object link. Do
    // not hash/reparse every function in every module on a no-op build.
    usize entry = context.symbols.length;
    usize symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) == resolution_symbol_function() &&
            c_function_is_entry(context, symbol, entry_module) {
            if entry != context.symbols.length { ok = false; }
            entry = symbol;
        }
        symbol = symbol + 1;
    }
    if entry == context.symbols.length { ok = false; }
    if ok {
        usize source_record = read_record_field(context.symbol_data, entry, 1);
        text source;
        status loaded = project_read_source_record(context.project_source, context.project_root,
            context.source_data, source_record, out source);
        ResolutionParsedSource parsed = resolution_cached_parsed_source(parsed_source_cache, source_record);
        DBuffer hash = d_buffer_create(65);
        ptr byte offsets = memory.alloc((context.symbols.length + 1) * size_of(usize));
        if loaded.ok && parsed.reusable {
            ok = coff_stable_add_symbol(context, source, parsed.syntax_data, parsed.syntax,
                entry, hash, offsets);
            d_put(cache.entry, "$openc$"); d_put(cache.entry, d_buffer_text(hash));
            ok = ok && cache.entry.ok && cache.entry.length == 71;
        } else { ok = false; }
        memory.free(offsets); d_buffer_destroy(hash);
    }
    cache.enabled = ok;
    if ok {
        timings.object_cache_enabled = true;
        module_index = 0;
        while module_index < context.modules.length {
            if module_cache_read_hit(prefix, module_index, cache) {
                timings.object_cache_hits = timings.object_cache_hits + 1;
            } else {
                timings.object_cache_misses = timings.object_cache_misses + 1;
            }
            module_index = module_index + 1;
        }
    }
    return ok;
}

unsafe bool module_cache_store(
    text prefix, usize module_index, ref ModuleCacheState cache,
    ref DBuffer object, ref DBuffer digest
) {
    usize digit = 0;
    while digit < 64 {
        *(cache.hashes.data + module_index * 64 + digit) = *(digest.data + digit);
        digit = digit + 1;
    }
    DBuffer object_path = d_buffer_create(text.byte_length(prefix) + 100);
    module_cache_path(object_path, prefix, ".o.", cache.hashes, module_index, ".obj");
    bool ok = object_path.ok && module_cache_publish(
        d_buffer_text(object_path), object.data, object.length
    );
    DBuffer record_path = d_buffer_create(text.byte_length(prefix) + 100);
    module_cache_path(record_path, prefix, ".k.", cache.keys, module_index, ".record");
    DBuffer record = d_buffer_create(131);
    d_put_raw(record, cache.keys.data + module_index * 64, 64);
    d_put(record, "\n"); d_put(record, d_buffer_text(digest)); d_put(record, "\n");
    if ok { ok = record.ok && record_path.ok && module_cache_publish(
        d_buffer_text(record_path), record.data, record.length
    ); }
    d_buffer_destroy(record); d_buffer_destroy(record_path);
    d_buffer_destroy(object_path);
    return ok;
}

unsafe status module_cache_write_set(
    ref IrContext context, ref DBuffer objects, text prefix,
    text cache_prefix, text linked_output,
    ref ModuleCacheState cache, ref BuildTimings timings
) {
    DBuffer manifest_path = d_buffer_create(text.byte_length(prefix) + 20);
    scope d_buffer_destroy(manifest_path);
    d_put(manifest_path, prefix); d_put(manifest_path, ".modules.json");
    if d_buffer_text(manifest_path) == linked_output {
        io.error("error[OPENC-COFF-LINK-PATH]: linked output collides with manifest\n");
        return status{ code = 1 };
    }
    // An earlier COMPLETE result must not survive a failed replacement build.
    status invalidated = file.write_text(d_buffer_text(manifest_path),
        "{\"schema\":\"openc.module_coff_set.v1\",\"status\":\"INCOMPLETE\"}\n");
    if !invalidated.ok { return status{ code = 1 }; }
    DBuffer bundle = d_buffer_create(1024);
    DBuffer manifest = d_buffer_create(context.modules.length * (text.byte_length(prefix) + 1024) + 4096);
    d_put(manifest, "{\"schema\":\"openc.module_coff_set.v1\",\"status\":\"COMPLETE\",\"target\":\"windows-x86_64-llp64\",\"modules\":[\n");
    usize module_index = 0;
    usize emitted = 0;
    bool ok = true;
    while module_index < context.modules.length && ok {
        usize saved = read_usize(cache.offsets, module_index * size_of(usize));
        DBuffer object = DBuffer{ data = null, length = 0, capacity = 0, ok = true };
        bool hit = saved != 0;
        bool owned = false;
        usize records = 0;
        if hit {
            usize bytes = native_read_u32(cache.saved, saved - 1);
            object = DBuffer{ data = cache.saved.data + saved + 3,
                length = bytes, capacity = bytes, ok = true };
        } else {
            DBuffer subset = d_buffer_create(objects.length + 1);
            usize selected_bytes = 0;
            ok = coff_module_subset(context, objects, module_index, subset,
                records, selected_bytes, true);
            if ok && records != 0 {
                usize exports = 0;
                usize relocations = 0;
                object = native_build_coff_object(context, subset, exports, relocations, true, true);
                owned = true;
                ok = object.ok;
            }
            d_buffer_destroy(subset);
        }
        if ok && object.length != 0 {
            DBuffer digest = d_buffer_create(65);
            module_cache_digest(object.data, object.length, digest);
            DBuffer object_path = d_buffer_create(text.byte_length(prefix) + 100);
            ok = coff_module_object_path(context, module_index, prefix, object_path) && digest.ok;
            if d_buffer_text(object_path) == linked_output { ok = false; }
            if ok {
                status written = file.write_bytes(d_buffer_text(object_path), object.data, object.length);
                ok = written.ok && coff_link_bundle_reserve(bundle, object.length + 4);
            }
            if ok {
                pe32_put_u32(bundle, object.length); d_put_raw(bundle, object.data, object.length);
                if !hit && !module_cache_store(cache_prefix, module_index, cache, object, digest) {
                    timings.object_cache_publish_failures = timings.object_cache_publish_failures + 1;
                }
                if emitted != 0 { d_put(manifest, ",\n"); }
                d_put(manifest, "{\"module\":"); cli_json_text(manifest, interface_module_name(
                    context.project_source, context.module_data, module_index));
                d_put(manifest, ",\"object\":"); cli_json_text(manifest, d_buffer_text(object_path));
                d_put(manifest, ",\"sha256\":"); cli_json_text(manifest, d_buffer_text(digest));
                d_put(manifest, ",\"cache_hit\":"); native_put_bool(manifest, hit);
                d_put(manifest, "}"); emitted = emitted + 1;
            }
            d_buffer_destroy(object_path); d_buffer_destroy(digest);
        }
        if owned { d_buffer_destroy(object); }
        module_index = module_index + 1;
    }
    d_put(manifest, "\n]}\n");
    status result = status{ code = 1 };
    if ok && cache.entry.ok && cache.entry.length == 71 && manifest.ok {
        result = coff_link_bundle_with_entry(bundle, cache.entry, linked_output);
        if result.ok {
            result = file.write_text(d_buffer_text(manifest_path), d_buffer_text(manifest));
        }
    }
    d_buffer_destroy(manifest); d_buffer_destroy(bundle);
    return result;
}
