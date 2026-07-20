module openc.ast;

import openc.common : NodeId;
import openc.source : SourceSpan;
import std.json : JSONValue;

enum NodeKind : string {
    sourceUnit = "source_unit",
    importDecl = "import_decl",
    functionDecl = "function_decl",
    structDecl = "struct_decl",
    resourceDecl = "resource_decl",
    enumDecl = "enum_decl",
    enumItem = "enum_item",
    moduleConstDecl = "module_const_decl",
    whenDecl = "when_decl",
    fieldDecl = "field_decl",
    parameter = "parameter",
    block = "block",
    localDecl = "local_decl",
    expressionStmt = "expression_stmt",
    ifStmt = "if_stmt",
    whileStmt = "while_stmt",
    forStmt = "for_stmt",
    switchStmt = "switch_stmt",
    switchCase = "switch_case",
    defaultCase = "default_case",
    breakStmt = "break_stmt",
    continueStmt = "continue_stmt",
    returnStmt = "return_stmt",
    scopeStmt = "scope_stmt",
    unsafeStmt = "unsafe_stmt",
    whenStmt = "when_stmt",
    typeRef = "type_ref",
    qualifiedName = "qualified_name",
    identifier = "identifier",
    integerLiteral = "integer_literal",
    floatLiteral = "float_literal",
    textLiteral = "text_literal",
    boolLiteral = "bool_literal",
    nullLiteral = "null_literal",
    noneLiteral = "none_literal",
    unaryExpr = "unary_expr",
    binaryExpr = "binary_expr",
    assignmentExpr = "assignment_expr",
    callExpr = "call_expr",
    memberExpr = "member_expr",
    indexExpr = "index_expr",
    rangeExpr = "range_expr",
    castExpr = "cast_expr",
    reinterpretExpr = "reinterpret_expr",
    constructExpr = "construct_expr",
    destroyExpr = "destroy_expr",
    typeQueryExpr = "type_query_expr",
    statusInitializer = "status_initializer",
    aggregateInitializer = "aggregate_initializer",
    aggregateField = "aggregate_field",
    arrayInitializer = "array_initializer",
    outArgument = "out_argument",
    missing = "missing"
}

final class AstNode {
    NodeId id;
    NodeKind kind;
    SourceSpan span;
    string text;
    AstNode[] children;
    string[string] attributes;

    this(NodeId id, NodeKind kind, SourceSpan span, string text = "") {
        this.id = id;
        this.kind = kind;
        this.span = span;
        this.text = text;
    }

    AstNode add(AstNode child) {
        if (child !is null) children ~= child;
        return this;
    }

    AstNode set(string key, string value) {
        attributes[key] = value;
        return this;
    }

    string get(string key, string fallback = "") const {
        auto found = key in attributes;
        return found is null ? fallback : *found;
    }

    bool flag(string key) const {
        return get(key) == "true";
    }

    JSONValue toJson() const {
        JSONValue result;
        result["id"] = id;
        result["kind"] = cast(string) kind;
        result["text"] = text;
        result["source"] = span.source.value;
        result["start"] = span.start;
        result["length"] = span.length;
        JSONValue attrs;
        foreach (key, value; attributes) attrs[key] = value;
        result["attributes"] = attrs;
        JSONValue[] childJson;
        foreach (child; children) childJson ~= child.toJson();
        result["children"] = JSONValue(childJson);
        return result;
    }
}

final class AstArena {
private:
    NodeId nextId;

public:
    AstNode make(NodeKind kind, SourceSpan span, string text = "") {
        return new AstNode(nextId++, kind, span, text);
    }
}

struct ParsedUnit {
    AstNode root;
    bool complete;
}
