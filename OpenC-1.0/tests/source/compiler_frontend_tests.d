module tests.compiler_frontend_tests;

import openc.ast : AstArena, NodeKind;
import openc.diagnostic : DiagnosticEngine;
import openc.lexer : Lexer;
import openc.parser : Parser;
import openc.source : SourceManager;
import std.typecons : tuple;

private auto parse(string source) {
    auto sources = new SourceManager();
    auto id = sources.addVirtual("test", source);
    auto diagnostics = new DiagnosticEngine();
    auto tokens = new Lexer(sources.get(id), diagnostics).lex();
    auto parsed = new Parser(tokens, diagnostics, new AstArena()).parse();
    return tuple(parsed, diagnostics);
}

unittest {
    auto result = parse("i32 main() { return 0; }");
    assert(result[0].root !is null);
    assert(result[0].root.kind == NodeKind.sourceUnit);
    assert(!result[1].hasErrors());
}

unittest {
    auto result = parse("struct Point { i32 x; i32 y; } i32 main() { Point p = Point{ x = 1, y = 2 }; return p.x; }");
    assert(result[0].complete);
    assert(!result[1].hasErrors());
}

unittest {
    auto result = parse("i32* pointer;");
    assert(result[1].hasErrors());
}

unittest {
    auto result = parse("when target.os == \"linux\" { i32 value() { return 1; } }");
    assert(result[0].root !is null);
    assert(!result[1].hasErrors());
}
