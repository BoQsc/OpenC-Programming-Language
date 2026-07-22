import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

text syntax_kind_name(usize kind) {
    if kind == 0 { return "source_unit"; }
    if kind == 1 { return "import_decl"; }
    if kind == 2 { return "function_decl"; }
    if kind == 3 { return "struct_decl"; }
    if kind == 4 { return "resource_decl"; }
    if kind == 5 { return "enum_decl"; }
    if kind == 6 { return "enum_item"; }
    if kind == 7 { return "module_const_decl"; }
    if kind == 8 { return "when_decl"; }
    if kind == 9 { return "field_decl"; }
    if kind == 10 { return "parameter"; }
    if kind == 11 { return "block"; }
    if kind == 12 { return "local_decl"; }
    if kind == 13 { return "expression_stmt"; }
    if kind == 14 { return "if_stmt"; }
    if kind == 15 { return "while_stmt"; }
    if kind == 16 { return "for_stmt"; }
    if kind == 17 { return "switch_stmt"; }
    if kind == 18 { return "switch_case"; }
    if kind == 19 { return "default_case"; }
    if kind == 20 { return "break_stmt"; }
    if kind == 21 { return "continue_stmt"; }
    if kind == 22 { return "return_stmt"; }
    if kind == 23 { return "scope_stmt"; }
    if kind == 24 { return "unsafe_stmt"; }
    if kind == 25 { return "when_stmt"; }
    if kind == 26 { return "type_ref"; }
    if kind == 27 { return "qualified_name"; }
    if kind == 28 { return "identifier"; }
    if kind == 29 { return "integer_literal"; }
    if kind == 30 { return "float_literal"; }
    if kind == 31 { return "text_literal"; }
    if kind == 32 { return "bool_literal"; }
    if kind == 33 { return "null_literal"; }
    if kind == 34 { return "none_literal"; }
    if kind == 35 { return "unary_expr"; }
    if kind == 36 { return "binary_expr"; }
    if kind == 37 { return "assignment_expr"; }
    if kind == 38 { return "call_expr"; }
    if kind == 39 { return "member_expr"; }
    if kind == 40 { return "index_expr"; }
    if kind == 41 { return "range_expr"; }
    if kind == 42 { return "cast_expr"; }
    if kind == 43 { return "reinterpret_expr"; }
    if kind == 44 { return "construct_expr"; }
    if kind == 45 { return "destroy_expr"; }
    if kind == 46 { return "type_query_expr"; }
    if kind == 47 { return "status_initializer"; }
    if kind == 48 { return "aggregate_initializer"; }
    if kind == 49 { return "aggregate_field"; }
    if kind == 50 { return "array_initializer"; }
    if kind == 51 { return "out_argument"; }
    return "missing";
}

unsafe void emit_syntax_records(
    ptr byte data,
    ref PackedBuffer syntax
) {
    usize record = 0;
    while record < syntax.length {
        io.print("NODE ");
        io.print(syntax_kind_name(read_record_field(data, record, 0)));
        io.print(" ");
        io.print(read_record_field(data, record, 1));
        io.print(" ");
        io.println(read_record_field(data, record, 2));
        record = record + 1;
    }
}

unsafe NodeResult parse_source_syntax(
    text source,
    ptr byte token_data,
    ref PackedBuffer tokens,
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    ptr byte diagnostic_data,
    ref PackedBuffer diagnostics
) {
    ParserContext context = ParserContext{
        source = source,
        token_data = token_data,
        token_count = tokens.length,
        syntax_data = syntax_data,
        syntax_length = syntax.length,
        syntax_capacity = syntax.capacity,
        diagnostic_data = diagnostic_data,
        diagnostic_length = diagnostics.length,
        diagnostic_capacity = diagnostics.capacity,
        cursor = 0,
        function_depth = 0,
        loop_depth = 0,
        unsafe_depth = 0,
        allow_aggregate_initializer = true
    };
    usize first = current_token(context);
    NodeResult root = make_node(
        context, 0,
        token_start(context, first), token_length(context, first)
    );
    while parser_match(context, "import") {
        parse_import(context, previous_token(context));
    }
    while !parser_at_end(context) {
        usize before = context.cursor;
        NodeResult declaration = parse_top_declaration(context);
        if declaration.kind == 0 { parser_synchronize_top(context); }
        parser_ensure_progress(context, before);
    }
    usize end = current_token(context);
    set_node_combined(
        context, root,
        token_start(context, first),
        token_start(context, end), token_length(context, end)
    );
    syntax.length = context.syntax_length;
    diagnostics.length = context.diagnostic_length;
    return root;
}
