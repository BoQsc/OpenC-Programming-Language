module openc.semantic_resolution_observation;

import openc.ast : AstArena, AstNode, NodeKind, ParsedUnit;
import openc.constant : ConstantEvaluator, ConstantValue;
import openc.declarations : DeclarationCollector;
import openc.diagnostic : DiagnosticEngine, DiagnosticPhase;
import openc.lexer : Lexer;
import openc.module_system : ModuleComposer;
import openc.names : NameResolver;
import openc.parser : Parser;
import openc.project : ProjectConfig;
import openc.semantic_model : SemanticModel;
import openc.source : SourceId, SourceManager;
import openc.symbol : Symbol;
import openc.type_check : TypeChecker;
import openc.types : TypeKind;
import std.stdio : stderr, stdout;

private struct UnitLocation {
    size_t moduleIndex;
    size_t sourceIndex;
}

int observeSemanticResolution(string path) {
    stdout.writeln("OPENC-SEMANTIC-RESOLUTION-OBSERVATION 1");
    auto loaded = ProjectConfig.load(path);
    if (!loaded.ok) {
        stdout.writeln("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
        stdout.writeln("SUMMARY 0 0 0 0 0 1");
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
                stderr.writeln("openc semantic-resolve-observe: " ~ source.error);
                stdout.writeln("PROJECT_ERROR OPENC-PROJECT-SOURCE-READ-001 ", moduleIndex, " ", sourceIndex);
                stdout.writeln("SUMMARY ", project.modules.length, " 0 0 0 0 1");
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
        stdout.writeln("SUMMARY ", project.modules.length, " ", sources.count(), " 0 0 0 ", diagnostics.errors());
        return 1;
    }

    auto graph = new ModuleComposer(diagnostics).compose(project, parsed, sources);
    auto model = new SemanticModel(graph, project.target);
    new DeclarationCollector(model, diagnostics).collect();
    new NameResolver(model, diagnostics).resolve();
    new TypeChecker(model, diagnostics).check();

    size_t bindingCount;
    size_t callCount;
    foreach (node; arena.all()) {
        if (node.kind == NodeKind.qualifiedName) {
            auto found = node.id in model.nodeSymbols;
            if (found is null) continue;
            auto location = locations[node.span.source];
            auto symbol = model.symbols.get(*found);
            stdout.write(
                "BIND ", bindingCount, " ", location.moduleIndex, " ",
                location.sourceIndex, " ", node.span.start, " ", node.span.length, " ",
            );
            writeHex(node.text);
            stdout.write(" ", cast(string) symbol.kind, " ");
            writeHex(symbolIdentity(symbol));
            stdout.write(" ", symbol.span.start, " ", symbol.span.length, " ");
            writeHex(model.types.get(model.typeOf(node)).display(model.types));
            stdout.writeln();
            ++bindingCount;
        } else if (node.kind == NodeKind.callExpr) {
            auto found = node.id in model.nodeSymbols;
            if (found is null) continue;
            auto location = locations[node.span.source];
            auto symbol = model.symbols.get(*found);
            stdout.write(
                "CALL ", callCount, " ", location.moduleIndex, " ",
                location.sourceIndex, " ", node.span.start, " ", node.span.length, " ",
            );
            writeHex(node.children.length ? node.children[0].text : "");
            stdout.write(" ");
            writeHex(symbolIdentity(symbol));
            stdout.write(" ", symbol.span.start, " ", symbol.span.length, " ");
            writeHex(model.types.get(model.typeOf(node)).display(model.types));
            stdout.writeln();
            ++callCount;
        }
    }

    auto observationDiagnostics = new DiagnosticEngine();
    auto evaluator = new ConstantEvaluator(model, observationDiagnostics);
    size_t constantCount;
    foreach (logical; graph.modules) {
        foreach (unit; logical.units) {
            foreach (node; unit.root.children) {
                if (node.kind == NodeKind.moduleConstDecl && node.children.length > 1) {
                    auto value = evaluator.evaluate(node.children[1]);
                    if (value.valid) {
                        emitConstant("module_constant", node.text, node, value, model, locations, constantCount);
                        ++constantCount;
                    }
                } else if (node.kind == NodeKind.enumDecl) {
                    foreach (item; node.children) {
                        if (item.kind != NodeKind.enumItem) continue;
                        auto stored = item.id in model.integerConstants;
                        if (stored is null) continue;
                        ConstantValue value;
                        value.type = model.nodeSymbols.get(item.id, 0) < model.symbols.symbols.length
                            ? model.symbols.get(model.nodeSymbols[item.id]).type
                            : model.types.errorType;
                        value.valid = true;
                        value.signedValue = *stored;
                        value.unsignedValue = cast(ulong) *stored;
                        emitConstant("enum_item", node.text ~ "." ~ item.text, item, value, model, locations, constantCount);
                        ++constantCount;
                    }
                }
            }
        }
    }

    size_t errorCount;
    foreach (diagnostic; diagnostics.all()) {
        if (!resolutionRule(diagnostic.rule)) continue;
        auto location = locations[diagnostic.span.source];
        stdout.writeln(
            "ERROR ", diagnostic.rule, " ", location.moduleIndex, " ",
            location.sourceIndex, " ", diagnostic.span.start, " ", diagnostic.span.length,
        );
        ++errorCount;
    }
    stdout.writeln(
        "SUMMARY ", project.modules.length, " ", sources.count(), " ",
        bindingCount, " ", constantCount, " ", callCount, " ", errorCount,
    );
    return errorCount == 0 ? 0 : 1;
}

private void emitConstant(
    string ownerKind,
    string name,
    AstNode node,
    ConstantValue value,
    SemanticModel model,
    UnitLocation[SourceId] locations,
    size_t ordinal,
) {
    auto location = locations[node.span.source];
    stdout.write(
        "CONST ", ordinal, " ", location.moduleIndex, " ", location.sourceIndex,
        " ", ownerKind, " ", node.span.start, " ", node.span.length, " ",
    );
    writeHex(name);
    stdout.write(" ");
    writeHex(model.types.get(value.type).display(model.types));
    auto info = model.types.get(value.type);
    if (info.integer() || info.kind == TypeKind.named) {
        stdout.writeln(" integer ", value.signedValue);
    } else if (info.kind == TypeKind.boolean) {
        stdout.writeln(" bool ", value.boolValue ? 1 : 0);
    } else if (info.kind == TypeKind.text) {
        stdout.write(" text ");
        writeHex(value.textValue);
        stdout.writeln();
    } else if (info.kind == TypeKind.floating) {
        stdout.write(" float_source ");
        writeHex(node.children.length ? node.children[$ - 1].text : node.text);
        stdout.writeln();
    } else {
        stdout.writeln(" unsupported 0");
    }
}

private string symbolIdentity(Symbol symbol) {
    return symbol.qualifiedName.length ? symbol.qualifiedName : symbol.name;
}

private bool resolutionRule(string rule) {
    return rule == "OPENC-NAME-DUPLICATE-001" ||
        rule == "OPENC-NAME-UNKNOWN-001" ||
        rule == "OPENC-NAME-AMBIGUOUS-001" ||
        rule == "OPENC-CALL-NOMATCH-001" ||
        rule == "OPENC-CALL-AMBIGUOUS-001" ||
        rule == "OPENC-LITERAL-RANGE-001" ||
        rule == "OPENC-LITERAL-FLOAT-001" ||
        rule == "OPENC-CONSTANT-TYPE-001" ||
        rule == "OPENC-ARITH-STATIC-OVERFLOW-001" ||
        rule == "OPENC-ARITH-DIVZERO-001" ||
        rule == "OPENC-ARITH-SHIFT-RANGE-001" ||
        rule == "OPENC-TYPE-QUERY-INCOMPLETE-001";
}

private void writeHex(string value) {
    immutable digits = "0123456789abcdef";
    foreach (ubyte octet; cast(const(ubyte)[]) value) {
        stdout.write(digits[octet >> 4], digits[octet & 15]);
    }
}
