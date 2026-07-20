module openc.cleanup;

import openc.ast : AstNode, NodeKind;
import openc.common : ScopeId, SymbolId;
import openc.diagnostic : Diagnostic, DiagnosticEngine, DiagnosticPhase, DiagnosticSeverity, RelatedLocation;
import openc.semantic_model : SemanticModel;

struct CleanupAction {
    ScopeId scopeId;
    AstNode statement;
    AstNode action;
    SymbolId[] capturedOwners;
    size_t sequence;
}

final class CleanupAnalyzer {
private:
    SemanticModel model;
    DiagnosticEngine diagnostics;
    CleanupAction[] actions;
    size_t sequence;

public:
    this(SemanticModel model, DiagnosticEngine diagnostics) {
        this.model = model;
        this.diagnostics = diagnostics;
    }

    CleanupAction[] analyzeFunction(AstNode functionNode) {
        actions = [];
        sequence = 0;
        inspectBlock(functionNode.children[$ - 1]);
        return actions.dup;
    }

private:
    void inspectBlock(AstNode block) {
        auto scopeId = model.nodeScopes.get(block.id, 0);
        foreach (node; block.children) {
            if (node.kind == NodeKind.scopeStmt) register(node, scopeId);
            else if (node.kind == NodeKind.block) inspectBlock(node);
            else {
                foreach (child; node.children) if (child !is null && child.kind == NodeKind.block) inspectBlock(child);
            }
        }
    }

    void register(AstNode statement, ScopeId scopeId) {
        auto action = statement.children[0];
        CleanupAction record;
        record.scopeId = scopeId;
        record.statement = statement;
        record.action = action;
        record.sequence = sequence++;

        if (action.kind == NodeKind.callExpr) {
            auto target = action.id in model.nodeSymbols;
            if (target is null) {
                diagnostics.error("OPENC-SCOPE-ACTION-001", DiagnosticPhase.name,
                    "cleanup.action", "scope cleanup target must resolve to a function", action.span);
            } else {
                auto functionSymbol = model.symbols.get(*target);
                if (functionSymbol.signature.result != model.types.voidType) {
                    diagnostics.error("OPENC-SCOPE-NOFAIL-001", DiagnosticPhase.type,
                        "cleanup.nofail", "scope cleanup function must return void", action.span);
                }
                foreach (index, mode; functionSymbol.signature.modes) {
                    if (mode == "out" || mode == "out_own") {
                        diagnostics.error("OPENC-SCOPE-NOFAIL-001", DiagnosticPhase.type,
                            "cleanup.nofail", "scope cleanup cannot publish outputs", action.span);
                    }
                    if (mode == "own" && index + 1 < action.children.length) {
                        auto owner = rootSymbol(action.children[index + 1]);
                        if (owner !is null) record.capturedOwners ~= *owner;
                    }
                }
            }
        } else if (action.kind == NodeKind.destroyExpr) {
            auto owner = rootSymbol(action.children[0]);
            if (owner !is null) record.capturedOwners ~= *owner;
        } else {
            diagnostics.error("OPENC-SCOPE-ACTION-001", DiagnosticPhase.syntax,
                "cleanup.action", "scope accepts a no-fail call or destroy action", action.span);
        }
        actions ~= record;
    }

    SymbolId* rootSymbol(AstNode node) {
        if (node is null) return null;
        if (node.kind == NodeKind.qualifiedName || node.kind == NodeKind.outArgument) return node.id in model.nodeSymbols;
        if (node.children.length) return rootSymbol(node.children[0]);
        return null;
    }
}
