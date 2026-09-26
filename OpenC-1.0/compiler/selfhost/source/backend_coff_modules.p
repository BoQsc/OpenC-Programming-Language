import system.file;
import system.io;
import system.memory;
import system.text;

unsafe bool coff_module_object_path(
    ref IrContext context,
    usize module_index,
    text prefix,
    ref DBuffer output
) {
    text module_name = interface_module_name(
        context.project_source, context.module_data, module_index
    );
    return coff_module_object_path_for_name(module_name, prefix, output);
}

unsafe bool coff_module_object_path_for_name(
    text module_name,
    text prefix,
    ref DBuffer output
) {
    DBuffer name_bytes = d_buffer_create(text.byte_length(module_name) + 1);
    d_put(name_bytes, module_name);
    DBuffer name_hash = d_buffer_create(65);
    if name_bytes.ok {
        winmd_sha256_hex(name_bytes.data, name_bytes.length, name_hash);
    }
    d_put(output, prefix);
    d_put(output, ".");
    d_put(output, d_buffer_text(name_hash));
    d_put(output, ".obj");
    bool ok = name_bytes.ok && name_hash.ok && output.ok;
    d_buffer_destroy(name_hash);
    d_buffer_destroy(name_bytes);
    return ok;
}

unsafe bool coff_module_names_valid(
    ref IrContext context,
    ptr byte order
) {
    usize ordinal = 0;
    while ordinal < context.modules.length {
        usize module_index = read_usize(order, ordinal * size_of(usize));
        text name = interface_module_name(
            context.project_source, context.module_data, module_index
        );
        if text.byte_length(name) == 0 || text.byte_length(name) > 1024 {
            return false;
        }
        if ordinal != 0 {
            usize previous = read_usize(
                order, (ordinal - 1) * size_of(usize)
            );
            text previous_name = interface_module_name(
                context.project_source, context.module_data, previous
            );
            if name == previous_name { return false; }
        }
        ordinal = ordinal + 1;
    }
    return true;
}

unsafe bool coff_module_subset(
    ref IrContext context,
    ref DBuffer objects,
    usize module_index,
    ref DBuffer subset,
    ref usize records,
    ref usize selected_bytes,
    bool copy_bytes
) {
    usize cursor = 0;
    usize selected = 0;
    usize bytes = 0;
    while cursor < objects.length {
        if objects.length - cursor < 24 { return false; }
        usize symbol = native_read_u32(objects, cursor);
        usize code = native_read_u32(objects, cursor + 8);
        usize unwind = native_read_u32(objects, cursor + 12);
        usize relocations = native_read_u32(objects, cursor + 16);
        usize constants = native_read_u32(objects, cursor + 20);
        if symbol >= context.symbols.length || relocations > 65535 {
            return false;
        }
        usize record_size = 24 + code + unwind +
            relocations * 8 + constants;
        if record_size > objects.length - cursor { return false; }
        if read_record_field(context.detail_data, symbol, 0) ==
            module_index {
            if copy_bytes {
                native_copy_range(subset, objects, cursor, record_size);
            }
            selected = selected + 1;
            bytes = bytes + record_size;
        }
        cursor = cursor + record_size;
    }
    records = selected;
    selected_bytes = bytes;
    return cursor == objects.length && subset.ok;
}

// Keep the opt-in in-memory link bundle bounded without reserving 8 MiB for
// every small project. The old bundle remains intact if allocation fails.
unsafe bool coff_link_bundle_reserve(
    ref DBuffer bundle,
    usize addition
) {
    usize limit = 8388608;
    if !bundle.ok || addition > limit ||
        bundle.length > limit - addition { return false; }
    usize needed = bundle.length + addition;
    if needed <= bundle.capacity { return true; }
    usize capacity = bundle.capacity;
    if capacity == 0 { capacity = 1024; }
    while capacity < needed {
        if capacity > limit / 2 { capacity = limit; }
        else { capacity = capacity * 2; }
    }
    DBuffer grown = d_buffer_create(capacity);
    if grown.data == null { return false; }
    d_put_raw(grown, bundle.data, bundle.length);
    if !grown.ok {
        d_buffer_destroy(grown);
        return false;
    }
    d_buffer_destroy(bundle);
    bundle = grown;
    return true;
}

// Compiler-private native runtime hook. Older bootstrap compilers emit this
// fail-closed body; the next native generation owns the bounded reader.
unsafe status cli_coff_read_bounded_object(
    text object_path,
    usize max_bytes,
    out ptr byte data,
    out usize length
) {
    return status{ code = 1 };
}

// Read back and authenticate the published COFF bytes before native link.
// This is deliberately file-backed even on the first build so the linker
// never relies on an unpublished writer buffer as its input.
unsafe bool coff_link_append_published_object(
    ref DBuffer bundle,
    text object_path,
    text expected_hash,
    usize expected_length
) {
    return coff_link_append_published_object_mode(
        bundle, object_path, expected_hash, expected_length, false
    );
}

unsafe bool coff_link_append_published_object_mode(
    ref DBuffer bundle, text object_path, text expected_hash,
    usize expected_length, bool accelerate_hash
) {
    ptr byte saved_data;
    usize saved_length;
    if bundle.length > 8388604 { return false; }
    usize remaining = 8388604 - bundle.length;
    status loaded = cli_coff_read_bounded_object(
        object_path, remaining, out saved_data, out saved_length
    );
    if !loaded.ok { return false; }
    bool ok = saved_data != null &&
        (expected_length == 0 || saved_length == expected_length) &&
        saved_length <= 8388604;
    DBuffer saved_hash = d_buffer_create(65);
    if ok {
        if accelerate_hash { module_cache_digest(saved_data, saved_length, saved_hash); }
        else { winmd_sha256_hex(saved_data, saved_length, saved_hash); }
        ok = saved_hash.ok &&
            d_buffer_text(saved_hash) == expected_hash;
    }
    if ok { ok = coff_link_bundle_reserve(bundle, saved_length + 4); }
    if ok {
        pe32_put_u32(bundle, saved_length);
        d_put_raw(bundle, saved_data, saved_length);
        ok = bundle.ok;
    }
    memory.free(saved_data);
    d_buffer_destroy(saved_hash);
    return ok;
}

unsafe bool coff_write_one_module(
    ref IrContext context,
    ref DBuffer objects,
    usize module_index,
    text prefix,
    ref DBuffer manifest,
    bool first_entry,
    ref bool wrote_entry,
    ref DBuffer bundle,
    text linked_output_path
) {
    wrote_entry = false;
    text module_name = interface_module_name(
        context.project_source, context.module_data, module_index
    );
    DBuffer object_path = d_buffer_create(text.byte_length(prefix) + 80);
    bool path_ok = coff_module_object_path(
        context, module_index, prefix, object_path
    );
    if d_buffer_text(object_path) == linked_output_path &&
        text.byte_length(linked_output_path) != 0 { path_ok = false; }
    DBuffer preview = DBuffer{
        data = null, length = 0, capacity = 0, ok = true
    };
    usize records = 0;
    usize selected_bytes = 0;
    bool ok = path_ok &&
        coff_module_subset(
            context, objects, module_index, preview, records,
            selected_bytes, false
        );
    if !ok && text.byte_length(linked_output_path) != 0 {
        io.error("error[OPENC-COFF-LINK-SUBSET]: module selection failed\n");
    }
    DBuffer subset = d_buffer_create(selected_bytes + 1);
    if ok && records != 0 {
        usize copied_records = 0;
        usize copied_bytes = 0;
        ok = coff_module_subset(
            context, objects, module_index, subset,
            copied_records, copied_bytes, true
        ) && copied_records == records &&
            copied_bytes == selected_bytes;
        if !ok && text.byte_length(linked_output_path) != 0 {
            io.error("error[OPENC-COFF-LINK-COPY]: module copy failed\n");
        }
    }
    if ok && records != 0 {
        usize exports = 0;
        usize relocations = 0;
        DBuffer object = native_build_coff_object(
            context, subset, exports, relocations, true, true
        );
        ok = object.ok;
        if !ok && text.byte_length(linked_output_path) != 0 {
            io.error("error[OPENC-COFF-LINK-COFF]: object writer failed\n");
        }
        DBuffer object_hash = d_buffer_create(65);
        if ok {
            winmd_sha256_hex(object.data, object.length, object_hash);
            status written = file.write_bytes(
                d_buffer_text(object_path), object.data, object.length
            );
            ok = written.ok && object_hash.ok;
            if !ok && text.byte_length(linked_output_path) != 0 {
                io.error("error[OPENC-COFF-LINK-FILE]: object write failed\n");
            }
        }
        if ok && text.byte_length(linked_output_path) != 0 {
            ok = coff_link_append_published_object(
                bundle, d_buffer_text(object_path),
                d_buffer_text(object_hash), object.length
            );
            if !ok {
                io.error("error[OPENC-COFF-LINK-READBACK]: saved object rejected\n");
            }
        }
        if ok {
            if !first_entry { d_put(manifest, ",\n"); }
            d_put(manifest, "    {\"module\": ");
            cli_json_text(manifest, module_name);
            d_put(manifest, ", \"object\": ");
            cli_json_text(manifest, d_buffer_text(object_path));
            d_put(manifest, ", \"sha256\": ");
            cli_json_text(manifest, d_buffer_text(object_hash));
            d_put(manifest, ", \"functions\": ");
            d_put_usize(manifest, records);
            d_put(manifest, "}");
            ok = manifest.ok;
            wrote_entry = ok;
        }
        d_buffer_destroy(object_hash);
        d_buffer_destroy(object);
    }
    d_buffer_destroy(subset);
    d_buffer_destroy(object_path);
    if !ok && text.byte_length(linked_output_path) != 0 {
        io.error("error[OPENC-COFF-LINK-OBJECT]: module object emission failed\n");
    }
    return ok;
}

unsafe status coff_module_emit_manifest(
    ref IrContext context,
    ref DBuffer objects,
    text prefix,
    ptr byte order,
    text manifest_path,
    text linked_output_path
) {
    status failed = status{ code = 1 };
    DBuffer manifest = d_buffer_create(
        context.modules.length * (text.byte_length(prefix) + 8192) + 4096
    );
    d_put(manifest, "{\n  \"schema\": \"openc.module_coff_set.v1\",\n");
    d_put(manifest, "  \"status\": \"COMPLETE\",\n");
    d_put(manifest, "  \"target\": \"windows-x86_64-llp64\",\n");
    d_put(manifest, "  \"modules\": [\n");
    DBuffer bundle = DBuffer{
        data = null, length = 0, capacity = 0, ok = true
    };
    if text.byte_length(linked_output_path) != 0 {
        bundle = d_buffer_create(1024);
    }
    usize ordinal = 0;
    usize emitted = 0;
    bool ok = true;
    while ordinal < context.modules.length && ok {
        usize module_index = read_usize(
            order, ordinal * size_of(usize)
        );
        bool wrote_entry = false;
        ok = coff_write_one_module(
            context, objects, module_index, prefix,
            manifest, emitted == 0, wrote_entry,
            bundle, linked_output_path
        );
        if wrote_entry { emitted = emitted + 1; }
        ordinal = ordinal + 1;
    }
    d_put(manifest, "\n  ]\n}\n");
    if ok && text.byte_length(linked_output_path) != 0 {
        status linked = coff_link_module_bundle(
            context, objects, bundle, linked_output_path
        );
        ok = linked.ok;
    }
    if ok && manifest.ok {
        failed = file.write_text(
            manifest_path, d_buffer_text(manifest)
        );
    }
    d_buffer_destroy(manifest);
    if bundle.data != null { d_buffer_destroy(bundle); }
    if !ok { io.error("error[OPENC-MODULE-COFF]: emission failed\n"); }
    return failed;
}

unsafe status native_write_module_coff_set(
    ref IrContext context,
    ref DBuffer objects,
    text prefix,
    text linked_output_path
) {
    status failed = status{ code = 1 };
    if context.modules.length == 0 || context.modules.length > 64 ||
        text.byte_length(prefix) > 4096 ||
        objects.length > 67108864 ||
        (text.byte_length(linked_output_path) != 0 &&
            (objects.length > 4194304 ||
                text.byte_length(linked_output_path) > 4096)) {
        io.error("error[OPENC-MODULE-COFF-BUDGET]: module set exceeds limits\n");
        return failed;
    }
    ptr byte order = memory.alloc(
        (context.modules.length + 1) * size_of(usize)
    );
    scope memory.free(order);
    PackedBuffer modules = context.modules;
    interface_sorted_modules(
        context.project_source, context.module_data,
        modules, order
    );
    if !coff_module_names_valid(context, order) {
        io.error("error[OPENC-MODULE-COFF-NAME]: invalid or duplicate module name\n");
        return failed;
    }
    DBuffer manifest_path = d_buffer_create(text.byte_length(prefix) + 20);
    d_put(manifest_path, prefix);
    d_put(manifest_path, ".modules.json");
    if d_buffer_text(manifest_path) == linked_output_path &&
        text.byte_length(linked_output_path) != 0 {
        io.error("error[OPENC-COFF-LINK-PATH]: linked output collides with manifest\n");
        d_buffer_destroy(manifest_path);
        return failed;
    }
    status invalidated = status{ code = 1 };
    if manifest_path.ok {
        invalidated = file.write_text(
            d_buffer_text(manifest_path),
            "{\"schema\":\"openc.module_coff_set.v1\",\"status\":\"INCOMPLETE\"}\n"
        );
    }
    if invalidated.ok {
        failed = coff_module_emit_manifest(
            context, objects, prefix, order,
            d_buffer_text(manifest_path), linked_output_path
        );
    } else {
        io.error("error[OPENC-MODULE-COFF-MANIFEST]: could not invalidate output set\n");
    }
    d_buffer_destroy(manifest_path);
    return failed;
}
