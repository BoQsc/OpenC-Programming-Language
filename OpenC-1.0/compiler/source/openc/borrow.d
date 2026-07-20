module openc.borrow;

import openc.ast : AstNode, NodeKind;
import openc.common : ScopeId, SymbolId;
import openc.diagnostic : Diagnostic, DiagnosticEngine, DiagnosticPhase, DiagnosticSeverity, RelatedLocation;
import openc.semantic_model : SemanticModel;
import openc.types : TypeKind;

struct BorrowRecord {
    SymbolId owner;
    SymbolId borrower;
    bool mutableBorrow;
    ScopeId scopeId;
    AstNode origin;
}

final class BorrowAnalyzer {
private:
    SemanticModel model;
    DiagnosticEngine diagnostics;
    BorrowRecord[] active;

public:
    this(SemanticModel model, DiagnosticEngine diagnostics) {
        this.model = model;
        this.diagnostics = diagnostics;
    }

    void analyzeFunction(AstNode functionNode) {
        active = [];
        inspectBlock(functionNode.children[$ - 1]);
    }

private:
    void inspectBlock(AstNode block) {
        auto scopeId = model.nodeScopes.get(block.id, 0);
        const before = active.length;
        foreach (node; block.children) {
            if (node.kind == NodeKind.localDecl) inspectLocal(node, scopeId);
            else inspectNode(node, scopeId);
        }
        active.length = before;
    }

    void inspectLocal(AstNode node, ScopeId scopeId) {
        if (node.children.length <= 1 || node.children[1] is null) return;
        auto type = model.types.resolve(node.children[0], model.target);
        auto typeInfo = model.types.get(type);
        if (typeInfo.kind == TypeKind.reference) {
            auto owner = rootSymbol(node.children[1]);
            auto borrower = node.id in model.nodeSymbols;
            if (owner !is null && borrower !is null) addBorrow(*owner, *borrower, !typeInfo.constQualified, scopeId, node);
        }
        inspectNode(node.children[1], scopeId);
    }

    void inspectNode(AstNode node, ScopeId scopeId) {
        if (node is null) return;
        if (node.kind == NodeKind.block) { inspectBlock(node); return; }
        if (node.kind == NodeKind.assignmentExpr) {
            auto owner = rootSymbol(node.children[0]);
            if (owner !is null) checkMutation(*owner, node.children[0]);
        }
        if (node.kind == NodeKind.callExpr) {
            auto callee = node.id in model.nodeSymbols;
            if (callee !is null) {
                auto signature = model.symbols.get(*callee).signature;
                foreach (index, argument; node.children[1 .. $]) {
                    if (index >= signature.parameters.length) continue;
                    auto parameter = model.types.get(signature.parameters[index]);
                    if (parameter.kind == TypeKind.reference) {
                        auto owner = rootSymbol(argument);
                        if (owner !is null) checkTemporaryBorrow(*owner, !parameter.constQualified, scopeId, argument);
                    }
                    if (signature.modes[index] == "own") {
                        auto owner = rootSymbol(argument);
                        if (owner !is null) checkMove(*owner, argument);
                    }
                }
            }
        }
        foreach (child; node.children) inspectNode(child, scopeId);
    }

    void addBorrow(SymbolId owner, SymbolId borrower, bool mutableBorrow, ScopeId scopeId, AstNode origin) {
        foreach (record; active) {
            if (record.owner != owner) continue;
            if (mutableBorrow || record.mutableBorrow) conflict(origin, record.origin);
        }
        active ~= BorrowRecord(owner, borrower, mutableBorrow, scopeId, origin);
    }

    void checkTemporaryBorrow(SymbolId owner, bool mutableBorrow, ScopeId scopeId, AstNode origin) {
        foreach (record; active) {
            if (record.owner != owner) continue;
            if (mutableBorrow || record.mutableBorrow) conflict(origin, record.origin);
        }
    }

    void checkMutation(SymbolId owner, AstNode site) {
        foreach (record; active) {
            if (record.owner == owner) conflict(site, record.origin);
        }
    }

    void checkMove(SymbolId owner, AstNode site) {
        foreach (record; active) {
            if (record.owner == owner) {
                Diagnostic diagnostic;
                diagnostic.rule = "OPENC-BORROW-MOVE-001";
                diagnostic.category = "borrow.move";
                diagnostic.severity = DiagnosticSeverity.error;
                diagnostic.phase = DiagnosticPhase.borrow;
                diagnostic.message = "cannot move an owner while it is borrowed";
                diagnostic.span = site.span;
                diagnostic.related ~= RelatedLocation(DiagnosticSeverity.note, "active borrow begins here", record.origin.span);
                diagnostics.emit(diagnostic);
            }
        }
    }

    void conflict(AstNode site, AstNode existing) {
        Diagnostic diagnostic;
        diagnostic.rule = "OPENC-BORROW-CONFLICT-001";
        diagnostic.category = "borrow.alias";
        diagnostic.severity = DiagnosticSeverity.error;
        diagnostic.phase = DiagnosticPhase.borrow;
        diagnostic.message = "conflicting safe borrows or mutation";
        diagnostic.span = site.span;
        diagnostic.related ~= RelatedLocation(DiagnosticSeverity.note, "conflicting borrow", existing.span);
        diagnostics.emit(diagnostic);
    }

    SymbolId* rootSymbol(AstNode node) {
        if (node is null) return null;
        if (node.kind == NodeKind.qualifiedName || node.kind == NodeKind.outArgument) return node.id in model.nodeSymbols;
        if ((node.kind == NodeKind.memberExpr || node.kind == NodeKind.indexExpr || node.kind == NodeKind.rangeExpr) && node.children.length) return rootSymbol(node.children[0]);
        return null;
    }
}
