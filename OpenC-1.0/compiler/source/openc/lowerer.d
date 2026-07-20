module openc.lowerer;

import openc.ast : AstNode, NodeKind;
import openc.common : BlockId, SymbolId, TypeId, ValueId;
import openc.ir : IrBlock, IrFunction, IrInstruction, IrModule, IrOpcode, IrOperand, IrProgram;
import openc.semantic_model : SemanticModel;
import openc.source : SourceSpan;
import openc.symbol : Visibility;
import openc.symbol : SymbolKind;
import openc.types : TypeKind;
import std.algorithm.searching : canFind;
import std.conv : to;
import std.string : indexOf;

final class Lowerer {
private:
    SemanticModel model;
    ValueId nextValue = 1;
    IrFunction currentFunction;
    IrBlock currentBlock;
    ValueId[SymbolId] locals;
    IrBlock[] breakTargets;
    IrBlock[] continueTargets;

public:
    this(SemanticModel model) {
        this.model = model;
    }

    IrProgram lower() {
        auto program = new IrProgram();
        foreach (logical; model.modules.modules) {
            auto moduleValue = new IrModule();
            moduleValue.name = logical.name;
            foreach (_, importName; logical.shortImports) moduleValue.imports ~= importName;
            foreach (unit; logical.units) {
                foreach (node; unit.root.children) {
                    if (node.kind == NodeKind.functionDecl) {
                        if (node.flag("prototype")) continue;
                        auto functionValue = lowerFunction(node);
                        moduleValue.functions ~= functionValue;
                        if (functionValue.name == logical.name ~ ".main") {
                            program.entryModule = logical.name;
                            program.entryFunction = "main";
                        }
                    }
                }
            }
            program.modules ~= moduleValue;
        }
        return program;
    }

private:
    IrFunction lowerFunction(AstNode node) {
        auto symbol = model.symbols.get(model.nodeSymbols[node.id]);
        currentFunction = new IrFunction();
        currentFunction.name = symbol.qualifiedName;
        currentFunction.result = symbol.signature.result;
        currentFunction.parameters = symbol.signature.parameters.dup;
        currentFunction.parameterModes = symbol.signature.modes.dup;
        currentFunction.unsafeFunction = symbol.signature.unsafeFunction;
        currentFunction.exported = symbol.visibility == Visibility.exported;
        foreach (child; node.children) if (child.kind == NodeKind.parameter) currentFunction.parameterNames ~= child.text;
        currentBlock = currentFunction.addBlock("entry");
        locals = null;
        foreach (child; node.children) {
            if (child.kind != NodeKind.parameter) continue;
            auto symbolId = model.nodeSymbols[child.id];
            auto localType = model.symbols.get(symbolId).type;
            auto mode = child.get("mode", "value");
            if (mode == "out" || mode == "out_own") {
                localType = model.types.reference(localType, false);
            }
            locals[symbolId] = emit(IrOpcode.allocateLocal, localType, child.span, child.text);
        }
        lowerBlock(node.children[$ - 1]);
        if (currentFunction.result == model.types.voidType &&
            (currentBlock.instructions.length == 0 ||
            (currentBlock.instructions[$ - 1].opcode != IrOpcode.returnValue &&
             currentBlock.instructions[$ - 1].opcode != IrOpcode.returnVoid))) {
            emit(IrOpcode.returnVoid, model.types.voidType, node.span);
        }
        return currentFunction;
    }

    void lowerBlock(AstNode block) {
        foreach (node; block.children) {
            if (node.kind == NodeKind.localDecl) {
                auto symbolId = model.nodeSymbols[node.id];
                auto address = emit(IrOpcode.allocateLocal, model.symbols.get(symbolId).type, node.span, node.text);
                locals[symbolId] = address;
                if (node.children.length > 1 && node.children[1] !is null) {
                    auto expected = model.symbols.get(symbolId).type;
                    auto value = lowerWithContext(node.children[1], expected);
                    emitVoid(IrOpcode.store, node.span, [
                        IrOperand(address, model.types.get(expected).kind == TypeKind.reference ? "bind" : ""),
                        IrOperand(value, "")]);
                }
            } else lowerStatement(node);
        }
    }

    void lowerStatement(AstNode node) {
        switch (node.kind) {
            case NodeKind.block: lowerBlock(node); break;
            case NodeKind.expressionStmt: lowerExpression(node.children[0]); break;
            case NodeKind.returnStmt:
                if (node.children.length && node.children[0] !is null) {
                    auto value = lowerWithContext(node.children[0], currentFunction.result);
                    emitVoid(IrOpcode.returnValue, node.span, [IrOperand(value, "")]);
                } else emitVoid(IrOpcode.returnVoid, node.span);
                break;
            case NodeKind.scopeStmt: lowerScope(node); break;
            case NodeKind.ifStmt: lowerIf(node); break;
            case NodeKind.whileStmt: lowerWhile(node); break;
            case NodeKind.forStmt: lowerFor(node); break;
            case NodeKind.switchStmt: lowerSwitch(node); break;
            case NodeKind.breakStmt:
                if (breakTargets.length) emitVoid(IrOpcode.branch, node.span,
                    [IrOperand(0, breakTargets[$ - 1].id.to!string)]);
                break;
            case NodeKind.continueStmt:
                if (continueTargets.length) emitVoid(IrOpcode.branch, node.span,
                    [IrOperand(0, continueTargets[$ - 1].id.to!string)]);
                break;
            case NodeKind.unsafeStmt: lowerBlock(node.children[0]); break;
            case NodeKind.whenStmt:
                auto selected = model.boolConstants.get(node.children[0].id, false);
                if (selected) lowerBlock(node.children[1]);
                break;
            default: break;
        }
    }

    void lowerIf(AstNode node) {
        auto condition = lowerExpression(node.children[0]);
        auto thenBlock = currentFunction.addBlock("if.then");
        auto elseBlock = currentFunction.addBlock("if.else");
        auto mergeBlock = currentFunction.addBlock("if.merge");
        emitVoid(IrOpcode.conditionalBranch, node.children[0].span,
            [IrOperand(condition, ""), IrOperand(0, thenBlock.id.to!string), IrOperand(0, elseBlock.id.to!string)]);
        currentBlock = thenBlock;
        lowerStatement(node.children[1]);
        emitVoid(IrOpcode.branch, node.span, [IrOperand(0, mergeBlock.id.to!string)]);
        currentBlock = elseBlock;
        if (node.children.length > 2) lowerStatement(node.children[2]);
        emitVoid(IrOpcode.branch, node.span, [IrOperand(0, mergeBlock.id.to!string)]);
        currentBlock = mergeBlock;
    }

    void lowerWhile(AstNode node) {
        auto header = currentFunction.addBlock("while.header");
        auto body = currentFunction.addBlock("while.body");
        auto after = currentFunction.addBlock("while.after");
        emitVoid(IrOpcode.branch, node.span, [IrOperand(0, header.id.to!string)]);
        currentBlock = header;
        auto condition = lowerExpression(node.children[0]);
        emitVoid(IrOpcode.conditionalBranch, node.children[0].span,
            [IrOperand(condition, ""), IrOperand(0, body.id.to!string), IrOperand(0, after.id.to!string)]);
        currentBlock = body;
        breakTargets ~= after;
        continueTargets ~= header;
        lowerStatement(node.children[1]);
        breakTargets.length = breakTargets.length - 1;
        continueTargets.length = continueTargets.length - 1;
        emitVoid(IrOpcode.branch, node.span, [IrOperand(0, header.id.to!string)]);
        currentBlock = after;
    }

    void lowerFor(AstNode node) {
        foreach (index, child; node.children) {
            if (child is null) continue;
            if (index == node.children.length - 1 && child.kind == NodeKind.block) break;
            if (child.kind == NodeKind.localDecl) {
                auto symbolId = model.nodeSymbols[child.id];
                locals[symbolId] = emit(IrOpcode.allocateLocal, model.symbols.get(symbolId).type, child.span, child.text);
                if (child.children.length > 1) {
                    auto value = lowerExpression(child.children[1]);
                    emitVoid(IrOpcode.store, child.span, [IrOperand(locals[symbolId], ""), IrOperand(value, "")]);
                }
            }
        }
        auto condition = node.children.length > 1 ? node.children[1] : null;
        auto step = node.children.length > 2 ? node.children[2] : null;
        auto header = currentFunction.addBlock("for.header");
        auto body = currentFunction.addBlock("for.body");
        auto stepBlock = currentFunction.addBlock("for.step");
        auto after = currentFunction.addBlock("for.after");
        emitVoid(IrOpcode.branch, node.span, [IrOperand(0, header.id.to!string)]);
        currentBlock = header;
        if (condition !is null) {
            auto value = lowerExpression(condition);
            emitVoid(IrOpcode.conditionalBranch, condition.span,
                [IrOperand(value, ""), IrOperand(0, body.id.to!string), IrOperand(0, after.id.to!string)]);
        } else emitVoid(IrOpcode.branch, node.span, [IrOperand(0, body.id.to!string)]);
        currentBlock = body;
        breakTargets ~= after;
        continueTargets ~= stepBlock;
        lowerBlock(node.children[$ - 1]);
        breakTargets.length = breakTargets.length - 1;
        continueTargets.length = continueTargets.length - 1;
        emitVoid(IrOpcode.branch, node.span, [IrOperand(0, stepBlock.id.to!string)]);
        currentBlock = stepBlock;
        if (step !is null && step.kind != NodeKind.block) lowerExpression(step);
        emitVoid(IrOpcode.branch, node.span, [IrOperand(0, header.id.to!string)]);
        currentBlock = after;
    }

    void lowerSwitch(AstNode node) {
        auto subject = lowerExpression(node.children[0]);
        auto after = currentFunction.addBlock("switch.after");
        auto dispatch = currentBlock;
        breakTargets ~= after;
        foreach (index, child; node.children[1 .. $]) {
            auto caseBlock = currentFunction.addBlock(child.kind == NodeKind.defaultCase ? "switch.default" : "switch.case");
            currentBlock = dispatch;
            if (child.kind == NodeKind.switchCase) {
                auto caseValue = lowerExpression(child.children[0]);
                auto compare = emit(IrOpcode.compare, model.types.boolType, child.span, "==",
                    [IrOperand(subject, ""), IrOperand(caseValue, "")]);
                auto next = index + 1 < node.children.length - 1
                    ? currentFunction.addBlock("switch.next") : after;
                emitVoid(IrOpcode.conditionalBranch, child.span,
                    [IrOperand(compare, ""), IrOperand(0, caseBlock.id.to!string), IrOperand(0, next.id.to!string)]);
                dispatch = next;
                currentBlock = caseBlock;
                lowerBlock(child.children[1]);
            } else {
                emitVoid(IrOpcode.branch, child.span, [IrOperand(0, caseBlock.id.to!string)]);
                currentBlock = caseBlock;
                lowerBlock(child.children[0]);
                dispatch = after;
            }
            emitVoid(IrOpcode.branch, child.span, [IrOperand(0, after.id.to!string)]);
        }
        breakTargets.length = breakTargets.length - 1;
        currentBlock = after;
    }

    ValueId lowerExpression(AstNode node) {
        if (node is null) return 0;
        switch (node.kind) {
            case NodeKind.integerLiteral: return emit(IrOpcode.constantInteger, model.typeOf(node), node.span, node.text);
            case NodeKind.floatLiteral: return emit(IrOpcode.constantFloat, model.typeOf(node), node.span, node.text);
            case NodeKind.textLiteral: return emit(IrOpcode.constantText, model.typeOf(node), node.span, node.text);
            case NodeKind.boolLiteral: return emit(IrOpcode.constantBool, model.typeOf(node), node.span, node.text);
            case NodeKind.nullLiteral: return emit(IrOpcode.nop, model.typeOf(node), node.span, "null");
            case NodeKind.noneLiteral: return emit(IrOpcode.optionalNone, model.typeOf(node), node.span);
            case NodeKind.qualifiedName:
                auto symbol = node.id in model.nodeSymbols;
                if (symbol !is null) {
                    if (*symbol in locals) return emit(IrOpcode.load, model.typeOf(node), node.span, "", [IrOperand(locals[*symbol], "")]);
                    auto info = model.symbols.get(*symbol);
                    if (info.kind == SymbolKind.enumItemSymbol && info.declaration !is null) {
                        return emit(IrOpcode.constantInteger, info.type, node.span,
                            model.integerConstants.get(info.declaration.id, 0).to!string);
                    }
                }
                auto path = lowerQualifiedPath(node);
                if (path) return path;
                return emit(IrOpcode.nop, model.typeOf(node), node.span, node.text);
            case NodeKind.unaryExpr:
                if (node.text == "-" && node.children[0].kind == NodeKind.integerLiteral) {
                    return emit(
                        IrOpcode.constantInteger,
                        model.typeOf(node),
                        node.span,
                        "-" ~ node.children[0].text);
                }
                if (node.text == "&") return lowerPointerTo(node.children[0]);
                auto operand = lowerExpression(node.children[0]);
                if (node.text == "*" && model.pointerTargetFaults.get(node.id, false)) {
                    currentBlock.instructions ~= IrInstruction(
                        0, IrOpcode.targetFault, model.types.voidType, [],
                        "invalid pointer dereference", node.span);
                    return emit(IrOpcode.nop, model.typeOf(node), node.span, "target-fault");
                }
                auto opcode = node.text == "&" ? IrOpcode.addressOf : IrOpcode.unary;
                return emit(opcode, model.typeOf(node), node.span, node.text, [IrOperand(operand, "")]);
            case NodeKind.binaryExpr:
                auto left = lowerExpression(node.children[0]);
                if (node.text == "&&" || node.text == "||") {
                    auto result = emit(IrOpcode.shortCircuitBegin, model.types.boolType,
                        node.span, node.text, [IrOperand(left, "")]);
                    auto right = lowerExpression(node.children[1]);
                    currentBlock.instructions ~= IrInstruction(
                        0, IrOpcode.shortCircuitEnd, model.types.voidType,
                        [IrOperand(result, ""), IrOperand(right, "")], node.text, node.span);
                    return result;
                }
                auto right = lowerExpression(node.children[1]);
                if (model.pointerTargetFaults.get(node.id, false)) {
                    currentBlock.instructions ~= IrInstruction(
                        0, IrOpcode.targetFault, model.types.voidType, [],
                        "invalid pointer operation", node.span);
                    return emit(IrOpcode.nop, model.typeOf(node), node.span, "target-fault");
                }
                auto opcode = ["==", "!=", "<", "<=", ">", ">="].canFind(node.text) ? IrOpcode.compare : IrOpcode.binary;
                return emit(opcode, model.typeOf(node), node.span, node.text, [IrOperand(left, ""), IrOperand(right, "")]);
            case NodeKind.assignmentExpr:
                auto destination = lowerAddress(node.children[0]);
                auto expected = model.typeOf(node.children[0]);
                if (model.types.get(expected).kind == TypeKind.reference) {
                    expected = model.types.get(expected).element;
                }
                auto value = lowerWithContext(node.children[1], expected);
                auto destinationMode = node.children[0].kind == NodeKind.unaryExpr &&
                    node.children[0].text == "*" ||
                    node.children[0].kind == NodeKind.memberExpr ||
                    node.children[0].kind == NodeKind.indexExpr ||
                    (node.children[0].kind == NodeKind.qualifiedName &&
                     node.children[0].text.indexOf('.') >= 0)
                    ? "deref" : "";
                emitVoid(IrOpcode.store, node.span,
                    [IrOperand(destination, destinationMode), IrOperand(value, "")]);
                return value;
            case NodeKind.callExpr:
                IrOperand[] args;
                auto target = node.id in model.nodeSymbols;
                foreach (index, argument; node.children[1 .. $]) {
                    auto expected = target is null || index >= model.symbols.get(*target).signature.parameters.length
                        ? model.typeOf(argument)
                        : model.symbols.get(*target).signature.parameters[index];
                    args ~= IrOperand(lowerWithContext(argument, expected), "");
                }
                return emit(IrOpcode.call, model.typeOf(node), node.span, callName(node), args);
            case NodeKind.memberExpr:
                auto base = lowerExpression(node.children[0]);
                return emit(IrOpcode.aggregateField, model.typeOf(node), node.span, node.text, [IrOperand(base, "")]);
            case NodeKind.indexExpr:
                auto aggregate = lowerExpression(node.children[0]);
                auto index = lowerExpression(node.children[1]);
                emitVoid(IrOpcode.boundsCheck, node.span, [IrOperand(aggregate, ""), IrOperand(index, "")]);
                return emit(IrOpcode.aggregateField, model.typeOf(node), node.span, "index", [IrOperand(aggregate, ""), IrOperand(index, "")]);
            case NodeKind.rangeExpr:
                IrOperand[] rangeArgs = [IrOperand(lowerExpression(node.children[0]), "")];
                foreach (child; node.children[1 .. $]) rangeArgs ~= IrOperand(child is null ? 0 : lowerExpression(child), "");
                return emit(IrOpcode.sliceCreate, model.typeOf(node), node.span, "range", rangeArgs);
            case NodeKind.castExpr: return emit(IrOpcode.castValue, model.typeOf(node), node.span, node.text, [IrOperand(lowerExpression(node.children[1]), "")]);
            case NodeKind.reinterpretExpr: return emit(IrOpcode.reinterpret, model.typeOf(node), node.span, node.text, [IrOperand(lowerExpression(node.children[1]), "")]);
            case NodeKind.constructExpr:
                auto storageType = model.types.get(model.typeOf(node.children[0]));
                return emit(IrOpcode.objectConstruct, model.typeOf(node), node.span, node.text, [
                    IrOperand(lowerAddress(node.children[0]), ""),
                    IrOperand(lowerWithContext(node.children[1], storageType.element), "")]);
            case NodeKind.destroyExpr:
                auto owner = lowerExpression(node.children[0]);
                emitVoid(IrOpcode.objectDestroy, node.span, [IrOperand(owner, "")]); return 0;
            case NodeKind.typeQueryExpr: return emit(IrOpcode.constantInteger, model.typeOf(node), node.span, model.integerConstants.get(node.id, 0).to!string);
            case NodeKind.statusInitializer:
                IrOperand[] statusArgs;
                foreach (field; node.children) statusArgs ~= IrOperand(lowerExpression(field.children[0]), field.text);
                return emit(IrOpcode.statusCreate, model.types.statusType, node.span, "status", statusArgs);
            case NodeKind.aggregateInitializer:
                IrOperand[] fields;
                foreach (field; node.children[1 .. $]) {
                    auto fieldId = field.id in model.nodeSymbols;
                    auto expected = fieldId is null ? model.typeOf(field.children[0]) : model.symbols.get(*fieldId).type;
                    fields ~= IrOperand(lowerWithContext(field.children[0], expected),
                        field.text ~ (field.flag("own") ? ":own" : ""));
                }
                return emit(IrOpcode.aggregateCreate, model.typeOf(node), node.span, node.text, fields);
            case NodeKind.arrayInitializer:
                IrOperand[] elements;
                foreach (child; node.children) elements ~= IrOperand(lowerExpression(child), "");
                return emit(IrOpcode.arrayCreate, model.typeOf(node), node.span, "", elements);
            case NodeKind.outArgument: return lowerAddress(node);
            default: return 0;
        }
    }

    ValueId lowerWithContext(AstNode node, TypeId expected) {
        auto expectedInfo = model.types.get(expected);
        auto actual = model.typeOf(node);
        if (expectedInfo.kind == TypeKind.reference) {
            auto actualInfo = model.types.get(actual);
            if (model.types.lossless(actual, expectedInfo.element, model.target) ||
                (actualInfo.kind == TypeKind.reference &&
                 model.types.lossless(actualInfo.element, expectedInfo.element, model.target))) {
                return lowerPointerTo(node);
            }
        }
        auto value = lowerExpression(node);
        if (expectedInfo.kind == TypeKind.optional &&
            model.types.lossless(actual, expectedInfo.element, model.target)) {
            return emit(IrOpcode.optionalSome, expected, node.span, "some", [IrOperand(value, "")]);
        }
        return value;
    }

    ValueId lowerAddress(AstNode node) {
        if (node.kind == NodeKind.unaryExpr && node.text == "*") {
            return lowerExpression(node.children[0]);
        }
        if (node.kind == NodeKind.indexExpr) {
            auto aggregate = lowerAddress(node.children[0]);
            auto index = lowerExpression(node.children[1]);
            emitVoid(IrOpcode.boundsCheck, node.span,
                [IrOperand(aggregate, ""), IrOperand(index, "")]);
            return emit(IrOpcode.aggregateField, model.typeOf(node), node.span,
                "index:address", [IrOperand(aggregate, ""), IrOperand(index, "")]);
        }
        if (node.kind == NodeKind.memberExpr) {
            auto aggregate = lowerAddress(node.children[0]);
            return emit(IrOpcode.aggregateField, model.typeOf(node), node.span,
                node.text ~ ":address", [IrOperand(aggregate, "")]);
        }
        if (node.kind == NodeKind.qualifiedName) {
            auto path = lowerQualifiedPath(node, true);
            if (path) return path;
        }
        auto symbol = node.id in model.nodeSymbols;
        if (symbol !is null && *symbol in locals) return locals[*symbol];
        return lowerExpression(node);
    }

    ValueId lowerPointerTo(AstNode node) {
        if (model.types.get(model.typeOf(node)).kind == TypeKind.reference) {
            return lowerExpression(node);
        }
        if (node.kind == NodeKind.memberExpr || node.kind == NodeKind.indexExpr ||
            (node.kind == NodeKind.unaryExpr && node.text == "*") ||
            (node.kind == NodeKind.qualifiedName && node.text.indexOf('.') >= 0)) {
            return lowerAddress(node);
        }
        if (node.kind == NodeKind.qualifiedName) {
            auto symbol = node.id in model.nodeSymbols;
            if (symbol !is null && *symbol in locals) {
                auto info = model.symbols.get(*symbol);
                auto mode = info.declaration is null ? "" : info.declaration.get("mode");
                if (model.types.get(info.type).kind == TypeKind.reference ||
                    mode == "out" || mode == "out_own") return locals[*symbol];
            }
        }
        auto address = lowerAddress(node);
        auto element = model.typeOf(node);
        if (model.types.get(element).kind == TypeKind.reference) {
            element = model.types.get(element).element;
        }
        return emit(IrOpcode.addressOf, model.types.pointer(element, false),
            node.span, "&", [IrOperand(address, "")]);
    }

    void lowerScope(AstNode node) {
        auto action = node.children[0];
        IrOperand[] operands;
        string text;
        if (action.kind == NodeKind.callExpr) {
            text = callName(action);
            foreach (argument; action.children[1 .. $]) {
                operands ~= IrOperand(lowerExpression(argument), "");
            }
        } else if (action.kind == NodeKind.destroyExpr) {
            text = "destroy";
            operands ~= IrOperand(lowerExpression(action.children[0]), "");
        } else {
            text = "unsupported";
        }
        currentBlock.instructions ~= IrInstruction(
            0, IrOpcode.scopeRegister, model.types.voidType,
            operands, text, node.span);
    }

    ValueId lowerQualifiedPath(AstNode node, bool address = false) {
        auto dot = node.text.indexOf('.');
        if (dot < 0) return 0;
        auto baseName = node.text[0 .. dot];
        auto member = node.text[dot + 1 .. $];
        foreach (symbolId, value; locals) {
            if (model.symbols.get(symbolId).name != baseName) continue;
            return emit(
                IrOpcode.aggregateField,
                model.typeOf(node),
                node.span,
                member ~ (address ? ":address" : ""),
                [IrOperand(value, "")]);
        }
        return 0;
    }

    string callName(AstNode node) {
        auto target = node.id in model.nodeSymbols;
        return target is null ? node.children[0].text : model.symbols.get(*target).qualifiedName;
    }

    ValueId emit(IrOpcode opcode, TypeId type, SourceSpan span, string text = "", IrOperand[] operands = []) {
        auto id = nextValue++;
        currentBlock.instructions ~= IrInstruction(id, opcode, type, operands, text, span);
        return id;
    }

    void emitVoid(IrOpcode opcode, SourceSpan span, IrOperand[] operands = []) {
        currentBlock.instructions ~= IrInstruction(0, opcode, model.types.voidType, operands, "", span);
    }
}
