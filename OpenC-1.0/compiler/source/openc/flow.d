module openc.flow;

import openc.ast : AstNode, NodeKind;
import openc.ast_util : walk;
import openc.cfg : BasicBlock, ControlFlowGraph, EdgeKind;
import openc.common : BlockId, SymbolId;
import openc.diagnostic : Diagnostic, DiagnosticEngine, DiagnosticPhase, DiagnosticSeverity, RelatedLocation;
import openc.semantic_model : SemanticModel;
import openc.symbol : SymbolKind;
import std.algorithm : sort;
import std.string : endsWith;

enum InitState : string {
    uninitialized = "uninitialized",
    conditional = "conditional",
    initialized = "initialized",
    maybeInitialized = "maybe_initialized",
    ambiguous = "ambiguous",
    moved = "moved",
    destroyed = "destroyed"
}

struct FlowValue {
    InitState state = InitState.uninitialized;
    size_t lineage;
    AstNode origin;
}

struct FlowEnvironment {
    FlowValue[SymbolId] values;
    bool reachable = true;

    bool equals(ref const FlowEnvironment other) const {
        if (reachable != other.reachable || values.length != other.values.length) return false;
        foreach (key, value; values) {
            auto found = key in other.values;
            if (found is null || found.state != value.state || found.lineage != value.lineage) return false;
        }
        return true;
    }
}

final class FlowAnalyzer {
private:
    SemanticModel model;
    DiagnosticEngine diagnostics;
    size_t nextLineage = 1;

public:
    this(SemanticModel model, DiagnosticEngine diagnostics) {
        this.model = model;
        this.diagnostics = diagnostics;
    }

    FlowEnvironment[BlockId] analyze(ControlFlowGraph graph, AstNode functionNode) {
        FlowEnvironment[BlockId] input;
        FlowEnvironment[BlockId] output;
        bool[BlockId] queued;
        BlockId[] worklist = [graph.entry];
        queued[graph.entry] = true;
        auto entry = initialEnvironment(functionNode);
        input[graph.entry] = entry;

        while (worklist.length) {
            auto blockId = worklist[0];
            worklist = worklist[1 .. $];
            queued[blockId] = false;
            auto state = input.get(blockId, FlowEnvironment());
            auto after = transfer(graph.blocks[blockId], state);
            auto old = blockId in output;
            if (old !is null && old.equals(after)) continue;
            output[blockId] = after;
            foreach (edge; graph.edges) {
                if (edge.from != blockId) continue;
                auto edgeState = refineForEdge(after, edge.kind, edge.condition);
                auto existing = edge.to in input;
                if (existing is null) input[edge.to] = edgeState;
                else input[edge.to] = merge(*existing, edgeState);
                if (!(edge.to in queued) || !queued[edge.to]) {
                    worklist ~= edge.to;
                    queued[edge.to] = true;
                }
            }
        }
        return output;
    }

private:
    FlowEnvironment initialEnvironment(AstNode functionNode) {
        FlowEnvironment env;
        foreach (child; functionNode.children) {
            if (child.kind != NodeKind.parameter) continue;
            auto symbol = child.id in model.nodeSymbols;
            if (symbol is null) continue;
            auto mode = child.get("mode", "value");
            if (mode == "out" || mode == "out_own") env.values[*symbol] = FlowValue(InitState.uninitialized, 0, child);
            else env.values[*symbol] = FlowValue(InitState.initialized, 0, child);
        }
        return env;
    }

    FlowEnvironment transfer(BasicBlock block, FlowEnvironment state) {
        if (!state.reachable) return state;
        foreach (statement; block.statements) {
            if (statement.kind == NodeKind.localDecl) {
                auto symbol = statement.id in model.nodeSymbols;
                if (symbol !is null) {
                    auto initial = statement.children.length > 1 && statement.children[1] !is null ? InitState.initialized : InitState.uninitialized;
                    state.values[*symbol] = FlowValue(initial, 0, statement);
                    if (initial == InitState.initialized) inspectExpression(statement.children[1], state, false);
                }
            } else {
                inspectStatement(statement, state);
            }
        }
        return state;
    }

    void inspectStatement(AstNode node, ref FlowEnvironment state) {
        if (node is null) return;
        switch (node.kind) {
            case NodeKind.expressionStmt:
            case NodeKind.returnStmt:
                foreach (child; node.children) inspectExpression(child, state, false);
                break;
            case NodeKind.scopeStmt:
                // A scope action is registered here and executes only when the
                // enclosing scope exits. Its captures are reads at registration,
                // but destroy must not end the referent's lifetime immediately.
                foreach (child; node.children) {
                    if (child.kind == NodeKind.destroyExpr) {
                        foreach (capture; child.children) inspectExpression(capture, state, false);
                    } else inspectExpression(child, state, false);
                }
                break;
            default:
                inspectExpression(node, state, false);
                break;
        }
    }

    void inspectExpression(AstNode node, ref FlowEnvironment state, bool writeContext) {
        if (node is null) return;
        if (node.kind == NodeKind.qualifiedName || node.kind == NodeKind.outArgument) {
            auto symbol = node.id in model.nodeSymbols;
            if (symbol is null) return;
            auto info = model.symbols.get(*symbol);
            if (info.kind != SymbolKind.variableSymbol && info.kind != SymbolKind.parameterSymbol) return;
            auto value = state.values.get(*symbol, FlowValue(info.initialized ? InitState.initialized : InitState.uninitialized, 0, info.declaration));
            if (writeContext || node.kind == NodeKind.outArgument) return;
            if (value.state != InitState.initialized) {
                string rule = value.state == InitState.moved ? "OPENC-OWN-USE-AFTER-MOVE-001" :
                    value.state == InitState.destroyed ? "OPENC-LIFETIME-USE-AFTER-DESTROY-001" : "OPENC-SAFE-INIT-001";
                string message = value.state == InitState.moved ? "value is used after ownership moved" :
                    value.state == InitState.destroyed ? "value is used after destruction" : "value is not definitely initialized";
                Diagnostic diagnostic;
                diagnostic.rule = rule;
                diagnostic.category = "flow.state";
                diagnostic.severity = DiagnosticSeverity.error;
                diagnostic.phase = DiagnosticPhase.flow;
                diagnostic.message = message;
                diagnostic.span = node.span;
                if (value.origin !is null) diagnostic.related ~= RelatedLocation(DiagnosticSeverity.note, "state originates here", value.origin.span);
                diagnostics.emit(diagnostic);
            }
            return;
        }
        if (node.kind == NodeKind.assignmentExpr) {
            inspectExpression(node.children[1], state, false);
            inspectExpression(node.children[0], state, true);
            markInitialized(node.children[0], state, node);
            return;
        }
        if (node.kind == NodeKind.callExpr) {
            inspectExpression(node.children[0], state, false);
            size_t lineage = nextLineage++;
            bool fallible = model.typeOf(node) == model.types.statusType;
            foreach (argument; node.children[1 .. $]) {
                if (argument.kind == NodeKind.outArgument) {
                    auto symbol = argument.id in model.nodeSymbols;
                    if (symbol !is null) state.values[*symbol] = FlowValue(fallible ? InitState.conditional : InitState.initialized, lineage, node);
                } else inspectExpression(argument, state, false);
            }
            return;
        }
        if (node.kind == NodeKind.destroyExpr) {
            foreach (child; node.children) {
                inspectExpression(child, state, false);
                markState(child, state, InitState.destroyed, node);
            }
            return;
        }
        if (node.kind == NodeKind.constructExpr) {
            // A storage binding denotes an allocated slot, not a live value.
            // Constructing into it is therefore a write even before an object
            // has been initialized in that slot.
            inspectExpression(node.children[0], state, true);
            inspectExpression(node.children[1], state, false);
            return;
        }
        foreach (child; node.children) inspectExpression(child, state, false);
    }

    void markInitialized(AstNode node, ref FlowEnvironment state, AstNode origin) {
        markState(node, state, InitState.initialized, origin);
    }

    void markState(AstNode node, ref FlowEnvironment state, InitState newState, AstNode origin) {
        if (node is null) return;
        auto symbol = node.id in model.nodeSymbols;
        if (symbol !is null) state.values[*symbol] = FlowValue(newState, 0, origin);
    }

    FlowEnvironment refineForEdge(FlowEnvironment state, EdgeKind kind, AstNode condition) {
        if (condition is null) return state;
        // Associative arrays have reference semantics. Each CFG edge must refine
        // an independent snapshot or the first branch will corrupt its sibling.
        state.values = state.values.dup;
        bool successBranch;
        bool known = extractStatusProof(condition, kind == EdgeKind.trueBranch, successBranch, state);
        if (!known) return state;
        foreach (symbol, value; state.values) {
            if (value.state == InitState.conditional) {
                state.values[symbol] = FlowValue(successBranch ? InitState.initialized : InitState.uninitialized, 0, condition);
            }
        }
        return state;
    }

    bool extractStatusProof(AstNode condition, bool branchTruth, out bool success, ref FlowEnvironment state) {
        if (condition.kind == NodeKind.unaryExpr && condition.text == "!") {
            bool nested;
            if (extractStatusProof(condition.children[0], !branchTruth, nested, state)) { success = nested; return true; }
        }
        if ((condition.kind == NodeKind.memberExpr && condition.text == "ok") ||
            (condition.kind == NodeKind.qualifiedName && condition.text.endsWith(".ok"))) {
            auto statusMember = condition.kind == NodeKind.qualifiedName ||
                model.typeOf(condition.children[0]) == model.types.statusType;
            if (statusMember) {
                success = branchTruth; return true;
            }
        }
        if (condition.kind == NodeKind.binaryExpr && (condition.text == "==" || condition.text == "!=")) {
            auto left = condition.children[0];
            auto right = condition.children[1];
            if (((left.kind == NodeKind.memberExpr && left.text == "code") ||
                (left.kind == NodeKind.qualifiedName && left.text.endsWith(".code"))) &&
                right.kind == NodeKind.integerLiteral && right.text == "0") {
                bool equalsZero = condition.text == "==";
                success = branchTruth ? equalsZero : !equalsZero;
                return true;
            }
        }
        return false;
    }

    FlowEnvironment merge(FlowEnvironment a, FlowEnvironment b) {
        if (!a.reachable) return b;
        if (!b.reachable) return a;
        FlowEnvironment result;
        foreach (symbol, left; a.values) {
            auto right = symbol in b.values;
            if (right is null) {
                result.values[symbol] = FlowValue(InitState.maybeInitialized, 0, left.origin);
                continue;
            }
            result.values[symbol] = mergeValue(left, *right);
        }
        foreach (symbol, right; b.values) {
            if (symbol !in result.values && symbol !in a.values) result.values[symbol] = FlowValue(InitState.maybeInitialized, 0, right.origin);
        }
        return result;
    }

    FlowValue mergeValue(FlowValue a, FlowValue b) {
        if (a.state == b.state && a.lineage == b.lineage) return a;
        if (a.state == InitState.initialized && b.state == InitState.initialized) return FlowValue(InitState.initialized, 0, a.origin);
        if (a.state == InitState.uninitialized && b.state == InitState.uninitialized) return FlowValue(InitState.uninitialized, 0, a.origin);
        if (a.state == InitState.conditional && b.state == InitState.conditional && a.lineage == b.lineage) return a;
        if (a.state == InitState.moved && b.state == InitState.moved) return a;
        if (a.state == InitState.destroyed && b.state == InitState.destroyed) return a;
        return FlowValue(InitState.maybeInitialized, 0, a.origin);
    }
}
