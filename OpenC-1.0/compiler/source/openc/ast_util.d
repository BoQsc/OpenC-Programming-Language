module openc.ast_util;

import openc.ast : AstNode, NodeKind;

void walk(AstNode node, void delegate(AstNode) visitor) {
    if (node is null) return;
    visitor(node);
    foreach (child; node.children) walk(child, visitor);
}

AstNode[] childrenOf(AstNode node, NodeKind kind) {
    AstNode[] result;
    if (node is null) return result;
    foreach (child; node.children) if (child !is null && child.kind == kind) result ~= child;
    return result;
}

AstNode firstChild(AstNode node, NodeKind kind) {
    if (node is null) return null;
    foreach (child; node.children) if (child !is null && child.kind == kind) return child;
    return null;
}

bool containsKind(AstNode node, NodeKind kind) {
    bool found;
    walk(node, (AstNode item) { if (item.kind == kind) found = true; });
    return found;
}
