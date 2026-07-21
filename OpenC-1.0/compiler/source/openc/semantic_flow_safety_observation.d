module openc.semantic_flow_safety_observation;

import openc.ast : AstArena, AstNode, NodeKind, ParsedUnit;
import openc.borrow : BorrowAnalyzer;
import openc.cfg : CfgBuilder, ControlFlowGraph;
import openc.cleanup : CleanupAnalyzer;
import openc.declarations : DeclarationCollector;
import openc.diagnostic : Diagnostic, DiagnosticEngine;
import openc.flow : FlowAnalyzer;
import openc.lexer : Lexer;
import openc.module_system : ModuleComposer;
import openc.names : NameResolver;
import openc.ownership : OwnershipAnalyzer;
import openc.parser : Parser;
import openc.pointer : PointerAnalyzer;
import openc.project : ProjectConfig;
import openc.semantic_model : SemanticModel;
import openc.source : SourceId, SourceManager;
import openc.status_out : StatusOutAnalyzer;
import openc.type_check : TypeChecker;
import openc.unsafe_checker : UnsafeChecker;
import std.stdio : stderr, stdout;

private struct UnitLocation {
    size_t moduleIndex;
    size_t sourceIndex;
}

int observeSemanticFlowSafety(string path) {
    stdout.writeln("OPENC-SEMANTIC-FLOW-SAFETY-OBSERVATION 1");
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
                stderr.writeln("openc semantic-flow-safety-observe: " ~ source.error);
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
    auto model = new SemanticModel(graph, project.target);
    new DeclarationCollector(model, diagnostics).collect();
    new NameResolver(model, diagnostics).resolve();
    new TypeChecker(model, diagnostics).check();

    size_t functionCount;
    size_t blockCount;
    size_t edgeCount;
    size_t cleanupCount;
    foreach (logical; graph.modules) {
        foreach (unit; logical.units) {
            foreach (node; unit.root.children) {
                if (node.kind != NodeKind.functionDecl || node.flag("prototype")) continue;
                auto location = locations[node.span.source];
                auto cfg = new CfgBuilder().build(node.children[$ - 1]);
                new FlowAnalyzer(model, diagnostics).analyze(cfg, node);
                new StatusOutAnalyzer(model, diagnostics).analyzeFunction(node);
                new OwnershipAnalyzer(model, diagnostics).analyzeFunction(node);
                new BorrowAnalyzer(model, diagnostics).analyzeFunction(node);
                auto cleanups = new CleanupAnalyzer(model, diagnostics).analyzeFunction(node);
                new PointerAnalyzer(model, diagnostics).analyzeFunction(node);
                new UnsafeChecker(model, diagnostics).analyzeFunction(node);

                stdout.write(
                    "FUNCTION ", functionCount, " ", location.moduleIndex, " ",
                    location.sourceIndex, " ", node.span.start, " ", node.span.length, " ",
                );
                writeHex(node.text);
                stdout.writeln(" ", cfg.blocks.length, " ", cfg.edges.length);

                blockCount += cfg.blocks.length;
                edgeCount += cfg.edges.length;
                foreach (cleanupIndex, cleanup; cleanups) {
                    stdout.writeln(
                        "CLEANUP ", functionCount, " ", cleanupIndex, " ",
                        cleanup.action.span.start, " ", cleanup.action.span.length,
                    );
                    ++cleanupCount;
                }
                ++functionCount;
            }
        }
    }

    size_t errorCount;
    foreach (diagnostic; diagnostics.all()) {
        if (!flowSafetyRule(diagnostic.rule)) continue;
        auto location = locations[diagnostic.span.source];
        stdout.writeln(
            "ERROR ", errorCount, " ", cast(string) diagnostic.phase, " ", diagnostic.rule,
            " ", location.moduleIndex, " ", location.sourceIndex, " ",
            diagnostic.span.start, " ", diagnostic.span.length,
        );
        ++errorCount;
    }
    stdout.writeln(
        "SUMMARY ", project.modules.length, " ", sources.count(), " ", functionCount,
        " ", blockCount, " ", edgeCount, " ", cleanupCount, " ", errorCount,
    );
    return errorCount == 0 ? 0 : 1;
}

private bool flowSafetyRule(string rule) {
    return rule == "OPENC-SAFE-INIT-001" ||
        rule == "OPENC-OWN-USE-AFTER-MOVE-001" ||
        rule == "OPENC-LIFETIME-USE-AFTER-DESTROY-001" ||
        rule == "OPENC-STATUS-FIELD-DUPLICATE-001" ||
        rule == "OPENC-STATUS-CODE-001" ||
        rule == "OPENC-OUT-STATUS-001" ||
        rule == "OPENC-OUT-CARRIER-001" ||
        rule == "OPENC-OUT-FUNCTION-STATUS-001" ||
        rule == "OPENC-OUT-RETURN-001" ||
        rule == "OPENC-OWN-EXIT-001" ||
        rule == "OPENC-OWN-OVERWRITE-001" ||
        rule == "OPENC-RESOURCE-INIT-DUPLICATE-OWNER-001" ||
        rule == "OPENC-SCOPE-OWNER-STATE-001" ||
        rule == "OPENC-OWN-CLEANUP-RESERVED-001" ||
        rule == "OPENC-OWN-DOUBLE-DISCHARGE-001" ||
        rule == "OPENC-OWN-USE-AFTER-DESTROY-001" ||
        rule == "OPENC-BORROW-MOVE-001" ||
        rule == "OPENC-BORROW-CONFLICT-001" ||
        rule == "OPENC-SCOPE-ACTION-001" ||
        rule == "OPENC-SCOPE-NOFAIL-001" ||
        rule == "OPENC-PTR-ONEPAST-001" ||
        rule == "OPENC-PTR-ADDRESS-UNSAFE-001" ||
        rule == "OPENC-PTR-DEREF-UNSAFE-001" ||
        rule == "OPENC-PTR-ARITH-UNSAFE-001" ||
        rule == "OPENC-REINTERPRET-UNSAFE-001" ||
        rule == "OPENC-UNSAFE-REQUIRED-001" ||
        rule == "OPENC-UNSAFE-CALL-001";
}

private void writeHex(string value) {
    immutable digits = "0123456789abcdef";
    foreach (ubyte octet; cast(const(ubyte)[]) value) {
        stdout.write(digits[octet >> 4], digits[octet & 15]);
    }
}
