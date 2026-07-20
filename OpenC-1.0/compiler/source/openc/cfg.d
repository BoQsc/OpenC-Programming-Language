module openc.cfg;

import openc.ast : AstNode, NodeKind;
import openc.common : BlockId;
import openc.source : SourceSpan;

enum EdgeKind : string {
    fallthrough = "fallthrough",
    trueBranch = "true",
    falseBranch = "false",
    loopBack = "loop_back",
    breakEdge = "break",
    continueEdge = "continue",
    returnEdge = "return",
    failureEdge = "failure"
}

struct CfgEdge {
    BlockId from;
    BlockId to;
    EdgeKind kind;
    AstNode condition;
}

final class BasicBlock {
    BlockId id;
    AstNode[] statements;
    bool terminal;
    string label;

    this(BlockId id, string label) {
        this.id = id;
        this.label = label;
    }
}

final class ControlFlowGraph {
    BasicBlock[] blocks;
    CfgEdge[] edges;
    BlockId entry;
    BlockId exit;

    BasicBlock addBlock(string label) {
        auto id = cast(BlockId) blocks.length;
        auto block = new BasicBlock(id, label);
        blocks ~= block;
        return block;
    }

    void connect(BlockId from, BlockId to, EdgeKind kind, AstNode condition = null) {
        edges ~= CfgEdge(from, to, kind, condition);
    }

    BlockId[] successors(BlockId block) const {
        BlockId[] result;
        foreach (edge; edges) if (edge.from == block) result ~= edge.to;
        return result;
    }

    BlockId[] predecessors(BlockId block) const {
        BlockId[] result;
        foreach (edge; edges) if (edge.to == block) result ~= edge.from;
        return result;
    }
}

final class CfgBuilder {
private:
    ControlFlowGraph graph;
    BlockId current;
    BlockId[] breakTargets;
    BlockId[] continueTargets;

public:
    ControlFlowGraph build(AstNode functionBody) {
        graph = new ControlFlowGraph();
        auto entry = graph.addBlock("entry");
        auto exit = graph.addBlock("exit");
        graph.entry = entry.id;
        graph.exit = exit.id;
        current = entry.id;
        buildBlock(functionBody);
        if (!graph.blocks[current].terminal) graph.connect(current, graph.exit, EdgeKind.fallthrough);
        return graph;
    }

private:
    void buildBlock(AstNode block) {
        foreach (statement; block.children) {
            if (graph.blocks[current].terminal) {
                auto unreachable = graph.addBlock("unreachable");
                current = unreachable.id;
            }
            buildStatement(statement);
        }
    }

    void buildStatement(AstNode node) {
        switch (node.kind) {
            case NodeKind.ifStmt: buildIf(node); break;
            case NodeKind.whileStmt: buildWhile(node); break;
            case NodeKind.forStmt: buildFor(node); break;
            case NodeKind.switchStmt: buildSwitch(node); break;
            case NodeKind.returnStmt:
                graph.blocks[current].statements ~= node;
                graph.blocks[current].terminal = true;
                graph.connect(current, graph.exit, EdgeKind.returnEdge, node.children.length ? node.children[0] : null);
                break;
            case NodeKind.breakStmt:
                graph.blocks[current].statements ~= node;
                graph.blocks[current].terminal = true;
                if (breakTargets.length) graph.connect(current, breakTargets[$ - 1], EdgeKind.breakEdge);
                break;
            case NodeKind.continueStmt:
                graph.blocks[current].statements ~= node;
                graph.blocks[current].terminal = true;
                if (continueTargets.length) graph.connect(current, continueTargets[$ - 1], EdgeKind.continueEdge);
                break;
            case NodeKind.block: buildBlock(node); break;
            default: graph.blocks[current].statements ~= node; break;
        }
    }

    void buildIf(AstNode node) {
        graph.blocks[current].statements ~= node.children[0];
        auto conditionBlock = current;
        auto thenBlock = graph.addBlock("if.then");
        auto mergeBlock = graph.addBlock("if.merge");
        BasicBlock elseBlock;
        if (node.children.length > 2) elseBlock = graph.addBlock("if.else");
        graph.connect(conditionBlock, thenBlock.id, EdgeKind.trueBranch, node.children[0]);
        graph.connect(conditionBlock, elseBlock is null ? mergeBlock.id : elseBlock.id, EdgeKind.falseBranch, node.children[0]);
        current = thenBlock.id;
        buildStatement(node.children[1]);
        if (!graph.blocks[current].terminal) graph.connect(current, mergeBlock.id, EdgeKind.fallthrough);
        if (elseBlock !is null) {
            current = elseBlock.id;
            buildStatement(node.children[2]);
            if (!graph.blocks[current].terminal) graph.connect(current, mergeBlock.id, EdgeKind.fallthrough);
        }
        current = mergeBlock.id;
    }

    void buildWhile(AstNode node) {
        auto header = graph.addBlock("while.header");
        auto body = graph.addBlock("while.body");
        auto after = graph.addBlock("while.after");
        graph.connect(current, header.id, EdgeKind.fallthrough);
        header.statements ~= node.children[0];
        graph.connect(header.id, body.id, EdgeKind.trueBranch, node.children[0]);
        graph.connect(header.id, after.id, EdgeKind.falseBranch, node.children[0]);
        breakTargets ~= after.id;
        continueTargets ~= header.id;
        current = body.id;
        buildStatement(node.children[1]);
        if (!graph.blocks[current].terminal) graph.connect(current, header.id, EdgeKind.loopBack);
        breakTargets.length = breakTargets.length - 1;
        continueTargets.length = continueTargets.length - 1;
        current = after.id;
    }

    void buildFor(AstNode node) {
        if (node.children.length) buildStatement(node.children[0]);
        auto header = graph.addBlock("for.header");
        auto body = graph.addBlock("for.body");
        auto step = graph.addBlock("for.step");
        auto after = graph.addBlock("for.after");
        graph.connect(current, header.id, EdgeKind.fallthrough);
        AstNode condition = node.children.length > 1 ? node.children[1] : null;
        if (condition !is null) header.statements ~= condition;
        graph.connect(header.id, body.id, EdgeKind.trueBranch, condition);
        if (condition !is null) graph.connect(header.id, after.id, EdgeKind.falseBranch, condition);
        breakTargets ~= after.id;
        continueTargets ~= step.id;
        current = body.id;
        buildStatement(node.children[$ - 1]);
        if (!graph.blocks[current].terminal) graph.connect(current, step.id, EdgeKind.fallthrough);
        current = step.id;
        if (node.children.length > 2 && node.children[2] !is null && node.children[2].kind != NodeKind.block) step.statements ~= node.children[2];
        graph.connect(step.id, header.id, EdgeKind.loopBack);
        breakTargets.length = breakTargets.length - 1;
        continueTargets.length = continueTargets.length - 1;
        current = after.id;
    }

    void buildSwitch(AstNode node) {
        graph.blocks[current].statements ~= node.children[0];
        auto dispatch = current;
        auto after = graph.addBlock("switch.after");
        breakTargets ~= after.id;
        foreach (child; node.children[1 .. $]) {
            auto caseBlock = graph.addBlock(child.kind == NodeKind.defaultCase ? "switch.default" : "switch.case");
            graph.connect(dispatch, caseBlock.id, child.kind == NodeKind.defaultCase ? EdgeKind.falseBranch : EdgeKind.trueBranch,
                child.kind == NodeKind.switchCase ? child.children[0] : null);
            current = caseBlock.id;
            buildStatement(child.kind == NodeKind.switchCase ? child.children[1] : child.children[0]);
            if (!graph.blocks[current].terminal) graph.connect(current, after.id, EdgeKind.fallthrough);
        }
        breakTargets.length = breakTargets.length - 1;
        current = after.id;
    }
}
