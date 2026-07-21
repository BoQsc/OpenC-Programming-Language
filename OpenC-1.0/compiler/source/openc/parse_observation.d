module openc.parse_observation;

import openc.ast : AstArena;
import openc.diagnostic : DiagnosticEngine;
import openc.lexer : Lexer;
import openc.parser : Parser;
import openc.source : SourceManager;
import std.stdio : stderr, stdout;
import std.string : startsWith;

int observeParsing(string path) {
    auto sources = new SourceManager();
    auto loaded = sources.load(path, path);
    if (!loaded.ok) {
        if (loaded.error.startsWith("source file is not valid UTF-8:")) {
            stdout.writeln("OPENC-PARSE-OBSERVATION 1");
            stdout.writeln("SOURCE_ERROR OPENC-SOURCE-INVALID-001 0 0 1 1");
            stdout.writeln("SUMMARY 0 1");
            return 1;
        }
        stderr.writeln("openc parse-observe: " ~ loaded.error);
        return 2;
    }

    auto source = sources.get(loaded.value);
    auto diagnostics = new DiagnosticEngine();
    auto tokens = new Lexer(source, diagnostics).lex();
    auto arena = new AstArena();
    new Parser(tokens, diagnostics, arena).parse();

    stdout.writeln("OPENC-PARSE-OBSERVATION 1");
    foreach (node; arena.all()) {
        stdout.writeln(
            "NODE ", cast(string) node.kind, " ",
            node.span.start, " ", node.span.length,
        );
    }
    foreach (diagnostic; diagnostics.all()) {
        const position = source.position(diagnostic.span.start);
        stdout.writeln(
            "ERROR ", diagnostic.rule, " ",
            diagnostic.span.start, " ", diagnostic.span.length, " ",
            position.line, " ", position.column,
        );
    }
    stdout.writeln("SUMMARY ", arena.all().length, " ", diagnostics.errors());
    return diagnostics.hasErrors() ? 1 : 0;
}
