module openc.ownership;

import openc.ast : AstNode, NodeKind;
import openc.ast_util : walk;
import openc.common : SymbolId, TypeId;
import openc.diagnostic : Diagnostic, DiagnosticEngine, DiagnosticPhase, DiagnosticSeverity, RelatedLocation;
import openc.semantic_model : SemanticModel;
import openc.symbol : SymbolKind;
import openc.types : TypeKind;
import std.algorithm.searching : canFind;
import std.algorithm.sorting : sort;

enum OwnershipState : string {
    none = "none",
    live = "live",
    cleanupReserved = "cleanup_reserved",
    moved = "moved",
    dismantling = "dismantling",
    destroyed = "destroyed",
    conditional = "conditional",
    maybeLive = "maybe_live"
}

struct OwnershipValue {
    OwnershipState state;
    AstNode origin;
}

final class OwnershipAnalyzer {
private:
    SemanticModel model;
    DiagnosticEngine diagnostics;
    OwnershipValue[SymbolId] state;

public:
    this(SemanticModel model, DiagnosticEngine diagnostics) {
        this.model = model;
        this.diagnostics = diagnostics;
    }

    void analyzeFunction(AstNode functionNode) {
        state = null;
        foreach (child; functionNode.children) {
            if (child.kind != NodeKind.parameter) continue;
            auto symbol = child.id in model.nodeSymbols;
            if (symbol is null) continue;
            auto info = model.symbols.get(*symbol);
            auto mode = child.get("mode", "value");
            if (info.resource || mode == "own" || mode == "out_own") {
                state[*symbol] = OwnershipValue(
                    mode == "out" || mode == "out_own" ? OwnershipState.none : OwnershipState.live,
                    child);
            }
        }
        inspectBlock(functionNode.children[$ - 1]);
        SymbolId[] ordered;
        foreach (symbol, value; state) {
            if (value.state == OwnershipState.live ||
                value.state == OwnershipState.dismantling ||
                value.state == OwnershipState.maybeLive) {
                ordered ~= symbol;
            }
        }
        ordered.sort!((left, right) {
            auto leftSpan = model.symbols.get(left).span;
            auto rightSpan = model.symbols.get(right).span;
            if (leftSpan.source.value != rightSpan.source.value) {
                return leftSpan.source.value < rightSpan.source.value;
            }
            if (leftSpan.start != rightSpan.start) {
                return leftSpan.start < rightSpan.start;
            }
            if (leftSpan.length != rightSpan.length) {
                return leftSpan.length < rightSpan.length;
            }
            return left < right;
        });
        foreach (symbol; ordered) {
            auto value = state[symbol];
            if (value.state == OwnershipState.live || value.state == OwnershipState.dismantling || value.state == OwnershipState.maybeLive) {
                auto info = model.symbols.get(symbol);
                if (info.kind == SymbolKind.parameterSymbol && info.declaration !is null &&
                    ["own", "out", "out_own"].canFind(info.declaration.get("mode"))) continue;
                diagnostics.error("OPENC-OWN-EXIT-001", DiagnosticPhase.ownership,
                    "ownership.exit", "ownership obligation leaves function without transfer or cleanup: " ~ info.name,
                    info.span);
            }
        }
    }

private:
    void inspectBlock(AstNode block) {
        foreach (node; block.children) {
            if (node.kind == NodeKind.localDecl) inspectLocal(node);
            else inspectStatement(node);
        }
    }

    void inspectLocal(AstNode node) {
        auto symbol = node.id in model.nodeSymbols;
        if (symbol is null) return;
        auto info = model.symbols.get(*symbol);
        if (node.children.length > 1 && node.children[1] !is null) inspectExpression(node.children[1], false);
        if (info.resource || model.types.get(info.type).resource || isOwningPointer(info.type)) {
            state[*symbol] = OwnershipValue(node.children.length > 1 ? OwnershipState.live : OwnershipState.none, node);
        }
    }

    void inspectStatement(AstNode node) {
        if (node is null) return;
        switch (node.kind) {
            case NodeKind.block: inspectBlock(node); break;
            case NodeKind.expressionStmt: inspectExpression(node.children[0], false); break;
            case NodeKind.scopeStmt: inspectScope(node); break;
            case NodeKind.returnStmt:
                if (node.children.length && node.children[0] !is null) inspectExpression(node.children[0], true);
                break;
            case NodeKind.ifStmt:
                inspectExpression(node.children[0], false);
                inspectBlock(node.children[1]);
                if (node.children.length > 2) {
                    if (node.children[2].kind == NodeKind.block) inspectBlock(node.children[2]);
                    else inspectStatement(node.children[2]);
                }
                break;
            case NodeKind.whileStmt:
            case NodeKind.forStmt:
            case NodeKind.switchStmt:
                walk(node, (AstNode child) { if (child.kind == NodeKind.callExpr || child.kind == NodeKind.assignmentExpr) inspectExpression(child, false); });
                break;
            case NodeKind.unsafeStmt:
            case NodeKind.whenStmt:
                foreach (child; node.children) if (child.kind == NodeKind.block) inspectBlock(child);
                break;
            default: break;
        }
    }

    void inspectExpression(AstNode node, bool returnContext) {
        if (node is null) return;
        if (node.kind == NodeKind.qualifiedName) {
            auto symbol = node.id in model.nodeSymbols;
            if (symbol !is null && *symbol in state) {
                auto value = state[*symbol];
                if (value.state == OwnershipState.moved || value.state == OwnershipState.destroyed) useAfter(node, *symbol, value);
                if (returnContext) move(node, *symbol);
            }
            return;
        }
        if (node.kind == NodeKind.assignmentExpr) {
            inspectExpression(node.children[1], false);
            auto destination = node.children[0].id in model.nodeSymbols;
            if (destination !is null && *destination in state) {
                auto existing = state[*destination];
                if (existing.state == OwnershipState.live || existing.state == OwnershipState.cleanupReserved) {
                    diagnostics.error("OPENC-OWN-OVERWRITE-001", DiagnosticPhase.ownership,
                        "ownership.overwrite", "cannot overwrite a live owner", node.children[0].span);
                }
                state[*destination] = OwnershipValue(OwnershipState.live, node);
            }
            return;
        }
        if (node.kind == NodeKind.callExpr) {
            auto callee = node.id in model.nodeSymbols;
            if (callee !is null) {
                auto functionSymbol = model.symbols.get(*callee);
                foreach (index, argument; node.children[1 .. $]) {
                    auto mode = index < functionSymbol.signature.modes.length ? functionSymbol.signature.modes[index] : "value";
                    if (mode == "own") {
                        auto source = argument.id in model.nodeSymbols;
                        if (source !is null) move(argument, *source);
                    } else if (mode == "out" || mode == "out_own") {
                        auto destination = argument.id in model.nodeSymbols;
                        if (destination !is null && *destination in state) {
                            state[*destination] = OwnershipValue(OwnershipState.live, node);
                        }
                    } else inspectExpression(argument, false);
                }
            } else foreach (argument; node.children[1 .. $]) inspectExpression(argument, false);
            return;
        }
        if (node.kind == NodeKind.aggregateInitializer) {
            bool[SymbolId] usedSources;
            foreach (field; node.children[1 .. $]) {
                auto value = field.children[0];
                if (field.flag("own")) {
                    auto source = value.id in model.nodeSymbols;
                    if (source !is null) {
                        if (*source in usedSources) diagnostics.error("OPENC-RESOURCE-INIT-DUPLICATE-OWNER-001", DiagnosticPhase.ownership,
                            "ownership.construction", "one ownership source cannot initialize two fields", value.span);
                        usedSources[*source] = true;
                        move(value, *source);
                    }
                } else inspectExpression(value, false);
            }
            return;
        }
        if (node.kind == NodeKind.destroyExpr) {
            auto owner = node.children[0].id in model.nodeSymbols;
            if (owner !is null) destroy(node, *owner);
            return;
        }
        foreach (child; node.children) inspectExpression(child, false);
    }

    void inspectScope(AstNode node) {
        auto action = node.children[0];
        if (action.kind == NodeKind.callExpr && action.children.length > 1) {
            auto argument = action.children[1];
            auto owner = argument.id in model.nodeSymbols;
            if (owner !is null && *owner in state) {
                auto value = state[*owner];
                if (value.state != OwnershipState.live) {
                    diagnostics.error("OPENC-SCOPE-OWNER-STATE-001", DiagnosticPhase.ownership,
                        "ownership.cleanup", "scope cleanup requires one live owner", argument.span);
                } else {
                    state[*owner] = OwnershipValue(OwnershipState.cleanupReserved, node);
                }
            }
        } else if (action.kind == NodeKind.destroyExpr) {
            auto owner = action.children[0].id in model.nodeSymbols;
            if (owner !is null) state[*owner] = OwnershipValue(OwnershipState.cleanupReserved, node);
        }
    }

    void move(AstNode node, SymbolId symbol) {
        auto value = state.get(symbol, OwnershipValue(OwnershipState.none, null));
        if (value.state == OwnershipState.cleanupReserved) {
            diagnostics.error("OPENC-OWN-CLEANUP-RESERVED-001", DiagnosticPhase.ownership,
                "ownership.move", "owner reserved for scope cleanup cannot be moved", node.span);
            return;
        }
        if (value.state != OwnershipState.live) {
            useAfter(node, symbol, value);
            return;
        }
        state[symbol] = OwnershipValue(OwnershipState.moved, node);
    }

    void destroy(AstNode node, SymbolId symbol) {
        auto value = state.get(symbol, OwnershipValue(OwnershipState.none, null));
        if (value.state == OwnershipState.destroyed || value.state == OwnershipState.moved) {
            useAfter(node, symbol, value);
            return;
        }
        if (value.state == OwnershipState.cleanupReserved) {
            diagnostics.error("OPENC-OWN-DOUBLE-DISCHARGE-001", DiagnosticPhase.ownership,
                "ownership.destroy", "owner already reserved for cleanup", node.span);
            return;
        }
        state[symbol] = OwnershipValue(OwnershipState.destroyed, node);
    }

    void useAfter(AstNode node, SymbolId symbol, OwnershipValue value) {
        auto info = model.symbols.get(symbol);
        Diagnostic diagnostic;
        diagnostic.rule = value.state == OwnershipState.destroyed ? "OPENC-OWN-USE-AFTER-DESTROY-001" : "OPENC-OWN-USE-AFTER-MOVE-001";
        diagnostic.category = "ownership.state";
        diagnostic.severity = DiagnosticSeverity.error;
        diagnostic.phase = DiagnosticPhase.ownership;
        diagnostic.message = "owner is not live: " ~ info.name;
        diagnostic.span = node.span;
        if (value.origin !is null) diagnostic.related ~= RelatedLocation(DiagnosticSeverity.note, "ownership state changed here", value.origin.span);
        diagnostics.emit(diagnostic);
    }

    bool isOwningPointer(TypeId type) {
        auto info = model.types.get(type);
        return info.kind == TypeKind.pointer && info.resource;
    }
}
