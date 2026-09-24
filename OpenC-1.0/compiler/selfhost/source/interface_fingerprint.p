import system.file;
import system.io;
import system.memory;
import system.text;

// This is a conservative textual ABI projection, not a cache key yet.
// Exact declaration spelling is intentional: whitespace can cause a safe
// extra invalidation, while same-width renames must never be invisible.
unsafe bool interface_append_source(
    ref DBuffer canonical,
    text project_source,
    text project_root,
    ptr byte source_data,
    usize source_record,
    ref bool unsupported_when,
    ref usize declarations
) {
    text source;
    status loaded = project_read_source_record(
        project_source, project_root, source_data, source_record, out source
    );
    if !loaded.ok { return false; }
    usize source_length = text.byte_length(source);
    if source_length > 131072 {
        io.error("error[OPENC-INTERFACE-BUDGET]: source file exceeds 128 KiB\n");
        return false;
    }
    PackedBuffer tokens = PackedBuffer{
        length = 0, capacity = source_length + 2
    };
    PackedBuffer diagnostics = PackedBuffer{
        length = 0, capacity = source_length * 4 + 8
    };
    ptr byte token_data = memory.alloc(tokens.capacity * record_stride());
    scope memory.free(token_data);
    ptr byte diagnostic_data = memory.alloc(
        diagnostics.capacity * record_stride()
    );
    scope memory.free(diagnostic_data);
    lex_source(source, token_data, tokens, diagnostic_data, diagnostics);
    PackedBuffer syntax = PackedBuffer{
        length = 0, capacity = tokens.length * 6 + 8
    };
    ptr byte syntax_data = memory.alloc(syntax.capacity * record_stride());
    scope memory.free(syntax_data);
    parse_source_syntax(
        source, token_data, tokens, syntax_data, syntax,
        diagnostic_data, diagnostics
    );
    if diagnostics.length != 0 { return false; }
    usize local_declarations = 0;
    usize node = 0;
    while node < syntax.length {
        usize kind = read_record_field(syntax_data, node, 0);
        if kind == 8 { unsupported_when = true; }
        if kind == 2 || kind == 3 || kind == 4 || kind == 5 ||
            kind == 7 || kind == 8 {
            usize start = read_record_field(syntax_data, node, 1);
            usize length = read_record_field(syntax_data, node, 2);
            usize name_start = read_record_field(syntax_data, node, 3);
            usize name_length = read_record_field(syntax_data, node, 4);
            if start > source_length || length > source_length - start ||
                name_start > source_length ||
                name_length > source_length - name_start {
                return false;
            }
            if kind == 2 {
                usize body = flow_largest_direct_block(
                    syntax_data, syntax, node
                );
                if body < syntax.length {
                    usize body_start = read_record_field(
                        syntax_data, body, 1
                    );
                    if body_start >= start && body_start < start + length &&
                        byte_at_or_zero(source, body_start) == 123 {
                        length = body_start - start;
                    }
                }
            }
            bool exported = semantic_prefix_has(
                source, token_data, tokens, start, name_start, "export"
            );
            d_put(canonical, "decl:");
            d_put_usize(canonical, kind);
            d_put(canonical, ":");
            if exported { d_put(canonical, "1:"); }
            else { d_put(canonical, "0:"); }
            d_put_usize(canonical, name_length);
            d_put(canonical, ":");
            d_put_slice(canonical, source, name_start, name_length);
            d_put(canonical, ":");
            d_put_usize(canonical, length);
            d_put(canonical, ":");
            d_put_slice(canonical, source, start, length);
            d_put(canonical, "\n");
            local_declarations = local_declarations + 1;
        }
        node = node + 1;
    }
    declarations = local_declarations;
    return canonical.ok;
}

unsafe text interface_module_name(
    text project_source,
    ptr byte module_data,
    usize module_index
) {
    return project_slice(
        project_source,
        read_record_field(module_data, module_index, 0),
        read_record_field(module_data, module_index, 1)
    );
}

unsafe bool interface_name_before_or_equal(text left, text right) {
    usize left_length = text.byte_length(left);
    usize right_length = text.byte_length(right);
    usize cursor = 0;
    while cursor < left_length && cursor < right_length {
        u8 left_byte = byte_at_or_zero(left, cursor);
        u8 right_byte = byte_at_or_zero(right, cursor);
        if left_byte < right_byte { return true; }
        if left_byte > right_byte { return false; }
        cursor = cursor + 1;
    }
    return left_length <= right_length;
}

// Project-object key order is not an interface fact. Keep the emitted module
// order and every import adjacency list lexical, independent of manifest order.
unsafe void interface_sorted_modules(
    text project_source,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte order
) {
    usize index = 0;
    while index < modules.length {
        write_usize(order, index * size_of(usize), index);
        index = index + 1;
    }
    index = 1;
    while index < modules.length {
        usize selected = read_usize(order, index * size_of(usize));
        text selected_name = interface_module_name(
            project_source, module_data, selected
        );
        usize at = index;
        while at > 0 {
            usize previous = read_usize(
                order, (at - 1) * size_of(usize)
            );
            text previous_name = interface_module_name(
                project_source, module_data, previous
            );
            if interface_name_before_or_equal(
                previous_name, selected_name
            ) { break; }
            write_usize(order, at * size_of(usize), previous);
            at = at - 1;
        }
        write_usize(order, at * size_of(usize), selected);
        index = index + 1;
    }
}

unsafe bool interface_fingerprint_write(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    text report_path,
    usize total_source_length,
    usize symbol_count
) {
    if total_source_length > 33554432 ||
        text.byte_length(project_source) > 1048576 ||
        modules.length > 4096 || symbol_count > 262144 {
        io.error("error[OPENC-INTERFACE-BUDGET]: project exceeds projection limits\n");
        return false;
    }
    DBuffer canonical = d_buffer_create(
        total_source_length + symbol_count * 96 + 65536
    );
    DBuffer project_canonical = d_buffer_create(
        text.byte_length(project_source) + modules.length * 256 + 4096
    );
    DBuffer report = d_buffer_create(
        text.byte_length(project_source) * 4 + modules.length * 512 + 4096
    );
    ptr byte order = memory.alloc((modules.length + 1) * size_of(usize));
    scope memory.free(order);
    interface_sorted_modules(project_source, module_data, modules, order);
    d_put(report, "{\n  \"schema\": \"openc.interface_fingerprint.v1\",\n");
    d_put(report, "  \"target\": \"windows-x86_64-llp64\",\n");
    d_put(report, "  \"modules\": [\n");
    bool supported = true;
    usize module_ordinal = 0;
    while module_ordinal < modules.length {
        usize module_index = read_usize(
            order, module_ordinal * size_of(usize)
        );
        canonical.length = 0;
        d_put(canonical, "openc-interface-v1:windows-x86_64-llp64\n");
        text module_name = interface_module_name(
            project_source, module_data, module_index
        );
        d_put(canonical, "module:");
        d_put_usize(canonical, text.byte_length(module_name));
        d_put(canonical, ":");
        d_put(canonical, module_name);
        d_put(canonical, "\n");
        if module_ordinal != 0 { d_put(report, ",\n"); }
        d_put(report, "    {\"name\": ");
        cli_json_text(report, module_name);
        d_put(report, ", \"imports\": [");
        usize dependency_ordinal = 0;
        usize import_count = 0;
        while dependency_ordinal < modules.length {
            usize dependency = read_usize(
                order, dependency_ordinal * size_of(usize)
            );
            if acceptance_module_imports(
                    project_source, project_root, module_data, source_data,
                    module_index, dependency
                ) {
                text import_name = interface_module_name(
                    project_source, module_data, dependency
                );
                if import_count != 0 { d_put(report, ", "); }
                cli_json_text(report, import_name);
                d_put(canonical, "import:");
                d_put_usize(canonical, text.byte_length(import_name));
                d_put(canonical, ":");
                d_put(canonical, import_name);
                d_put(canonical, "\n");
                import_count = import_count + 1;
            }
            dependency_ordinal = dependency_ordinal + 1;
        }
        d_put(report, "], \"declarations\": ");
        usize declarations = 0;
        bool unsupported_when = false;
        usize first = read_record_field(module_data, module_index, 2);
        usize count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < count {
            usize source_declarations = 0;
            if !interface_append_source(
                canonical, project_source, project_root, source_data,
                first + source_index, unsupported_when, source_declarations
            ) {
                d_buffer_destroy(canonical);
                d_buffer_destroy(project_canonical);
                d_buffer_destroy(report);
                return false;
            }
            declarations = declarations + source_declarations;
            source_index = source_index + 1;
        }
        d_put_usize(report, declarations);
        DBuffer digest = d_buffer_create(65);
        winmd_sha256_hex(canonical.data, canonical.length, digest);
        d_put(report, ", \"sha256\": ");
        cli_json_text(report, d_buffer_text(digest));
        d_put(report, ", \"supported\": ");
        if unsupported_when {
            d_put(report, "false, \"unsupported_kinds\": [\"when_decl\"]}");
            supported = false;
        } else {
            d_put(report, "true, \"unsupported_kinds\": []}");
        }
        d_put(project_canonical, module_name);
        d_put(project_canonical, ":");
        d_put(project_canonical, d_buffer_text(digest));
        d_put(project_canonical, "\n");
        d_buffer_destroy(digest);
        module_ordinal = module_ordinal + 1;
    }
    DBuffer project_digest = d_buffer_create(65);
    winmd_sha256_hex(
        project_canonical.data, project_canonical.length, project_digest
    );
    d_put(report, "\n  ],\n  \"project_sha256\": ");
    cli_json_text(report, d_buffer_text(project_digest));
    d_put(report, ",\n  \"supported\": ");
    if supported { d_put(report, "true\n}\n"); }
    else { d_put(report, "false\n}\n"); }
    status written = status{ code = 1 };
    if canonical.ok && project_canonical.ok && report.ok &&
        project_digest.ok {
        written = file.write_text(report_path, d_buffer_text(report));
    }
    d_buffer_destroy(project_digest);
    d_buffer_destroy(canonical);
    d_buffer_destroy(project_canonical);
    d_buffer_destroy(report);
    if !supported {
        io.error("error[OPENC-INTERFACE-UNSUPPORTED]: when_decl\n");
    }
    return written.ok && supported;
}
