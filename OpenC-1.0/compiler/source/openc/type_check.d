module openc.type_check;

import openc.ast : AstNode, NodeKind;
import openc.common : ScopeId, SymbolId, TypeId;
import openc.constant : ConstantEvaluator;
import openc.diagnostic : Diagnostic, DiagnosticEngine, DiagnosticPhase, DiagnosticSeverity, RelatedLocation;
import openc.overload : OverloadResolver;
import openc.semantic_model : SemanticModel, ValueCategory;
import openc.symbol : Symbol, SymbolKind;
import openc.types : OpenCTypeInfo, TypeKind;
import std.algorithm.searching : canFind;
import std.conv : to;

final class TypeChecker {
private:
    SemanticModel model;
    DiagnosticEngine diagnostics;
    ConstantEvaluator constants;
    OverloadResolver overloads;
    TypeId currentReturn;
    string currentFunction;
    bool currentUnsafe;

public:
    this(SemanticModel model, DiagnosticEngine diagnostics) {
        this.model = model;
        this.diagnostics = diagnostics;
        constants = new ConstantEvaluator(model, diagnostics);
        overloads = new OverloadResolver(model);
    }

    void check() {
        foreach (logical; model.modules.modules) {
            foreach (unit; logical.units) {
                foreach (node; unit.root.children) {
                    if (node.kind == NodeKind.functionDecl) checkFunction(node);
                    else if (node.kind == NodeKind.moduleConstDecl) checkModuleConstant(node);
                    else if (node.kind == NodeKind.structDecl || node.kind == NodeKind.resourceDecl) checkAggregate(node);
                    else if (node.kind == NodeKind.enumDecl) checkEnum(node);
                    else if (node.kind == NodeKind.whenDecl) checkWhen(node);
                }
            }
        }
    }

private:
    void checkFunction(AstNode node) {
        auto symbolId = node.id in model.nodeSymbols;
        if (symbolId is null) return;
        auto symbol = model.symbols.get(*symbolId);
        currentReturn = symbol.signature.result;
        currentFunction = symbol.qualifiedName;
        currentUnsafe = symbol.signature.unsafeFunction;
        auto body = node.children[$ - 1];
        checkBlock(body);
        if (currentReturn != model.types.voidType && !definitelyReturns(body)) {
            diagnostics.error("OPENC-FUNCTION-RETURN-001", DiagnosticPhase.flow,
                "function.return", "not every completed path returns a value", node.span);
        }
    }

    void checkModuleConstant(AstNode node) {
        auto expected = model.types.resolve(node.children[0], model.target);
        auto value = constants.evaluate(node.children[1]);
        if (value.valid && !model.types.lossless(value.type, expected, model.target)) {
            mismatch(node.children[1], value.type, expected, "module constant initializer");
        }
        model.setType(node, expected);
    }

    void checkAggregate(AstNode node) {
        foreach (field; node.children) {
            if (field.children.length <= 1) continue;
            auto expected = model.types.resolve(field.children[0], model.target);
            auto actual = checkExpression(field.children[1]);
            if (!model.types.lossless(actual, expected, model.target)) mismatch(field.children[1], actual, expected, "field default");
        }
    }

    void checkEnum(AstNode node) {
        long nextValue;
        foreach (item; node.children) {
            if (item.children.length) {
                auto value = constants.evaluate(item.children[0]);
                if (value.valid) nextValue = value.signedValue;
            }
            model.integerConstants[item.id] = nextValue++;
        }
    }

    void checkWhen(AstNode node) {
        auto condition = checkExpression(node.children[0]);
        requireBool(node.children[0], condition, "when condition");
        foreach (child; node.children[1 .. $]) {
            if (child.kind == NodeKind.functionDecl) checkFunction(child);
        }
    }

    void checkBlock(AstNode block) {
        foreach (item; block.children) {
            if (item is null) continue;
            if (item.kind == NodeKind.localDecl) checkLocal(item);
            else checkStatement(item);
        }
    }

    void checkLocal(AstNode node) {
        auto expected = model.types.resolve(node.children[0], model.target);
        model.setType(node, expected);
        if (node.children.length > 1 && node.children[1] !is null) {
            auto actual = checkExpression(node.children[1]);
            if (!model.types.lossless(actual, expected, model.target)) mismatch(node.children[1], actual, expected, "local initializer");
        }
    }

    void checkStatement(AstNode node) {
        switch (node.kind) {
            case NodeKind.block: checkBlock(node); break;
            case NodeKind.expressionStmt: checkExpression(node.children[0]); break;
            case NodeKind.ifStmt:
                requireBool(node.children[0], checkExpression(node.children[0]), "if condition");
                checkBlock(node.children[1]);
                if (node.children.length > 2) {
                    if (node.children[2].kind == NodeKind.ifStmt) checkStatement(node.children[2]);
                    else checkBlock(node.children[2]);
                }
                break;
            case NodeKind.whileStmt:
                requireBool(node.children[0], checkExpression(node.children[0]), "while condition");
                checkBlock(node.children[1]);
                break;
            case NodeKind.forStmt:
                foreach (index, child; node.children) {
                    if (child is null) continue;
                    if (child.kind == NodeKind.localDecl) checkLocal(child);
                    else if (child.kind == NodeKind.block) checkBlock(child);
                    else {
                        auto type = checkExpression(child);
                        if (index == 1) requireBool(child, type, "for condition");
                    }
                }
                break;
            case NodeKind.switchStmt:
                auto subject = checkExpression(node.children[0]);
                foreach (child; node.children[1 .. $]) {
                    if (child.kind == NodeKind.switchCase) {
                        auto caseType = checkExpression(child.children[0]);
                        if (!model.types.lossless(caseType, subject, model.target) && !model.types.lossless(subject, caseType, model.target)) {
                            mismatch(child.children[0], caseType, subject, "switch case");
                        }
                        checkBlock(child.children[1]);
                    } else checkBlock(child.children[0]);
                }
                break;
            case NodeKind.returnStmt:
                if (node.children.length == 0 || node.children[0] is null) {
                    if (currentReturn != model.types.voidType) diagnostics.error("OPENC-FUNCTION-RETURN-TYPE-001", DiagnosticPhase.type,
                        "function.return", "function must return " ~ model.types.get(currentReturn).display(model.types), node.span);
                } else {
                    auto actual = checkExpression(node.children[0]);
                    if (currentReturn == model.types.voidType) diagnostics.error("OPENC-FUNCTION-RETURN-VALUE-001", DiagnosticPhase.type,
                        "function.return", "void function cannot return a value", node.span);
                    else if (!model.types.lossless(actual, currentReturn, model.target)) mismatch(node.children[0], actual, currentReturn, "return value");
                }
                break;
            case NodeKind.scopeStmt:
                auto actionType = checkExpression(node.children[0]);
                if (actionType != model.types.voidType) diagnostics.error("OPENC-SCOPE-NOFAIL-001", DiagnosticPhase.type,
                    "scope.action", "scope action must be a no-fail void call or destroy operation", node.children[0].span);
                break;
            case NodeKind.unsafeStmt:
                auto previous = currentUnsafe; currentUnsafe = true; checkBlock(node.children[0]); currentUnsafe = previous; break;
            case NodeKind.whenStmt:
                requireBool(node.children[0], checkExpression(node.children[0]), "when condition"); checkBlock(node.children[1]); break;
            default: break;
        }
    }

    TypeId checkExpression(AstNode node) {
        if (node is null) return model.types.voidType;
        switch (node.kind) {
            case NodeKind.integerLiteral:
            case NodeKind.floatLiteral:
            case NodeKind.textLiteral:
            case NodeKind.boolLiteral:
                return constants.evaluate(node).type;
            case NodeKind.nullLiteral:
                model.setType(node, model.types.pointer(model.types.voidType, true)); return model.typeOf(node);
            case NodeKind.noneLiteral:
                model.setType(node, model.types.optional(model.types.errorType, false)); return model.typeOf(node);
            case NodeKind.qualifiedName: return checkName(node);
            case NodeKind.unaryExpr: return checkUnary(node);
            case NodeKind.binaryExpr: return checkBinary(node);
            case NodeKind.assignmentExpr: return checkAssignment(node);
            case NodeKind.callExpr: return checkCall(node);
            case NodeKind.memberExpr: return checkMember(node);
            case NodeKind.indexExpr: return checkIndex(node);
            case NodeKind.rangeExpr: return checkRange(node);
            case NodeKind.castExpr: return checkCast(node);
            case NodeKind.reinterpretExpr: return checkReinterpret(node);
            case NodeKind.constructExpr: return checkConstruct(node);
            case NodeKind.destroyExpr: return checkDestroy(node);
            case NodeKind.typeQueryExpr: return constants.evaluate(node).type;
            case NodeKind.statusInitializer: return checkStatusInitializer(node);
            case NodeKind.aggregateInitializer: return checkAggregateInitializer(node);
            case NodeKind.arrayInitializer: return checkArrayInitializer(node);
            case NodeKind.outArgument: return checkOutArgument(node);
            default:
                model.setType(node, model.types.errorType); return model.types.errorType;
        }
    }

    TypeId checkName(AstNode node) {
        auto found = node.id in model.nodeSymbols;
        if (found is null) return model.types.errorType;
        auto symbol = model.symbols.get(*found);
        model.setType(node, symbol.type);
        ValueCategory category;
        category.lvalue = symbol.kind == SymbolKind.variableSymbol || symbol.kind == SymbolKind.parameterSymbol || symbol.kind == SymbolKind.fieldSymbol;
        category.mutableValue = symbol.mutableValue;
        category.initialized = symbol.initialized;
        category.constantValue = symbol.kind == SymbolKind.constantSymbol || symbol.kind == SymbolKind.enumItemSymbol;
        model.categories[node.id] = category;
        return symbol.type;
    }

    TypeId checkUnary(AstNode node) {
        auto operand = checkExpression(node.children[0]);
        auto info = model.types.get(operand);
        if (node.text == "!") {
            requireBool(node.children[0], operand, "logical negation"); model.setType(node, model.types.boolType); return model.types.boolType;
        }
        if (node.text == "~" || node.text == "+" || node.text == "-") {
            if (!info.numeric()) diagnostics.error("OPENC-EXPR-TYPE-001", DiagnosticPhase.type,
                "expression.unary", "unary operator requires a numeric operand", node.span);
            model.setType(node, operand); return operand;
        }
        if (node.text == "&") {
            if (!currentUnsafe) diagnostics.error("OPENC-PTR-ADDRESS-UNSAFE-001", DiagnosticPhase.unsafePhase,
                "unsafe.address_of", "raw address-of requires an unsafe context", node.span);
            auto result = model.types.pointer(operand, false); model.setType(node, result); return result;
        }
        if (node.text == "*") {
            if (!currentUnsafe) diagnostics.error("OPENC-PTR-DEREF-UNSAFE-001", DiagnosticPhase.unsafePhase,
                "unsafe.dereference", "raw pointer dereference requires an unsafe context", node.span);
            if (info.kind != TypeKind.pointer) {
                diagnostics.error("OPENC-PTR-DEREF-TYPE-001", DiagnosticPhase.type,
                    "pointer.dereference", "dereference operand must be ptr T", node.span);
                return model.types.errorType;
            }
            model.setType(node, info.element);
            model.categories[node.id] = ValueCategory(true, !info.constQualified, true, false);
            return info.element;
        }
        return model.types.errorType;
    }

    TypeId checkBinary(AstNode node) {
        auto left = checkExpression(node.children[0]);
        auto right = checkExpression(node.children[1]);
        auto op = node.text;
        if (op == "&&" || op == "||") {
            requireBool(node.children[0], left, "logical operand"); requireBool(node.children[1], right, "logical operand");
            model.setType(node, model.types.boolType); return model.types.boolType;
        }
        if (["==", "!=", "<", "<=", ">", ">="].canFind(op)) {
            if (!compatible(left, right)) mismatch(node, right, left, "comparison");
            model.setType(node, model.types.boolType); return model.types.boolType;
        }
        auto l = model.types.get(left); auto r = model.types.get(right);
        if (l.kind == TypeKind.pointer || r.kind == TypeKind.pointer) {
            if (!currentUnsafe) diagnostics.error("OPENC-PTR-ARITH-UNSAFE-001", DiagnosticPhase.unsafePhase,
                "unsafe.pointer_arithmetic", "raw pointer arithmetic requires unsafe", node.span);
            if ((op == "+" || op == "-") && l.kind == TypeKind.pointer && r.integer()) {
                model.setType(node, left); return left;
            }
            diagnostics.error("OPENC-PTR-ARITH-TYPE-001", DiagnosticPhase.type,
                "pointer.arithmetic", "unsupported raw pointer operation", node.span);
            return model.types.errorType;
        }
        if (!l.numeric() || !r.numeric()) {
            diagnostics.error("OPENC-EXPR-TYPE-001", DiagnosticPhase.type,
                "expression.binary", "binary operator requires compatible numeric operands", node.span);
            return model.types.errorType;
        }
        if (!compatible(left, right)) mismatch(node, right, left, "binary expression");
        model.setType(node, left); return left;
    }

    TypeId checkAssignment(AstNode node) {
        auto left = checkExpression(node.children[0]);
        auto right = checkExpression(node.children[1]);
        auto category = model.categories.get(node.children[0].id, ValueCategory());
        if (!category.lvalue) diagnostics.error("OPENC-ASSIGN-LVALUE-001", DiagnosticPhase.type,
            "assignment.lvalue", "assignment destination is not assignable", node.children[0].span);
        if (!category.mutableValue) diagnostics.error("OPENC-CONST-ASSIGN-001", DiagnosticPhase.type,
            "assignment.const", "cannot assign through a const value", node.children[0].span);
        if (!model.types.lossless(right, left, model.target)) mismatch(node.children[1], right, left, "assignment");
        model.setType(node, left); return left;
    }

    TypeId checkCall(AstNode node) {
        auto callee = node.children[0];
        SymbolId[] candidates;
        if (callee.kind == NodeKind.qualifiedName) {
            auto resolved = callee.id in model.nodeSymbols;
            if (resolved !is null) {
                auto symbol = model.symbols.get(*resolved);
                candidates = model.symbols.lookup(symbol.scopeId, symbol.name);
                if (!candidates.length) candidates = [*resolved];
            }
        }
        TypeId[] argumentTypes;
        string[] modes;
        foreach (argument; node.children[1 .. $]) {
            if (argument.kind == NodeKind.outArgument) {
                modes ~= "out";
                argumentTypes ~= checkOutArgument(argument);
            } else {
                modes ~= "value";
                argumentTypes ~= checkExpression(argument);
            }
        }
        auto match = overloads.resolve(candidates, argumentTypes, modes);
        if (!match.found) {
            diagnostics.error("OPENC-CALL-NOMATCH-001", DiagnosticPhase.type,
                "call.overload", "no overload matches the argument types and modes", node.span);
            return model.types.errorType;
        }
        if (match.ambiguous) {
            diagnostics.error("OPENC-CALL-AMBIGUOUS-001", DiagnosticPhase.type,
                "call.overload", "call is ambiguous after lossless conversions", node.span);
            return model.types.errorType;
        }
        model.nodeSymbols[node.id] = match.symbol;
        auto result = model.symbols.get(match.symbol).signature.result;
        model.setType(node, result); return result;
    }

    TypeId checkMember(AstNode node) {
        auto baseType = checkExpression(node.children[0]);
        auto baseInfo = model.types.get(baseType);
        if (baseInfo.kind == TypeKind.reference || baseInfo.kind == TypeKind.pointer) baseInfo = model.types.get(baseInfo.element);
        if (baseInfo.kind == TypeKind.slice && node.text == "length") {
            auto result = model.types.find("usize"); model.setType(node, result); return result;
        }
        if (baseInfo.kind == TypeKind.text && node.text == "length") {
            auto result = model.types.find("usize"); model.setType(node, result); return result;
        }
        auto aggregate = findAggregateSymbol(baseInfo.name);
        if (aggregate is null) {
            diagnostics.error("OPENC-MEMBER-TYPE-001", DiagnosticPhase.type,
                "member.base", "type has no fields: " ~ baseInfo.display(model.types), node.span);
            return model.types.errorType;
        }
        auto scopeId = model.nodeScopes.get(aggregate.declaration.id, 0);
        auto fields = model.symbols.local(scopeId, node.text);
        if (!fields.length) {
            diagnostics.error("OPENC-STRUCT-FIELD-UNKNOWN-001", DiagnosticPhase.type,
                "member.unknown", "unknown field: " ~ node.text, node.span);
            return model.types.errorType;
        }
        model.nodeSymbols[node.id] = fields[0];
        auto result = model.symbols.get(fields[0]).type;
        model.setType(node, result);
        auto baseCategory = model.categories.get(node.children[0].id, ValueCategory());
        model.categories[node.id] = ValueCategory(true, baseCategory.mutableValue, baseCategory.initialized, false);
        return result;
    }

    TypeId checkIndex(AstNode node) {
        auto base = checkExpression(node.children[0]);
        auto index = checkExpression(node.children[1]);
        if (!model.types.get(index).integer()) diagnostics.error("OPENC-INDEX-TYPE-001", DiagnosticPhase.type,
            "index.type", "index must be an integer", node.children[1].span);
        auto info = model.types.get(base);
        if (info.kind != TypeKind.fixedArray && info.kind != TypeKind.slice) {
            diagnostics.error("OPENC-INDEX-BASE-001", DiagnosticPhase.type,
                "index.base", "only arrays and slices support safe indexing", node.children[0].span);
            return model.types.errorType;
        }
        model.setType(node, info.element);
        model.categories[node.id] = ValueCategory(true, !info.constQualified, true, false);
        return info.element;
    }

    TypeId checkRange(AstNode node) {
        auto base = checkExpression(node.children[0]);
        auto info = model.types.get(base);
        if (info.kind != TypeKind.fixedArray && info.kind != TypeKind.slice && info.kind != TypeKind.text) {
            diagnostics.error("OPENC-RANGE-BASE-001", DiagnosticPhase.type,
                "range.base", "range requires an array, slice, or text value", node.children[0].span);
            return model.types.errorType;
        }
        foreach (bound; node.children[1 .. $]) {
            if (bound is null) continue;
            auto type = checkExpression(bound);
            if (!model.types.get(type).integer()) diagnostics.error("OPENC-RANGE-TYPE-001", DiagnosticPhase.type,
                "range.bound", "range bound must be an integer", bound.span);
        }
        TypeId result;
        if (info.kind == TypeKind.text) result = model.types.textType;
        else result = model.types.slice(info.element, info.constQualified);
        model.setType(node, result); return result;
    }

    TypeId checkCast(AstNode node) {
        auto target = model.types.resolve(node.children[0], model.target);
        auto source = checkExpression(node.children[1]);
        if (node.flag("unsafe_operation") && !currentUnsafe) diagnostics.error("OPENC-CAST-UNCHECKED-UNSAFE-001", DiagnosticPhase.unsafePhase,
            "unsafe.cast", "unchecked cast requires unsafe", node.span);
        model.setType(node, target); return target;
    }

    TypeId checkReinterpret(AstNode node) {
        auto target = model.types.resolve(node.children[0], model.target);
        checkExpression(node.children[1]);
        if (!currentUnsafe) diagnostics.error("OPENC-REINTERPRET-UNSAFE-001", DiagnosticPhase.unsafePhase,
            "unsafe.reinterpret", "reinterpret requires unsafe", node.span);
        model.setType(node, target); return target;
    }

    TypeId checkConstruct(AstNode node) {
        auto target = model.types.find(node.text);
        auto storage = checkExpression(node.children[0]);
        auto storageInfo = model.types.get(storage);
        if (storageInfo.kind != TypeKind.storage || storageInfo.element != target) diagnostics.error("OPENC-STORAGE-CONSTRUCT-TYPE-001", DiagnosticPhase.type,
            "storage.construct", "construct target does not match storage object type", node.span);
        auto result = model.types.reference(target, false); model.setType(node, result); return result;
    }

    TypeId checkDestroy(AstNode node) {
        checkExpression(node.children[0]);
        model.setType(node, model.types.voidType); return model.types.voidType;
    }

    TypeId checkStatusInitializer(AstNode node) {
        bool codeSeen;
        bool messageSeen;
        foreach (field; node.children) {
            auto value = checkExpression(field.children[0]);
            if (field.text == "code") {
                codeSeen = true;
                if (!model.types.get(value).integer()) mismatch(field.children[0], value, model.types.find("i32"), "status code");
            } else if (field.text == "message") {
                messageSeen = true;
                if (value != model.types.textType) mismatch(field.children[0], value, model.types.textType, "status message");
            }
        }
        if (!codeSeen) diagnostics.error("OPENC-STATUS-CODE-001", DiagnosticPhase.type,
            "status.initializer", "status initializer requires code", node.span);
        model.setType(node, model.types.statusType); return model.types.statusType;
    }

    TypeId checkAggregateInitializer(AstNode node) {
        auto aggregateType = model.types.find(node.text);
        auto aggregate = findAggregateSymbol(node.text);
        if (aggregate is null) {
            diagnostics.error("OPENC-STRUCT-INIT-TYPE-001", DiagnosticPhase.type,
                "aggregate.initializer", "unknown aggregate type: " ~ node.text, node.span);
            return model.types.errorType;
        }
        auto scopeId = model.nodeScopes.get(aggregate.declaration.id, 0);
        bool[string] seen;
        foreach (field; node.children[1 .. $]) {
            if (field.text in seen) diagnostics.error("OPENC-STRUCT-INIT-DUPLICATE-001", DiagnosticPhase.type,
                "aggregate.initializer", "field initialized more than once: " ~ field.text, field.span);
            seen[field.text] = true;
            auto symbols = model.symbols.local(scopeId, field.text);
            if (!symbols.length) {
                diagnostics.error("OPENC-STRUCT-INIT-UNKNOWN-001", DiagnosticPhase.type,
                    "aggregate.initializer", "unknown aggregate field: " ~ field.text, field.span);
                continue;
            }
            auto fieldSymbol = model.symbols.get(symbols[0]);
            auto actual = checkExpression(field.children[0]);
            if (!model.types.lossless(actual, fieldSymbol.type, model.target)) mismatch(field.children[0], actual, fieldSymbol.type, "aggregate field");
            if (fieldSymbol.resource != field.flag("own")) diagnostics.error("OPENC-RESOURCE-INIT-OWNER-001", DiagnosticPhase.ownership,
                "aggregate.ownership", "ownership-bearing field requires an explicit own initializer", field.span);
        }
        model.setType(node, aggregateType); return aggregateType;
    }

    TypeId checkArrayInitializer(AstNode node) {
        TypeId element = model.types.errorType;
        foreach (child; node.children) {
            auto type = checkExpression(child);
            if (element == model.types.errorType) element = type;
            else if (!compatible(type, element)) mismatch(child, type, element, "array initializer element");
        }
        auto result = model.types.fixedArray(element, node.children.length);
        model.setType(node, result); return result;
    }

    TypeId checkOutArgument(AstNode node) {
        auto symbolIds = model.symbols.lookup(model.nodeScopes.get(node.id, 0), node.text);
        if (!symbolIds.length) return model.types.errorType;
        auto symbol = model.symbols.get(symbolIds[0]);
        model.nodeSymbols[node.id] = symbol.id;
        model.setType(node, symbol.type); return symbol.type;
    }

    bool compatible(TypeId a, TypeId b) const {
        return model.types.lossless(a, b, model.target) || model.types.lossless(b, a, model.target);
    }

    void requireBool(AstNode node, TypeId type, string context) {
        if (type != model.types.boolType) mismatch(node, type, model.types.boolType, context);
    }

    void mismatch(AstNode node, TypeId actual, TypeId expected, string context) {
        diagnostics.error("OPENC-TYPE-MISMATCH-001", DiagnosticPhase.type,
            "type.mismatch", context ~ " requires " ~ model.types.get(expected).display(model.types) ~
            " but found " ~ model.types.get(actual).display(model.types), node.span);
    }

    Symbol findAggregateSymbol(string name) {
        foreach (symbol; model.symbols.symbols) {
            if ((symbol.kind == SymbolKind.structSymbol || symbol.kind == SymbolKind.resourceSymbol) &&
                (symbol.name == name || symbol.qualifiedName == name)) return symbol;
        }
        return null;
    }

    bool definitelyReturns(AstNode node) const {
        if (node is null) return false;
        if (node.kind == NodeKind.returnStmt) return true;
        if (node.kind == NodeKind.block) {
            foreach (child; node.children) if (definitelyReturns(child)) return true;
            return false;
        }
        if (node.kind == NodeKind.ifStmt && node.children.length > 2) return definitelyReturns(node.children[1]) && definitelyReturns(node.children[2]);
        if (node.kind == NodeKind.switchStmt) {
            bool hasDefault;
            foreach (child; node.children[1 .. $]) if (child.kind == NodeKind.defaultCase) hasDefault = true;
            if (!hasDefault) return false;
            foreach (child; node.children[1 .. $]) {
                auto body = child.kind == NodeKind.switchCase ? child.children[1] : child.children[0];
                if (!definitelyReturns(body)) return false;
            }
            return true;
        }
        return false;
    }
}
