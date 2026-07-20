module openc.lex_observation;

import openc.diagnostic : DiagnosticEngine;
import openc.lexer : Lexer;
import openc.source : SourceManager;
import openc.token : TokenKind;
import std.stdio : stderr, stdout;
import std.string : startsWith;

int observeLexing(string path) {
    auto sources = new SourceManager();
    auto loaded = sources.load(path, path);
    if (!loaded.ok) {
        if (loaded.error.startsWith("source file is not valid UTF-8:")) {
            stdout.writeln("OPENC-LEX-OBSERVATION 2");
            stdout.writeln("SOURCE_ERROR OPENC-SOURCE-INVALID-001 0 0 1 1");
            stdout.writeln("SUMMARY 0 1");
            return 1;
        }
        stderr.writeln("openc lex-observe: " ~ loaded.error);
        return 2;
    }

    auto source = sources.get(loaded.value);
    auto diagnostics = new DiagnosticEngine();
    auto tokens = new Lexer(source, diagnostics).lex();

    stdout.writeln("OPENC-LEX-OBSERVATION 2");
    foreach (token; tokens) {
        const position = source.position(token.span.start);
        stdout.writeln(
            "TOKEN ", kindCode(token.kind), " ",
            token.span.start, " ", token.span.length, " ",
            position.line, " ", position.column,
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
    stdout.writeln("SUMMARY ", tokens.length, " ", diagnostics.errors());
    return diagnostics.hasErrors() ? 1 : 0;
}

private int kindCode(TokenKind kind) {
    final switch (kind) {
        case TokenKind.eofToken: return 0;
        case TokenKind.identifier: return 1;
        case TokenKind.integerLiteral: return 2;
        case TokenKind.floatLiteral: return 3;
        case TokenKind.textLiteral: return 4;
        case TokenKind.keyword: return 5;
        case TokenKind.symbol: return 6;
    }
}
