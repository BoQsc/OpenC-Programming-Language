module openc.semantic_pipeline;

import openc.ast : AstNode, NodeKind, ParsedUnit;
import openc.borrow : BorrowAnalyzer;
import openc.cfg : CfgBuilder, ControlFlowGraph;
import openc.cleanup : CleanupAnalyzer;
import openc.common : TargetContext;
import openc.core_rules : CoreRuleChecker;
import openc.declarations : DeclarationCollector;
import openc.diagnostic : DiagnosticEngine;
import openc.flow : FlowAnalyzer;
import openc.module_system : ModuleComposer, ModuleGraph;
import openc.names : NameResolver;
import openc.ownership : OwnershipAnalyzer;
import openc.pointer : PointerAnalyzer;
import openc.project : ProjectConfig;
import openc.semantic_model : SemanticModel;
import openc.source : SourceId, SourceManager;
import openc.status_out : StatusOutAnalyzer;
import openc.type_check : TypeChecker;
import openc.unsafe_checker : UnsafeChecker;

final class SemanticPipeline {
private:
    SourceManager sources;
    DiagnosticEngine diagnostics;

public:
    this(SourceManager sources, DiagnosticEngine diagnostics) {
        this.sources = sources;
        this.diagnostics = diagnostics;
    }

    SemanticModel run(ProjectConfig project, ParsedUnit[SourceId] units) {
        auto graph = new ModuleComposer(diagnostics).compose(project, units, sources);
        auto model = new SemanticModel(graph, project.target);
        new DeclarationCollector(model, diagnostics).collect();
        new NameResolver(model, diagnostics).resolve();
        new TypeChecker(model, diagnostics).check();

        foreach (logical; graph.modules) {
            foreach (unit; logical.units) {
                foreach (node; unit.root.children) {
                    if (node.kind != NodeKind.functionDecl) continue;
                    if (node.flag("prototype")) continue;
                    auto cfg = new CfgBuilder().build(node.children[$ - 1]);
                    new FlowAnalyzer(model, diagnostics).analyze(cfg, node);
                    new StatusOutAnalyzer(model, diagnostics).analyzeFunction(node);
                    new OwnershipAnalyzer(model, diagnostics).analyzeFunction(node);
                    new BorrowAnalyzer(model, diagnostics).analyzeFunction(node);
                    new CleanupAnalyzer(model, diagnostics).analyzeFunction(node);
                    new PointerAnalyzer(model, diagnostics).analyzeFunction(node);
                    new UnsafeChecker(model, diagnostics).analyzeFunction(node);
                }
            }
        }
        new CoreRuleChecker(model, diagnostics, sources, project.profile).check();
        return model;
    }
}
