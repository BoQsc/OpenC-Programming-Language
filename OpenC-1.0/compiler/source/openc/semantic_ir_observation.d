module openc.semantic_ir_observation;

import openc.ast : AstArena, ParsedUnit;
import openc.diagnostic : DiagnosticEngine;
import openc.lexer : Lexer;
import openc.lowerer : Lowerer;
import openc.parser : Parser;
import openc.project : ProjectConfig;
import openc.semantic_pipeline : SemanticPipeline;
import openc.source : SourceId, SourceManager;
import std.stdio : stderr, stdout;

int observeSemanticIr(string path) {
    stdout.writeln("OPENC-SEMANTIC-IR-OBSERVATION 1");
    auto loaded = ProjectConfig.load(path);
    if (!loaded.ok) {
        stdout.writeln("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
        return 1;
    }
    auto project = loaded.value;
    auto sources = new SourceManager();
    auto diagnostics = new DiagnosticEngine();
    auto arena = new AstArena();
    ParsedUnit[SourceId] parsed;
    foreach (moduleConfig; project.modules) {
        foreach (sourcePath; moduleConfig.sources) {
            auto source = sources.load(sourcePath, moduleConfig.name);
            if (!source.ok) {
                stderr.writeln("openc semantic-ir-observe: " ~ source.error);
                stdout.writeln("PROJECT_ERROR OPENC-PROJECT-SOURCE-READ-001");
                return 1;
            }
        }
    }
    foreach (source; sources.all()) {
        auto tokens = new Lexer(source, diagnostics).lex();
        parsed[source.id] = new Parser(tokens, diagnostics, arena).parse();
    }
    if (diagnostics.hasErrors()) {
        stdout.writeln("FRONTEND_ERROR ", diagnostics.errors());
        return 1;
    }
    auto model = new SemanticPipeline(sources, diagnostics).run(project, parsed);
    if (diagnostics.hasErrors()) {
        stdout.writeln("SEMANTIC_ERROR ", diagnostics.errors());
        return 1;
    }
    auto program = new Lowerer(model).lower();
    stdout.writeln(program.toJson().toString());
    return 0;
}
