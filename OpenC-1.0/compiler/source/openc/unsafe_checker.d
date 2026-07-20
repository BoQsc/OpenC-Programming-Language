module openc.unsafe_checker;

import openc.ast : AstNode, NodeKind;
import openc.diagnostic : DiagnosticEngine, DiagnosticPhase;
import openc.semantic_model : SemanticModel;
import openc.types : TypeKind;

final class UnsafeChecker {
private:
    SemanticModel model;
    DiagnosticEngine diagnostics;
    size_t depth;
    bool unsafeFunction;

public:
    this(SemanticModel model, DiagnosticEngine diagnostics) {
        this.model = model;
        this.diagnostics = diagnostics;
    }

    void analyzeFunction(AstNode functionNode) {
        unsafeFunction = functionNode.flag("unsafe");
        depth = unsafeFunction ? 1 : 0;
        inspect(functionNode.children[$ - 1]);
    }

private:
    void inspect(AstNode node) {
        if (node is null) return;
        if (node.kind == NodeKind.unsafeStmt) {
            ++depth;
            inspect(node.children[0]);
            --depth;
            return;
        }
        if (requiresUnsafe(node) && depth == 0) {
            diagnostics.error(ruleFor(node), DiagnosticPhase.unsafePhase,
                "unsafe.required", "operation requires an explicit unsafe region or unsafe function", node.span);
        }
        if (node.kind == NodeKind.callExpr) {
            auto target = node.id in model.nodeSymbols;
            if (target !is null && model.symbols.get(*target).signature.unsafeFunction && depth == 0) {
                diagnostics.error("OPENC-UNSAFE-CALL-001", DiagnosticPhase.unsafePhase,
                    "unsafe.call", "calling an unsafe function requires unsafe", node.span);
            }
        }
        foreach (child; node.children) inspect(child);
    }

    bool requiresUnsafe(AstNode node) const {
        if (node.kind == NodeKind.unaryExpr && (node.text == "&" || node.text == "*")) return true;
        if (node.kind == NodeKind.binaryExpr && (node.text == "+" || node.text == "-") &&
            model.types.get(model.typeOf(node.children[0])).kind == TypeKind.pointer) return true;
        if (node.kind == NodeKind.reinterpretExpr) return true;
        if (node.kind == NodeKind.castExpr && node.flag("unsafe_operation")) return true;
        return false;
    }

    string ruleFor(AstNode node) const {
        if (node.kind == NodeKind.unaryExpr && node.text == "&") return "OPENC-PTR-ADDRESS-UNSAFE-001";
        if (node.kind == NodeKind.unaryExpr && node.text == "*") return "OPENC-PTR-DEREF-UNSAFE-001";
        if (node.kind == NodeKind.binaryExpr) return "OPENC-PTR-ARITH-UNSAFE-001";
        if (node.kind == NodeKind.reinterpretExpr) return "OPENC-REINTERPRET-UNSAFE-001";
        return "OPENC-UNSAFE-REQUIRED-001";
    }
}
