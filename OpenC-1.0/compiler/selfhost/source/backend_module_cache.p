import system.file;
import system.io;
import system.memory;
import system.process;
import system.text;

// Opt-in cache for the restricted native module-COFF boundary. Per-module
// records are storage hints. Only a checksum-verified whole-project snapshot
// published after successful acceptance and native link can skip acceptance
// for byte-identical inputs on a later build.
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
// attributes, constants, layouts and spelling. Declaration/interface edits
// invalidate the owning module and every qualified-reference/import dependent;
// body-only edits invalidate their owner via its separate full-content hash.
// Conditional declarations
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

// Resolution accepts an exported `module.symbol` (or short-module qualifier)
// even without an import declaration. Scan the exact source bytes, including
// function bodies, for every qualifier that the resolver can recognize.
// Comments and strings can create extra edges, which only cost cache hits.
unsafe bool module_cache_qualified_reference(text source, text name) {
    usize source_length = text.byte_length(source);
    usize name_length = text.byte_length(name);
    if name_length == 0 || name_length >= source_length { return false; }
    usize cursor = 0;
    while cursor + name_length < source_length {
        if starts_with_ascii(source, cursor, name) &&
            byte_at_or_zero(source, cursor + name_length) == 46 { return true; }
        cursor = cursor + 1;
    }
    return false;
}

unsafe bool module_cache_module_reference(
    text source, text project_source, ptr byte module_data, usize provider
) {
    usize start = read_record_field(module_data, provider, 0);
    usize length = read_record_field(module_data, provider, 1);
    text name = project_slice(project_source, start, length);
    usize short_start = project_short_start(name);
    text short_name = project_slice(name, short_start, length - short_start);
    return module_cache_qualified_reference(source, name) ||
        module_cache_qualified_reference(source, short_name) ||
        acceptance_source_imports(source, project_source, start, length);
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

// A whole-project validation snapshot is separate from per-module object
// keys. It may skip semantic work only for the exact compiler, manifest,
// project root, options schema, and every stable source byte previously
// validated and linked successfully. A changed source always takes the full
// acceptance path before consulting the object cache.
unsafe bool module_cache_project_key(
    text project_source, text project_root, ptr byte module_data,
    ref PackedBuffer modules, ptr byte source_data, usize source_bytes,
    ref DBuffer output
) {
    if modules.length == 0 || modules.length > 64 ||
        source_bytes > 4194304 || text.byte_length(project_source) > 1048576 {
        return false;
    }
    DBuffer input = d_buffer_create(
        text.byte_length(project_source) + text.byte_length(project_root) +
        source_bytes + modules.length * 128 + 4096
    );
    d_put(input, "openc-project-validation-v1:windows-x86_64-llp64:stable-coff:serial\n");
    d_put_usize(input, text.byte_length(project_root));
    d_put(input, ":"); d_put(input, project_root);
    d_put_usize(input, text.byte_length(project_source));
    d_put(input, ":"); d_put(input, project_source);
    ptr byte compiler_data;
    usize compiler_length;
    status compiler_loaded = cli_coff_read_bounded_object(
        process.executable_path(), 33554432, out compiler_data, out compiler_length
    );
    if !compiler_loaded.ok { d_buffer_destroy(input); return false; }
    DBuffer compiler_hash = d_buffer_create(65);
    module_cache_compiler_hash(compiler_data, compiler_length, compiler_hash);
    memory.free(compiler_data);
    d_put(input, d_buffer_text(compiler_hash));
    bool ok = input.ok && compiler_hash.ok;
    d_buffer_destroy(compiler_hash);
    usize module_index = 0;
    while module_index < modules.length && ok {
        text name = interface_module_name(project_source, module_data, module_index);
        if text.byte_length(name) == 0 || text.byte_length(name) > 1024 ||
            (module_index != 0 && name == interface_module_name(
                project_source, module_data, module_index - 1
            )) { ok = false; break; }
        d_put_usize(input, text.byte_length(name));
        d_put(input, ":"); d_put(input, name);
        usize first = read_record_field(module_data, module_index, 2);
        usize count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < count && ok {
            text source;
            status loaded = project_read_source_record(
                project_source, project_root, source_data,
                first + source_index, out source
            );
            if !loaded.ok || text.byte_length(source) > 131072 { ok = false; break; }
            d_put_usize(input, text.byte_length(source));
            d_put(input, ":"); d_put(input, source);
            ok = input.ok;
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    if ok { module_cache_digest(input.data, input.length, output); }
    ok = ok && output.ok && output.length == 64;
    d_buffer_destroy(input);
    return ok;
}

unsafe void module_cache_project_record_path(
    text prefix, text key, ref DBuffer output
) {
    d_put(output, prefix); d_put(output, ".p.");
    d_put(output, key); d_put(output, ".record");
}

unsafe bool module_cache_lower_hex(ptr byte data, usize length) {
    usize index = 0;
    while index < length {
        u8 value = cast(u8, *(data + index));
        if !((value >= 48 && value <= 57) ||
            (value >= 97 && value <= 102)) { return false; }
        index = index + 1;
    }
    return true;
}

unsafe bool module_cache_project_publish(
    text prefix, text key, ref ModuleCacheState cache, usize module_count
) {
    if !cache.enabled || text.byte_length(key) != 64 ||
        cache.entry.length != 71 || cache.hashes.length != module_count * 64 {
        return false;
    }
    DBuffer record = d_buffer_create(212 + module_count * 64);
    d_put(record, "OCVC0001\n");
    d_put(record, key);
    d_put_raw(record, cache.entry.data, 71);
    pe32_put_u32(record, module_count);
    d_put_raw(record, cache.hashes.data, module_count * 64);
    DBuffer checksum = d_buffer_create(65);
    if record.ok { module_cache_digest(record.data, record.length, checksum); }
    d_put(record, d_buffer_text(checksum));
    DBuffer path = d_buffer_create(text.byte_length(prefix) + 110);
    module_cache_project_record_path(prefix, key, path);
    bool ok = record.ok && record.length == 212 + module_count * 64 &&
        checksum.ok && path.ok && module_cache_publish(
            d_buffer_text(path), record.data, record.length
        );
    d_buffer_destroy(path); d_buffer_destroy(checksum);
    d_buffer_destroy(record);
    return ok;
}

// Returns 0 for a missing/damaged cache hint, 1 for a successful no-op
// relink, and -1 for an output/link failure after validated inputs were used.
unsafe i32 module_cache_project_dispose(ref DBuffer bundle, i32 result) {
    // The link bundle can grow. A `scope d_buffer_destroy(bundle)` captures
    // its original allocation and would double-free after reserve replaces it.
    d_buffer_destroy(bundle);
    return result;
}

unsafe i32 module_cache_project_try(
    text project_source, ptr byte module_data, ref PackedBuffer modules,
    text output_prefix, text linked_output, text cache_prefix,
    text key, ref BuildTimings timings
) {
    DBuffer path = d_buffer_create(text.byte_length(cache_prefix) + 110);
    scope d_buffer_destroy(path);
    module_cache_project_record_path(cache_prefix, key, path);
    if !path.ok { return 0; }
    ptr byte data;
    usize length;
    status loaded = cli_coff_read_bounded_object(
        d_buffer_text(path), 4308, out data, out length
    );
    if !loaded.ok { return 0; }
    scope memory.free(data);
    usize expected = 212 + modules.length * 64;
    DBuffer record_view = DBuffer{
        data = data, length = length, capacity = length, ok = true
    };
    if length != expected || modules.length > 64 ||
        !span_equals_ascii(d_buffer_text(record_view), 0, 9, "OCVC0001\n") { return 0; }
    usize digit = 0;
    while digit < 64 {
        if *(data + 9 + digit) != byte_at_or_zero(key, digit) { return 0; }
        digit = digit + 1;
    }
    if native_read_u32(record_view, 144) != modules.length { return 0; }
    DBuffer entry_prefix = DBuffer{
        data = data + 73, length = 7, capacity = 7, ok = true
    };
    if !span_equals_ascii(d_buffer_text(entry_prefix), 0, 7, "$openc$") ||
        !module_cache_lower_hex(data + 80, 64) { return 0; }
    DBuffer checksum = d_buffer_create(65);
    scope d_buffer_destroy(checksum);
    module_cache_digest(data, length - 64, checksum);
    if !checksum.ok { return 0; }
    digit = 0;
    while digit < 64 {
        if *(data + length - 64 + digit) != *(checksum.data + digit) { return 0; }
        digit = digit + 1;
    }
    DBuffer bundle = d_buffer_create(1024);
    ptr byte offsets = memory.alloc((modules.length + 1) * size_of(usize));
    scope memory.free(offsets);
    usize hits = 0;
    usize module_index = 0;
    while module_index < modules.length {
        write_usize(offsets, module_index * size_of(usize), 0);
        ptr byte hash_data = data + 148 + module_index * 64;
        if !module_cache_lower_hex(hash_data, 64) {
            return module_cache_project_dispose(bundle, 0);
        }
        DBuffer hash = DBuffer{
            data = hash_data, length = 64, capacity = 64, ok = true
        };
        if d_buffer_text(hash) !=
            "0000000000000000000000000000000000000000000000000000000000000000" {
            usize start = bundle.length;
            DBuffer object_path = d_buffer_create(text.byte_length(cache_prefix) + 100);
            d_put(object_path, cache_prefix); d_put(object_path, ".o.");
            d_put_raw(object_path, hash_data, 64); d_put(object_path, ".obj");
            bool ok = object_path.ok && coff_link_append_published_object_mode(
                bundle, d_buffer_text(object_path), d_buffer_text(hash), 0, true
            );
            d_buffer_destroy(object_path);
            if !ok { return module_cache_project_dispose(bundle, 0); }
            usize bytes = native_read_u32(bundle, start);
            DBuffer view = DBuffer{
                data = bundle.data + start + 4,
                length = bytes, capacity = bytes, ok = true
            };
            CoffLinkObject object = coff_link_parse(view);
            if !object.ok { return module_cache_project_dispose(bundle, 0); }
            write_usize(offsets, module_index * size_of(usize), start + 1);
            hits = hits + 1;
        }
        module_index = module_index + 1;
    }
    DBuffer manifest_path = d_buffer_create(text.byte_length(output_prefix) + 20);
    scope d_buffer_destroy(manifest_path);
    d_put(manifest_path, output_prefix); d_put(manifest_path, ".modules.json");
    if !manifest_path.ok || d_buffer_text(manifest_path) == linked_output {
        io.error("error[OPENC-COFF-LINK-PATH]: linked output collides with manifest\n");
        return module_cache_project_dispose(bundle, -1);
    }
    DBuffer manifest = d_buffer_create(
        modules.length * (text.byte_length(output_prefix) + 1024) + 4096
    );
    scope d_buffer_destroy(manifest);
    // Once authenticated inputs are accepted, invalidate a prior COMPLETE
    // output before replacing any object or PE at this output prefix.
    status invalidated = file.write_text(d_buffer_text(manifest_path),
        "{\"schema\":\"openc.module_coff_set.v1\",\"status\":\"INCOMPLETE\"}\n");
    if !invalidated.ok { return module_cache_project_dispose(bundle, -1); }
    d_put(manifest, "{\"schema\":\"openc.module_coff_set.v1\",\"status\":\"COMPLETE\",\"target\":\"windows-x86_64-llp64\",\"modules\":[\n");
    module_index = 0;
    usize emitted = 0;
    while module_index < modules.length {
        usize saved = read_usize(offsets, module_index * size_of(usize));
        if saved != 0 {
            text name = interface_module_name(project_source, module_data, module_index);
            DBuffer output_path = d_buffer_create(text.byte_length(output_prefix) + 100);
            bool ok = coff_module_object_path_for_name(name, output_prefix, output_path);
            if !ok || d_buffer_text(output_path) == linked_output {
                d_buffer_destroy(output_path);
                return module_cache_project_dispose(bundle, -1);
            }
            usize bytes = native_read_u32(bundle, saved - 1);
            status written = file.write_bytes(
                d_buffer_text(output_path), bundle.data + saved + 3, bytes
            );
            if !written.ok {
                d_buffer_destroy(output_path);
                return module_cache_project_dispose(bundle, -1);
            }
            if emitted != 0 { d_put(manifest, ",\n"); }
            d_put(manifest, "{\"module\":"); cli_json_text(manifest, name);
            d_put(manifest, ",\"object\":"); cli_json_text(manifest, d_buffer_text(output_path));
            d_put(manifest, ",\"sha256\":");
            DBuffer hash = DBuffer{
                data = data + 148 + module_index * 64,
                length = 64, capacity = 64, ok = true
            };
            cli_json_text(manifest, d_buffer_text(hash));
            d_put(manifest, ",\"cache_hit\":true}");
            emitted = emitted + 1;
            d_buffer_destroy(output_path);
        }
        module_index = module_index + 1;
    }
    d_put(manifest, "\n]}\n");
    if !manifest.ok { return module_cache_project_dispose(bundle, -1); }
    DBuffer entry = d_buffer_create(72);
    scope d_buffer_destroy(entry);
    d_put_raw(entry, data + 73, 71);
    if !entry.ok { return module_cache_project_dispose(bundle, -1); }
    status linked = coff_link_bundle_with_entry(bundle, entry, linked_output);
    if !linked.ok { return module_cache_project_dispose(bundle, -1); }
    status finished = file.write_text(d_buffer_text(manifest_path), d_buffer_text(manifest));
    if !finished.ok { return module_cache_project_dispose(bundle, -1); }
    timings.object_cache_enabled = true;
    timings.object_cache_hits = hits;
    timings.object_cache_misses = 0;
    timings.object_cache_validation_skipped = true;
    timings.module_selection_enabled = true;
    return module_cache_project_dispose(bundle, 1);
}

unsafe bool module_cache_prepare(
    ref IrContext context, ptr byte parsed_source_cache,
    text prefix, usize entry_module, ref ModuleCacheState cache, ref BuildTimings timings
) {
    if context.modules.length == 0 || context.modules.length > 64 ||
        timings.source_bytes > 4194304 || context.symbols.length > 16384 {
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
    DBuffer module_interfaces = d_buffer_create(context.modules.length * 64 + 1);
    DBuffer interfaces = d_buffer_create(
        text.byte_length(context.project_source) + 1024
    );
    ptr byte dependencies = memory.alloc(
        context.modules.length * context.modules.length * size_of(usize)
    );
    usize edge = 0;
    while edge < context.modules.length * context.modules.length {
        write_usize(dependencies, edge * size_of(usize), 0);
        edge = edge + 1;
    }
    d_put(interfaces, "openc-module-cache-v2:windows-x86_64-llp64:stable-coff:serial\n");
    d_put(interfaces, context.project_source);
    ptr byte compiler_data;
    usize compiler_length;
    status compiler_loaded = cli_coff_read_bounded_object(
        process.executable_path(), 33554432, out compiler_data, out compiler_length
    );
    if !compiler_loaded.ok {
        memory.free(dependencies); d_buffer_destroy(module_interfaces);
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
        write_usize(dependencies,
            (module_index * context.modules.length + module_index) * size_of(usize), 1);
        DBuffer module_content = d_buffer_create(timings.source_bytes + 8192);
        DBuffer module_interface = d_buffer_create(
            timings.source_files * 80 + 2048
        );
        text module_name = interface_module_name(
            context.project_source, context.module_data, module_index
        );
        d_put_usize(module_content, text.byte_length(module_name));
        d_put(module_content, ":"); d_put(module_content, module_name);
        d_put(module_content, "\n");
        d_put_usize(module_interface, text.byte_length(module_name));
        d_put(module_interface, ":"); d_put(module_interface, module_name);
        d_put(module_interface, "\n");
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
                d_buffer_destroy(module_interface); d_buffer_destroy(module_content);
                memory.free(dependencies); d_buffer_destroy(module_interfaces);
                d_buffer_destroy(contents); d_buffer_destroy(interfaces);
                return false;
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
                d_put(module_interface, d_buffer_text(source_hash));
                d_put(module_interface, "\n");
                d_put_usize(module_content, text.byte_length(source));
                d_put(module_content, ":"); d_put(module_content, source);
                ok = source_hash.ok && module_interface.ok && module_content.ok;
                usize provider = 0;
                while provider < context.modules.length && ok {
                    if provider != module_index && module_cache_module_reference(
                        source, context.project_source, context.module_data, provider
                    ) {
                        write_usize(dependencies,
                            (module_index * context.modules.length + provider) *
                                size_of(usize), 1);
                    }
                    provider = provider + 1;
                }
            }
            d_buffer_destroy(source_hash); d_buffer_destroy(projected);
            source_index = source_index + 1;
        }
        if ok {
            module_cache_digest(module_content.data, module_content.length, contents);
            module_cache_digest(module_interface.data, module_interface.length,
                module_interfaces);
            ok = contents.ok && module_interfaces.ok;
        }
        d_buffer_destroy(module_interface);
        d_buffer_destroy(module_content);
        module_index = module_index + 1;
    }
    DBuffer base_hash = d_buffer_create(65);
    if ok { module_cache_digest(interfaces.data, interfaces.length, base_hash); }
    ok = ok && base_hash.ok && base_hash.length == 64;
    // Boolean transitive closure. A provider interface change must invalidate
    // every module whose code or exported API can depend on it, not unrelated
    // modules. All edges are conservative textual supersets of resolver paths.
    usize via = 0;
    while via < context.modules.length && ok {
        usize dependent = 0;
        while dependent < context.modules.length {
            if read_usize(dependencies,
                (dependent * context.modules.length + via) * size_of(usize)) != 0 {
                usize provider = 0;
                while provider < context.modules.length {
                    if read_usize(dependencies,
                        (via * context.modules.length + provider) * size_of(usize)) != 0 {
                        write_usize(dependencies,
                            (dependent * context.modules.length + provider) *
                                size_of(usize), 1);
                    }
                    provider = provider + 1;
                }
            }
            dependent = dependent + 1;
        }
        via = via + 1;
    }
    module_index = 0;
    while module_index < context.modules.length && ok {
        DBuffer key = d_buffer_create(128 + context.modules.length * 64);
        d_put(key, d_buffer_text(base_hash));
        d_put_raw(key, contents.data + module_index * 64, 64);
        usize provider = 0;
        while provider < context.modules.length {
            if read_usize(dependencies,
                (module_index * context.modules.length + provider) * size_of(usize)) != 0 {
                d_put_raw(key, module_interfaces.data + provider * 64, 64);
            }
            provider = provider + 1;
        }
        if key.ok { module_cache_digest(key.data, key.length, cache.keys); }
        d_put(cache.hashes, "0000000000000000000000000000000000000000000000000000000000000000");
        d_buffer_destroy(key);
        ok = cache.keys.ok && cache.hashes.ok;
        module_index = module_index + 1;
    }
    d_buffer_destroy(base_hash); d_buffer_destroy(interfaces);
    d_buffer_destroy(module_interfaces); d_buffer_destroy(contents);
    memory.free(dependencies);
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
    text cache_prefix, text linked_output, text project_key,
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
        if result.ok && timings.object_cache_publish_failures == 0 &&
            text.byte_length(project_key) == 64 &&
            !module_cache_project_publish(
                cache_prefix, project_key, cache, context.modules.length
            ) {
            timings.object_cache_publish_failures =
                timings.object_cache_publish_failures + 1;
        }
    }
    d_buffer_destroy(manifest); d_buffer_destroy(bundle);
    return result;
}
