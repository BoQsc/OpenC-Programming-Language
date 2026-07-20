module openc.lowerer;

import openc.ast : AstNode, NodeKind;
import openc.common : BlockId, SymbolId, TypeId, ValueId;
import openc.ir : IrBlock, IrFunction, IrInstruction, IrModule, IrOpcode, IrOperand, IrProgram;
import openc.semantic_model : SemanticModel;
import openc.source : SourceSpan;
import openc.symbol : Visibility;
import openc.types : TypeKind;
import std.algorithm.searching : canFind;
import std.conv : to;

final class Lowerer {
private:
    SemanticModel model;
    ValueId nextValue = 1;
    IrFunction currentFunction;
    IrBlock currentBlock;
    ValueId[SymbolId] locals;

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
            locals[symbolId] = emit(IrOpcode.allocateLocal, model.symbols.get(symbolId).type, child.span, child.text);
        }
        lowerBlock(node.children[$ - 1]);
        if (currentBlock.instructions.length == 0 ||
            (currentBlock.instructions[$ - 1].opcode != IrOpcode.returnValue && currentBlock.instructions[$ - 1].opcode != IrOpcode.returnVoid)) {
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
                    auto value = lowerExpression(node.children[1]);
                    emitVoid(IrOpcode.store, node.span, [IrOperand(address, ""), IrOperand(value, "")]);
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
                    auto value = lowerExpression(node.children[0]);
                    emitVoid(IrOpcode.returnValue, node.span, [IrOperand(value, "")]);
                } else emitVoid(IrOpcode.returnVoid, node.span);
                break;
            case NodeKind.scopeStmt:
                auto action = lowerExpression(node.children[0]);
                emitVoid(IrOpcode.scopeRegister, node.span, [IrOperand(action, "")]);
                break;
            case NodeKind.ifStmt: lowerIf(node); break;
            case NodeKind.whileStmt: lowerWhile(node); break;
            case NodeKind.forStmt: lowerFor(node); break;
            case NodeKind.switchStmt: lowerSwitch(node); break;
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
        lowerStatement(node.children[1]);
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
        lowerBlock(node.children[$ - 1]);
        emitVoid(IrOpcode.branch, node.span, [IrOperand(0, stepBlock.id.to!string)]);
        currentBlock = stepBlock;
        if (step !is null && step.kind != NodeKind.block) lowerExpression(step);
        emitVoid(IrOpcode.branch, node.span, [IrOperand(0, header.id.to!string)]);
        currentBlock = after;
    }

    void lowerSwitch(AstNode node) {
        auto subject = lowerExpression(node.children[0]);
        auto after = currentFunction.addBlock("switch.after");
        foreach (child; node.children[1 .. $]) {
            auto caseBlock = currentFunction.addBlock(child.kind == NodeKind.defaultCase ? "switch.default" : "switch.case");
            if (child.kind == NodeKind.switchCase) {
                auto caseValue = lowerExpression(child.children[0]);
                auto compare = emit(IrOpcode.compare, model.types.boolType, child.span, "==",
                    [IrOperand(subject, ""), IrOperand(caseValue, "")]);
                emitVoid(IrOpcode.conditionalBranch, child.span,
                    [IrOperand(compare, ""), IrOperand(0, caseBlock.id.to!string), IrOperand(0, after.id.to!string)]);
                currentBlock = caseBlock;
                lowerBlock(child.children[1]);
            } else {
                emitVoid(IrOpcode.branch, child.span, [IrOperand(0, caseBlock.id.to!string)]);
                currentBlock = caseBlock;
                lowerBlock(child.children[0]);
            }
            emitVoid(IrOpcode.branch, child.span, [IrOperand(0, after.id.to!string)]);
        }
        currentBlock = after;
    }

    ValueId lowerExpression(AstNode node) {
        if (node is null) return 0;
        switch (node.kind) {
            case NodeKind.integerLiteral: return emit(IrOpcode.constantInteger, model.typeOf(node), node.span, node.text);
            case NodeKind.floatLiteral: return emit(IrOpcode.constantFloat, model.typeOf(node), node.span, node.text);
            case NodeKind.textLiteral: return emit(IrOpcode.constantText, model.typeOf(node), node.span, node.text);
            case NodeKind.boolLiteral: return emit(IrOpcode.constantBool, model.typeOf(node), node.span, node.text);
            case NodeKind.noneLiteral: return emit(IrOpcode.optionalNone, model.typeOf(node), node.span);
            case NodeKind.qualifiedName:
                auto symbol = node.id in model.nodeSymbols;
                if (symbol !is null && *symbol in locals) return emit(IrOpcode.load, model.typeOf(node), node.span, "", [IrOperand(locals[*symbol], "")]);
                return emit(IrOpcode.nop, model.typeOf(node), node.span, node.text);
            case NodeKind.unaryExpr:
                if (node.text == "-" && node.children[0].kind == NodeKind.integerLiteral) {
                    return emit(
                        IrOpcode.constantInteger,
                        model.typeOf(node),
                        node.span,
                        "-" ~ node.children[0].text);
                }
                auto operand = lowerExpression(node.children[0]);
                auto opcode = node.text == "&" ? IrOpcode.addressOf : IrOpcode.unary;
                return emit(opcode, model.typeOf(node), node.span, node.text, [IrOperand(operand, "")]);
            case NodeKind.binaryExpr:
                auto left = lowerExpression(node.children[0]);
                auto right = lowerExpression(node.children[1]);
                auto opcode = ["==", "!=", "<", "<=", ">", ">="].canFind(node.text) ? IrOpcode.compare : IrOpcode.binary;
                return emit(opcode, model.typeOf(node), node.span, node.text, [IrOperand(left, ""), IrOperand(right, "")]);
            case NodeKind.assignmentExpr:
                auto destination = lowerAddress(node.children[0]);
                auto value = lowerExpression(node.children[1]);
                emitVoid(IrOpcode.store, node.span, [IrOperand(destination, ""), IrOperand(value, "")]);
                return value;
            case NodeKind.callExpr:
                IrOperand[] args;
                foreach (argument; node.children[1 .. $]) args ~= IrOperand(lowerExpression(argument), "");
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
            case NodeKind.constructExpr: return emit(IrOpcode.objectConstruct, model.typeOf(node), node.span, node.text, [IrOperand(lowerExpression(node.children[0]), "")]);
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
                foreach (field; node.children[1 .. $]) fields ~= IrOperand(lowerExpression(field.children[0]), field.text ~ (field.flag("own") ? ":own" : ""));
                return emit(IrOpcode.aggregateCreate, model.typeOf(node), node.span, node.text, fields);
            case NodeKind.arrayInitializer:
                IrOperand[] elements;
                foreach (child; node.children) elements ~= IrOperand(lowerExpression(child), "");
                return emit(IrOpcode.arrayCreate, model.typeOf(node), node.span, "", elements);
            case NodeKind.outArgument: return lowerAddress(node);
            default: return 0;
        }
    }

    ValueId lowerAddress(AstNode node) {
        auto symbol = node.id in model.nodeSymbols;
        if (symbol !is null && *symbol in locals) return locals[*symbol];
        return lowerExpression(node);
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
