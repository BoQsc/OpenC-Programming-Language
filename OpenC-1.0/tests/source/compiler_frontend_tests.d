module tests.compiler_frontend_tests;

import openc.ast : AstArena, NodeKind;
import openc.compiler : CompilationOptions, Compiler;
import openc.common : canonicalSourceExtension;
import openc.diagnostic : DiagnosticEngine;
import openc.lexer : Lexer;
import openc.parser : Parser;
import openc.project : ProjectConfig;
import openc.source : SourceManager;
import std.conv : to;
import std.file : exists, remove, tempDir, write;
import std.path : buildPath;
import std.process : thisProcessID;
import std.typecons : tuple;

private auto parse(string source) {
    auto sources = new SourceManager();
    auto id = sources.addVirtual("test", source);
    auto diagnostics = new DiagnosticEngine();
    auto tokens = new Lexer(sources.get(id), diagnostics).lex();
    auto parsed = new Parser(tokens, diagnostics, new AstArena()).parse();
    return tuple(parsed, diagnostics);
}

private auto compileSource(string source, string suffix) {
    auto path = buildPath(tempDir(), "openc-frontend-" ~ suffix ~ "-" ~ thisProcessID.to!string);
    scope (exit) if (exists(path)) remove(path);
    write(path, source);
    auto options = CompilationOptions();
    options.stopAfterCheck = true;
    return new Compiler().compile(ProjectConfig.singleSource(path), options);
}

unittest {
    assert(canonicalSourceExtension == ".p");
}

unittest {
    auto result = parse("i32 main() { return 0; }");
    assert(result[0].root !is null);
    assert(result[0].root.kind == NodeKind.sourceUnit);
    assert(!result[1].hasErrors());
}

unittest {
    auto compiled = compileSource(
        "import system.io; struct P{i32 x;} " ~
        "void set(ref P p){p=P{x=2};} " ~
        "i32 main(){P p=P{x=1};set(p);optional P value=p;" ~
        "if value.present {system.io.print(value.value.x);return value.value.x;}return 0;}",
        "contexts");
    assert(compiled.ok);
    assert(compiled.value.success());
}

unittest {
    auto compiled = compileSource(
        "struct P{i32 x;} i32 main(){storage P s;" ~
        "ref P a=construct(s,P{x=1});ref P b=construct(s,P{x=2});return a.x+b.x;}",
        "storage-double");
    assert(compiled.ok);
    assert(!compiled.value.success());
    bool found;
    foreach (diagnostic; compiled.value.diagnostics.all()) {
        if (diagnostic.rule == "OPENC-CONSTRUCT-DOUBLE-001") found = true;
    }
    assert(found);
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

unittest {
    auto path = buildPath(tempDir(), "openc-invalid-utf8-" ~ thisProcessID.to!string);
    scope (exit) if (exists(path)) remove(path);
    write(path, cast(ubyte[]) [0xFF, 0xFE, 0x0A]);
    auto options = CompilationOptions();
    options.stopAfterCheck = true;
    auto compiled = new Compiler().compile(ProjectConfig.singleSource(path), options);
    assert(compiled.ok);
    assert(!compiled.value.success());
    assert(compiled.value.diagnostics.all().length == 1);
    assert(compiled.value.diagnostics.all()[0].rule == "OPENC-SOURCE-INVALID-001");
}
