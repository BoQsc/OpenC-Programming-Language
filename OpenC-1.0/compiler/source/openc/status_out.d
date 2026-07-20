module openc.status_out;

import openc.ast : AstNode, NodeKind;
import openc.ast_util : walk;
import openc.diagnostic : DiagnosticEngine, DiagnosticPhase;
import openc.semantic_model : SemanticModel;
import openc.symbol : SymbolKind;
import std.algorithm.searching : canFind;

final class StatusOutAnalyzer {
private:
    SemanticModel model;
    DiagnosticEngine diagnostics;

public:
    this(SemanticModel model, DiagnosticEngine diagnostics) {
        this.model = model;
        this.diagnostics = diagnostics;
    }

    void analyzeFunction(AstNode functionNode) {
        auto body = functionNode.children[$ - 1];
        walk(body, (AstNode node) {
            if (node.kind == NodeKind.statusInitializer) checkStatusInitializer(node);
            if (node.kind == NodeKind.callExpr) checkOutCall(node);
        });
        checkCalleeOutputs(functionNode);
    }

private:
    void checkStatusInitializer(AstNode node) {
        bool codeSeen;
        bool messageSeen;
        foreach (field; node.children) {
            if (field.text == "code") {
                if (codeSeen) diagnostics.error("OPENC-STATUS-FIELD-DUPLICATE-001", DiagnosticPhase.type,
                    "status.initializer", "status code initialized more than once", field.span);
                codeSeen = true;
            } else if (field.text == "message") {
                if (messageSeen) diagnostics.error("OPENC-STATUS-FIELD-DUPLICATE-001", DiagnosticPhase.type,
                    "status.initializer", "status message initialized more than once", field.span);
                messageSeen = true;
            }
        }
        if (!codeSeen) diagnostics.error("OPENC-STATUS-CODE-001", DiagnosticPhase.type,
            "status.initializer", "status requires a code field", node.span);
    }

    void checkOutCall(AstNode node) {
        bool hasOut;
        foreach (argument; node.children[1 .. $]) if (argument.kind == NodeKind.outArgument) hasOut = true;
        if (!hasOut) return;
        if (model.typeOf(node) != model.types.statusType) {
            diagnostics.error("OPENC-OUT-STATUS-001", DiagnosticPhase.type,
                "status.out", "a function with out parameters must return status", node.span);
        }
        auto parentCarrier = findStableCarrier(node);
        if (parentCarrier is null) {
            diagnostics.error("OPENC-OUT-CARRIER-001", DiagnosticPhase.flow,
                "status.out", "fallible out call requires a stable status binding or exact return forwarding", node.span);
        }
    }

    AstNode findStableCarrier(AstNode call) {
        return call.get("stable_carrier").length ? call : null;
    }

    void checkCalleeOutputs(AstNode functionNode) {
        bool hasOut;
        foreach (child; functionNode.children) {
            if (child.kind == NodeKind.parameter && ["out", "out_own"].canFind(child.get("mode"))) hasOut = true;
        }
        if (!hasOut) return;
        auto functionSymbol = functionNode.id in model.nodeSymbols;
        if (functionSymbol is null || model.symbols.get(*functionSymbol).signature.result != model.types.statusType) {
            diagnostics.error("OPENC-OUT-FUNCTION-STATUS-001", DiagnosticPhase.type,
                "status.out", "function with out parameters must return status", functionNode.span);
        }
        auto body = functionNode.children[$ - 1];
        walk(body, (AstNode node) {
            if (node.kind == NodeKind.returnStmt && node.children.length && node.children[0] !is null &&
                model.typeOf(node.children[0]) != model.types.statusType) {
                diagnostics.error("OPENC-OUT-RETURN-001", DiagnosticPhase.type,
                    "status.out", "out function must return status", node.span);
            }
        });
    }
}
