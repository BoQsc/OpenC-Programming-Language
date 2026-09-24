import system.file;
import system.io;
import system.memory;
import system.text;

// Experimental COFF-only spelling. The native stream still uses global IDs;
// this prepares a stable external identity, not an object-cache boundary.
unsafe bool coff_stable_add_symbol(
    ref IrContext context,
    text source,
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize symbol,
    ref DBuffer hashes,
    ptr byte offsets
) {
    usize node = read_record_field(context.detail_data, symbol, 1);
    usize name_start = read_record_field(context.symbol_data, symbol, 2);
    usize name_length = read_record_field(context.symbol_data, symbol, 3);
    if node >= syntax.length ||
        read_record_field(syntax_data, node, 0) != 2 ||
        read_record_field(syntax_data, node, 3) != name_start ||
        read_record_field(syntax_data, node, 4) != name_length {
        return false;
    }
    usize start = read_record_field(syntax_data, node, 1);
    usize length = read_record_field(syntax_data, node, 2);
    usize source_length = text.byte_length(source);
    if start > source_length || length > source_length - start {
        return false;
    }
    usize body = flow_largest_direct_block(syntax_data, syntax, node);
    if body < syntax.length {
        usize body_start = read_record_field(syntax_data, body, 1);
        if body_start >= start && body_start < start + length &&
            byte_at_or_zero(source, body_start) == 123 {
            length = body_start - start;
        }
    }
    usize module_index = read_record_field(context.detail_data, symbol, 0);
    if module_index >= context.modules.length { return false; }
    text module_name = project_slice(
        context.project_source,
        read_record_field(context.module_data, module_index, 0),
        read_record_field(context.module_data, module_index, 1)
    );
    DBuffer canonical = d_buffer_create(
        text.byte_length(module_name) + length + 128
    );
    d_put(canonical, "openc-coff-symbol-v1:windows-x86_64-llp64\n");
    d_put_usize(canonical, text.byte_length(module_name));
    d_put(canonical, ":");
    d_put(canonical, module_name);
    d_put(canonical, ":");
    d_put_usize(canonical, length);
    d_put(canonical, ":");
    d_put_slice(canonical, source, start, length);
    DBuffer digest = d_buffer_create(65);
    if canonical.ok {
        winmd_sha256_hex(canonical.data, canonical.length, digest);
    }
    bool ok = canonical.ok && digest.ok && digest.length == 64;
    if ok {
        write_usize(
            offsets, symbol * size_of(usize), hashes.length + 1
        );
        d_put(hashes, d_buffer_text(digest));
        ok = hashes.ok;
    }
    d_buffer_destroy(digest);
    d_buffer_destroy(canonical);
    return ok;
}

unsafe bool coff_stable_source(
    ref IrContext context,
    usize source_record,
    usize first_symbol_plus_one,
    ptr byte next_symbol,
    ref DBuffer hashes,
    ptr byte offsets
) {
    text source;
    status loaded = project_read_source_record(
        context.project_source, context.project_root,
        context.source_data, source_record, out source
    );
    if !loaded.ok { return false; }
    usize source_length = text.byte_length(source);
    if source_length > 131072 {
        io.error("error[OPENC-COFF-STABLE-BUDGET]: source exceeds 128 KiB\n");
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
    usize node = 0;
    while node < syntax.length {
        if read_record_field(syntax_data, node, 0) == 8 {
            io.error("error[OPENC-COFF-STABLE-UNSUPPORTED]: when_decl\n");
            return false;
        }
        node = node + 1;
    }
    usize linked = first_symbol_plus_one;
    while linked != 0 {
        usize symbol = linked - 1;
        if !coff_stable_add_symbol(
            context, source, syntax_data, syntax, symbol, hashes, offsets
        ) { return false; }
        linked = read_usize(next_symbol, symbol * size_of(usize));
    }
    return true;
}

unsafe bool coff_stable_prepare(
    ref IrContext context,
    ref DBuffer hashes,
    ptr byte offsets
) {
    if context.symbols.length > 262144 {
        io.error("error[OPENC-COFF-STABLE-BUDGET]: too many symbols\n");
        return false;
    }
    usize max_source = 0;
    usize symbol = 0;
    while symbol < context.symbols.length {
        write_usize(offsets, symbol * size_of(usize), 0);
        if read_record_field(context.symbol_data, symbol, 0) ==
            resolution_symbol_function() {
            usize function_source_record = read_record_field(
                context.symbol_data, symbol, 1
            );
            if function_source_record > max_source {
                max_source = function_source_record;
            }
        }
        symbol = symbol + 1;
    }
    if max_source > 65536 {
        io.error("error[OPENC-COFF-STABLE-BUDGET]: too many sources\n");
        return false;
    }
    ptr byte heads = memory.alloc((max_source + 2) * size_of(usize));
    scope memory.free(heads);
    ptr byte next_symbol = memory.alloc(
        (context.symbols.length + 1) * size_of(usize)
    );
    scope memory.free(next_symbol);
    usize source_record = 0;
    while source_record <= max_source {
        write_usize(heads, source_record * size_of(usize), 0);
        source_record = source_record + 1;
    }
    symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
            resolution_symbol_function() {
            source_record = read_record_field(context.symbol_data, symbol, 1);
            write_usize(
                next_symbol, symbol * size_of(usize),
                read_usize(heads, source_record * size_of(usize))
            );
            write_usize(
                heads, source_record * size_of(usize), symbol + 1
            );
        }
        symbol = symbol + 1;
    }
    source_record = 0;
    while source_record <= max_source {
        usize first = read_usize(
            heads, source_record * size_of(usize)
        );
        if first != 0 && !coff_stable_source(
            context, source_record, first, next_symbol, hashes, offsets
        ) { return false; }
        source_record = source_record + 1;
    }
    return hashes.ok;
}
