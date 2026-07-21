module openc.semantic_declaration_observation;

import openc.ast : AstArena, NodeKind, ParsedUnit;
import openc.common : SymbolId;
import openc.declarations : DeclarationCollector;
import openc.diagnostic : DiagnosticEngine, DiagnosticPhase;
import openc.lexer : Lexer;
import openc.module_system : ModuleComposer;
import openc.parser : Parser;
import openc.project : ProjectConfig;
import openc.semantic_model : SemanticModel;
import openc.source : SourceId, SourceManager;
import openc.symbol : Symbol, SymbolKind;
import std.stdio : stderr, stdout;

private struct UnitLocation {
    size_t moduleIndex;
    size_t sourceIndex;
}

int observeSemanticDeclarations(string path) {
    stdout.writeln("OPENC-SEMANTIC-DECL-OBSERVATION 1");
    auto loaded = ProjectConfig.load(path);
    if (!loaded.ok) {
        stdout.writeln("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
        stdout.writeln("SUMMARY 0 0 0 0 0 0 1");
        return 1;
    }

    auto project = loaded.value;
    auto sources = new SourceManager();
    auto diagnostics = new DiagnosticEngine();
    auto arena = new AstArena();
    ParsedUnit[SourceId] parsed;
    UnitLocation[SourceId] locations;

    foreach (moduleIndex, moduleConfig; project.modules) {
        stdout.write("MODULE ", moduleIndex, " ");
        writeHex(moduleConfig.name);
        stdout.writeln(" ", moduleConfig.sources.length);
        foreach (sourceIndex, sourcePath; moduleConfig.sources) {
            auto source = sources.load(sourcePath, moduleConfig.name);
            if (!source.ok) {
                stderr.writeln("openc semantic-decl-observe: " ~ source.error);
                stdout.writeln("PROJECT_ERROR OPENC-PROJECT-SOURCE-READ-001 ", moduleIndex, " ", sourceIndex);
                stdout.writeln("SUMMARY ", project.modules.length, " 0 0 0 0 0 1");
                return 1;
            }
            locations[source.value] = UnitLocation(moduleIndex, sourceIndex);
        }
    }

    foreach (source; sources.all()) {
        auto tokens = new Lexer(source, diagnostics).lex();
        parsed[source.id] = new Parser(tokens, diagnostics, arena).parse();
    }
    if (diagnostics.hasErrors()) {
        stdout.writeln("FRONTEND_ERROR ", diagnostics.errors());
        stdout.writeln("SUMMARY ", project.modules.length, " ", sources.count(), " 0 0 0 0 ", diagnostics.errors());
        return 1;
    }

    auto graph = new ModuleComposer(diagnostics).compose(project, parsed, sources);
    if (diagnostics.hasErrors()) {
        stdout.writeln("FRONTEND_ERROR ", diagnostics.errors());
        stdout.writeln("SUMMARY ", project.modules.length, " ", sources.count(), " 0 0 0 0 ", diagnostics.errors());
        return 1;
    }
    auto model = new SemanticModel(graph, project.target);
    new DeclarationCollector(model, diagnostics).collect();

    size_t declarationCount;
    size_t parameterCount;
    size_t fieldCount;
    size_t itemCount;
    foreach (symbol; model.symbols.symbols) {
        if (!topLevelUserDeclaration(symbol)) continue;
        auto location = locations[symbol.span.source];
        stdout.write(
            "DECL ", declarationCount, " ", location.moduleIndex, " ",
            location.sourceIndex, " ", cast(string) symbol.kind, " ",
            cast(string) symbol.visibility, " ",
        );
        writeHex(symbol.name);
        stdout.write(" ", symbol.span.start, " ", symbol.span.length, " ");
        writeHex(model.types.get(symbol.type).display(model.types));
        stdout.writeln(
            " ", symbol.declaration.flag("unsafe") ? 1 : 0,
            " ", symbol.declaration.flag("own_result") ? 1 : 0,
            " ", symbol.resource ? 1 : 0,
        );

        if (symbol.kind == SymbolKind.functionSymbol) {
            size_t parameterIndex;
            foreach (child; symbol.declaration.children[1 .. $]) {
                if (child.kind != NodeKind.parameter) continue;
                stdout.write(
                    "PARAM ", declarationCount, " ", parameterIndex, " ",
                    symbol.signature.modes[parameterIndex], " ",
                );
                writeHex(child.text);
                stdout.write(" ", child.span.start, " ", child.span.length, " ");
                writeHex(model.types.get(symbol.signature.parameters[parameterIndex]).display(model.types));
                stdout.writeln();
                ++parameterIndex;
                ++parameterCount;
            }
        } else if (symbol.kind == SymbolKind.structSymbol || symbol.kind == SymbolKind.resourceSymbol) {
            size_t memberIndex;
            foreach (child; symbol.declaration.children) {
                if (child.kind != NodeKind.fieldDecl) continue;
                auto field = model.symbols.get(model.nodeSymbols[child.id]);
                stdout.write("FIELD ", declarationCount, " ", memberIndex, " ");
                writeHex(field.name);
                stdout.write(" ", field.span.start, " ", field.span.length, " ");
                writeHex(model.types.get(field.type).display(model.types));
                stdout.writeln(" ", field.resource ? 1 : 0);
                ++memberIndex;
                ++fieldCount;
            }
        } else if (symbol.kind == SymbolKind.enumSymbol) {
            size_t memberIndex;
            foreach (child; symbol.declaration.children) {
                if (child.kind != NodeKind.enumItem) continue;
                auto item = model.symbols.get(model.nodeSymbols[child.id]);
                stdout.write("ITEM ", declarationCount, " ", memberIndex, " ");
                writeHex(item.name);
                stdout.write(" ", item.span.start, " ", item.span.length, " ");
                writeHex(model.types.get(item.type).display(model.types));
                stdout.writeln();
                ++memberIndex;
                ++itemCount;
            }
        }
        ++declarationCount;
    }

    foreach (id; 0 .. model.types.length) {
        auto type = model.types.get(id);
        stdout.write("TYPE ", id, " ", cast(string) type.kind, " ");
        writeHex(type.display(model.types));
        stdout.writeln(
            " ", type.element, " ", type.length, " ", type.bits,
            " ", type.constQualified ? 1 : 0,
            " ", type.resource ? 1 : 0,
        );
    }

    size_t declarationErrors;
    foreach (diagnostic; diagnostics.all()) {
        if (diagnostic.phase != DiagnosticPhase.declaration) continue;
        auto location = locations[diagnostic.span.source];
        stdout.writeln(
            "ERROR ", diagnostic.rule, " ", location.moduleIndex, " ",
            location.sourceIndex, " ", diagnostic.span.start, " ", diagnostic.span.length,
        );
        ++declarationErrors;
    }
    stdout.writeln(
        "SUMMARY ", project.modules.length, " ", sources.count(), " ",
        declarationCount, " ", parameterCount, " ", fieldCount, " ",
        itemCount, " ", declarationErrors,
    );
    return declarationErrors == 0 ? 0 : 1;
}

private bool topLevelUserDeclaration(Symbol symbol) {
    if (symbol.declaration is null || symbol.scopeId != 0) return false;
    return symbol.kind == SymbolKind.functionSymbol ||
        symbol.kind == SymbolKind.structSymbol ||
        symbol.kind == SymbolKind.resourceSymbol ||
        symbol.kind == SymbolKind.enumSymbol ||
        symbol.kind == SymbolKind.constantSymbol;
}

private void writeHex(string value) {
    immutable digits = "0123456789abcdef";
    foreach (ubyte octet; cast(const(ubyte)[]) value) {
        stdout.write(digits[octet >> 4], digits[octet & 15]);
    }
}
