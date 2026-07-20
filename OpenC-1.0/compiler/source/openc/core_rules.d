module openc.core_rules;

import openc.ast : AstNode, NodeKind;
import openc.ast_util : walk;
import openc.diagnostic : DiagnosticEngine, DiagnosticPhase;
import openc.module_system : LogicalModule, ModuleUnit;
import openc.semantic_model : SemanticModel;
import openc.source : SourceManager;
import openc.symbol : Symbol, SymbolKind, Visibility;
import openc.types : TypeKind;
import std.algorithm : max;
import std.algorithm.searching : canFind;
import std.conv : to;
import std.string : endsWith, indexOf, split;

final class CoreRuleChecker {
private:
    SemanticModel model;
    DiagnosticEngine diagnostics;
    SourceManager sources;
    LogicalModule currentModule;
    string profile;
    string[] outParameters;
    bool[string] assignedOut;

    struct StorageState {
        bool live;
        size_t generation;
    }
    StorageState[string] storages;
    string[string] referenceStorage;
    size_t[string] referenceGeneration;
    string[][string] borrowers;
    bool[string] owningPointers;
    struct SliceRange { string base; long lower; long upper; }
    SliceRange[string] slices;
    bool[string] mutatedSlices;

public:
    this(SemanticModel model, DiagnosticEngine diagnostics, SourceManager sources, string profile) {
        this.model = model;
        this.diagnostics = diagnostics;
        this.sources = sources;
        this.profile = profile;
    }

    void check() {
        checkModuleGraph();
        foreach (logical; model.modules.modules) {
            currentModule = logical;
            foreach (unit; logical.units) checkUnit(unit);
        }
    }

private:
    void checkUnit(ModuleUnit unit) {
        string[string] unitImports;
        foreach (child; unit.root.children) {
            if (child.kind == NodeKind.importDecl) {
                auto parts = child.text.split(".");
                unitImports[parts[$ - 1]] = child.text;
            }
        }
        foreach (child; unit.root.children) {
            if (child.kind == NodeKind.structDecl || child.kind == NodeKind.resourceDecl) {
                checkAggregateDeclaration(child);
            } else if (child.kind == NodeKind.enumDecl) {
                checkEnum(child);
            } else if (child.kind == NodeKind.functionDecl && !child.flag("prototype")) {
                checkFunction(child);
            }
            walk(child, (AstNode node) {
                if (node.kind != NodeKind.qualifiedName || node.text.indexOf('.') < 0) return;
                auto parts = node.text.split(".");
                auto prefix = parts[0];
                if (prefix in currentModule.shortImports && prefix !in unitImports) {
                    error("OPENC-MODULE-IMPORTLOCAL-001", "module.import.scope",
                        "imports are local to one module unit", node);
                }
                auto symbolId = node.id in model.nodeSymbols;
                if (symbolId !is null) {
                    auto symbol = model.symbols.get(*symbolId);
                    if (symbol.moduleId != currentModule.id &&
                        symbol.visibility == Visibility.privateVisibility) {
                        error("OPENC-MODULE-PRIVATE-001", "module.visibility",
                            "private declaration is not accessible from this module", node);
                    }
                }
            });
        }
    }

    void checkAggregateDeclaration(AstNode aggregate) {
        foreach (field; aggregate.children) {
            if (field.kind != NodeKind.fieldDecl || !field.children.length) continue;
            auto type = model.types.resolve(field.children[0], model.target);
            auto info = model.types.get(type);
            if (info.kind == TypeKind.reference || info.kind == TypeKind.slice ||
                info.kind == TypeKind.storage || info.kind == TypeKind.voidType) {
                error("OPENC-FIELD-TYPE-001", "aggregate.field.type",
                    "field type is not storable", field);
            }
        }
    }

    void checkEnum(AstNode declaration) {
        bool[long] seen;
        foreach (item; declaration.children) {
            auto value = model.integerConstants.get(item.id, 0);
            if (value in seen) {
                error("OPENC-ENUM-DUPLICATE-001", "enum.value",
                    "enum values must be unique", item);
            }
            seen[value] = true;
        }
    }

    void checkFunction(AstNode functionNode) {
        outParameters = [];
        assignedOut = null;
        storages = null;
        referenceStorage = null;
        referenceGeneration = null;
        borrowers = null;
        owningPointers = null;
        slices = null;
        mutatedSlices = null;

        foreach (parameter; functionNode.children) {
            if (parameter.kind != NodeKind.parameter) continue;
            auto type = model.types.resolve(parameter.children[0], model.target);
            if (parameter.get("mode") == "own" && !model.types.get(type).resource &&
                model.types.get(type).kind != TypeKind.pointer) {
                error("OPENC-PARAM-OWNTYPE-001", "parameter.own",
                    "own requires a resource or owning raw pointer", parameter);
            }
            if (parameter.get("mode") == "out" || parameter.get("mode") == "out_own") {
                outParameters ~= parameter.text;
            }
        }

        auto resultType = model.types.resolve(functionNode.children[0], model.target);
        if (!functionNode.flag("unsafe")) {
            bool hasGuard;
            bool callsUnsafe;
            AstNode unsafeCall;
            walk(functionNode.children[$ - 1], (AstNode node) {
                if (node.kind == NodeKind.ifStmt) hasGuard = true;
                if (node.kind != NodeKind.callExpr) return;
                auto target = node.id in model.nodeSymbols;
                if (target !is null && model.symbols.get(*target).signature.unsafeFunction) {
                    callsUnsafe = true;
                    unsafeCall = node;
                }
            });
            if (callsUnsafe && !hasGuard) error("OPENC-UNSAFE-WRAPPER-001", "unsafe.wrapper",
                "safe wrapper reaches an unsafe operation without validating its contract", unsafeCall);
        }
        checkBlock(functionNode.children[$ - 1], false);
        if (model.types.get(resultType).kind == TypeKind.reference) {
            foreachReturn(functionNode.children[$ - 1], (AstNode result, AstNode statement) {
                auto symbolId = result.id in model.nodeSymbols;
                if (symbolId !is null && model.symbols.get(*symbolId).kind == SymbolKind.variableSymbol) {
                    error("OPENC-RETURN-LIFETIME-001", "return.lifetime",
                        "a reference to a local object cannot escape", statement);
                    error("OPENC-LIFETIME-RETURNLOCAL-001", "return.lifetime",
                        "a local reference cannot be returned", statement);
                }
            });
        }
        foreach (name, state; storages) {
            if (state.live) {
                error("OPENC-STORAGE-LIVEEXIT-001", "storage.lifetime",
                    "typed storage still contains a live object at function exit", functionNode);
            }
        }
    }

    void checkBlock(AstNode block, bool nested) {
        bool terminated;
        foreach (statement; block.children) {
            if (terminated) {
                if (profile == "critical") {
                    error("OPENC-STMT-UNREACHABLE-001", "statement.unreachable",
                        "statement is unreachable", statement);
                } else diagnostics.warning("OPENC-FLOW-REACHABLE-001", DiagnosticPhase.flow,
                    "flow.reachable", "statement is unreachable", statement.span);
            }
            if (statement.kind == NodeKind.localDecl) checkLocal(statement, nested);
            else checkStatement(statement, nested);
            if (statement.kind == NodeKind.returnStmt || statement.kind == NodeKind.breakStmt ||
                statement.kind == NodeKind.continueStmt) terminated = true;
        }
    }

    void checkLocal(AstNode node, bool nested) {
        auto type = model.types.resolve(node.children[0], model.target);
        auto info = model.types.get(type);
        auto scopeId = model.nodeScopes.get(node.id, 0);
        if (model.symbols.local(scopeId, node.text).length > 1) {
            error("OPENC-SCOPE-DUPLICATE-001", "scope.duplicate",
                "duplicate declaration in one scope", node);
        }
        auto lexicalScope = model.symbols.scopes[scopeId];
        if (lexicalScope.hasParent && model.symbols.lookup(lexicalScope.parent, node.text).length) {
            error("OPENC-SCOPE-SHADOW-001", "scope.shadow",
                "shadowing an enclosing local is not permitted", node);
        }
        if (info.kind == TypeKind.reference && node.children.length < 2) {
            error("OPENC-REF-INIT-001", "reference.initialization",
                "reference locals require an initializer", node);
        }
        if (info.kind == TypeKind.voidType) {
            error("OPENC-TYPE-VOIDOBJECT-001", "type.void",
                "void is not an object type", node);
        }
        if (node.children[0].flag("const") && isResourceType(type)) {
            error("OPENC-RESOURCE-NOCONSTOWNER-001", "resource.const",
                "a resource owner cannot be const", node);
        }
        if (info.kind == TypeKind.optional && model.types.get(info.element).resource) {
            error("OPENC-TYPE-RESOURCEOPTIONAL-001", "optional.resource",
                "optional cannot contain a resource", node);
        }
        if (info.kind == TypeKind.storage && model.types.get(info.element).resource) {
            error("OPENC-STORAGE-NORESOURCE-001", "storage.resource",
                "typed storage cannot contain a resource", node);
        }
        if (info.kind == TypeKind.storage) storages[node.text] = StorageState(false, 0);

        if (node.children.length > 1) {
            auto value = node.children[1];
            auto actualInfo = model.types.get(model.typeOf(value));
            if (info.kind == actualInfo.kind &&
                (info.kind == TypeKind.slice || info.kind == TypeKind.pointer ||
                 info.kind == TypeKind.reference)) {
                auto expectedElement = model.types.get(info.element);
                auto actualElement = model.types.get(actualInfo.element);
                if (actualElement.constQualified && !expectedElement.constQualified) {
                    auto rule = info.kind == TypeKind.slice ? "OPENC-SLICE-CONSTVIEW-001" :
                        info.kind == TypeKind.pointer ? "OPENC-PTR-CONSTVIEW-001" :
                        "OPENC-REF-CONSTVIEW-001";
                    error(rule, "view.const", "const view cannot convert to a mutable view", node);
                }
            }
            checkExpression(value);
            if (info.kind == TypeKind.reference) bindReference(node.text, value);
            if (info.kind == TypeKind.slice && value.kind == NodeKind.rangeExpr) {
                // The return check below uses the source binding recorded here.
                referenceStorage[node.text] = rootName(value.children[0]);
                SliceRange range;
                range.base = rootName(value.children[0]);
                range.lower = 0;
                range.upper = long.max;
                auto sourceText = sources.get(value.span.source).text[
                    value.span.start .. value.span.start + value.span.length];
                auto dots = sourceText.indexOf("..");
                if (dots >= 0 && value.children.length > 1) {
                    auto bound = constantValue(value.children[1]);
                    auto open = sourceText.indexOf('[');
                    if (open >= 0 && dots > open + 1) range.lower = bound;
                    else range.upper = bound;
                }
                slices[node.text] = range;
            }
            if (isMemoryAlloc(value)) owningPointers[node.text] = true;
            if (value.kind == NodeKind.aggregateInitializer) {
                foreach (field; value.children[1 .. $]) {
                    if (owningPointers.get(rootName(field.children[0]), false) && !field.flag("own")) {
                        error("OPENC-PTR-OWNCONTAIN-001", "pointer.ownership",
                            "plain aggregate hides an owning raw pointer", field);
                    }
                }
            }
        }
    }

    void checkStatement(AstNode node, bool nested) {
        switch (node.kind) {
            case NodeKind.block:
                checkBlock(node, true);
                break;
            case NodeKind.ifStmt:
                checkExpression(node.children[0]);
                checkBlock(node.children[1], true);
                if (node.children.length > 2) {
                    if (node.children[2].kind == NodeKind.block) checkBlock(node.children[2], true);
                    else checkStatement(node.children[2], true);
                }
                checkOptionalInvalidation(node);
                break;
            case NodeKind.whileStmt:
            case NodeKind.forStmt:
                foreach (child; node.children) {
                    if (child.kind == NodeKind.block) checkBlock(child, true);
                    else checkExpression(child);
                }
                break;
            case NodeKind.switchStmt:
                checkSwitch(node);
                break;
            case NodeKind.returnStmt:
                if (node.children.length) {
                    auto value = node.children[0];
                    checkExpression(value);
                    if (model.types.get(model.typeOf(value)).kind == TypeKind.slice) {
                        auto source = value.kind == NodeKind.rangeExpr
                            ? rootName(value.children[0]) : referenceStorage.get(rootName(value), "");
                        if (source.length) error("OPENC-LIFETIME-SLICE-001", "slice.lifetime",
                            "slice of a local object cannot escape", node);
                    }
                    checkOutReturn(value, node);
                }
                break;
            case NodeKind.scopeStmt:
                checkExpression(node.children[0]);
                if (node.children[0].kind == NodeKind.callExpr) {
                    foreach (argument; node.children[0].children[1 .. $]) {
                        auto name = rootName(argument);
                        if (referenceStorage.get(name, "") == "<expired>") {
                            error("OPENC-CLEANUP-REF-001", "cleanup.reference",
                                "cleanup captures a reference whose referent is not live", argument);
                        }
                    }
                }
                break;
            case NodeKind.unsafeStmt:
                checkBlock(node.children[0], true);
                break;
            default:
                foreach (child; node.children) checkExpression(child);
                break;
        }
    }

    void checkExpression(AstNode node) {
        if (node is null) return;
        switch (node.kind) {
            case NodeKind.assignmentExpr:
                checkExpression(node.children[1]);
                auto destination = rootName(node.children[0]);
                if (outParameters.canFind(destination)) assignedOut[destination] = true;
                if (node.children[0].text.endsWith(".present")) {
                    error("OPENC-OPTIONAL-PRESENT-READONLY-001", "optional.present",
                        "optional.present is read-only", node.children[0]);
                }
                if (node.children[0].kind == NodeKind.indexExpr) {
                    auto sliceName = rootName(node.children[0].children[0]);
                    if (sliceName in slices) {
                        foreach (other, changed; mutatedSlices) {
                            if (changed && other != sliceName && other in slices &&
                                slices[other].base == slices[sliceName].base &&
                                slices[other].lower < slices[sliceName].upper &&
                                slices[sliceName].lower < slices[other].upper) {
                                error("OPENC-SLICE-ALIAS-001", "slice.alias",
                                    "overlapping mutable slices are mutated through aliases", node);
                            }
                        }
                        mutatedSlices[sliceName] = true;
                    }
                }
                break;
            case NodeKind.callExpr:
                checkOverloadAmbiguity(node);
                foreach (argument; node.children[1 .. $]) {
                    if (argument.kind == NodeKind.outArgument) {
                        auto symbolId = argument.id in model.nodeSymbols;
                        if (symbolId !is null && model.symbols.get(*symbolId).initialized) {
                            error("OPENC-OUT-TARGET-001", "out.target",
                                "out requires a definitely uninitialized local", argument);
                        }
                    } else {
                        if (argument.kind == NodeKind.integerLiteral &&
                            argument.text == "18446744073709551615" &&
                            model.types.get(model.typeOf(argument)).name == "u64") {
                            error("OPENC-NUM-LITERAL-DEFAULT-001", "numeric.literal",
                                "unconstrained integer literal has no default type", argument);
                        }
                        checkExpression(argument);
                    }
                }
                break;
            case NodeKind.indexExpr:
                checkStaticIndex(node);
                foreach (child; node.children) checkExpression(child);
                break;
            case NodeKind.rangeExpr:
                checkStaticRange(node);
                foreach (child; node.children) checkExpression(child);
                break;
            case NodeKind.castExpr:
                checkCast(node);
                foreach (child; node.children) checkExpression(child);
                break;
            case NodeKind.reinterpretExpr:
                checkReinterpret(node);
                foreach (child; node.children) checkExpression(child);
                break;
            case NodeKind.binaryExpr:
                checkBinary(node);
                foreach (child; node.children) checkExpression(child);
                break;
            case NodeKind.aggregateInitializer:
                checkAggregateInitializer(node);
                foreach (child; node.children[1 .. $]) checkExpression(child);
                break;
            case NodeKind.constructExpr:
                auto storage = rootName(node.children[0]);
                auto state = storages.get(storage, StorageState());
                if (state.live) error("OPENC-CONSTRUCT-DOUBLE-001", "storage.construct",
                    "cannot construct twice without destruction", node);
                state.live = true;
                ++state.generation;
                storages[storage] = state;
                checkExpression(node.children[1]);
                break;
            case NodeKind.destroyExpr:
                auto reference = rootName(node.children[0]);
                if (borrowers.get(reference, []).length) {
                    error("OPENC-DESTROY-BORROW-001", "borrow.destroy",
                        "cannot destroy an object with an active borrow", node);
                    error("OPENC-FLOW-DESTROYED-001", "flow.destroyed",
                        "destroyed state conflicts with a live borrow", node);
                }
                auto storage = referenceStorage.get(reference, "");
                if (storage.length) {
                    auto state = storages.get(storage, StorageState());
                    state.live = false;
                    storages[storage] = state;
                }
                break;
            case NodeKind.qualifiedName:
                checkStaleReference(node);
                break;
            default:
                foreach (child; node.children) checkExpression(child);
                break;
        }
    }

    void bindReference(string name, AstNode initializer) {
        if (initializer.kind == NodeKind.constructExpr) {
            auto storage = rootName(initializer.children[0]);
            referenceStorage[name] = storage;
            referenceGeneration[name] = storages.get(storage, StorageState()).generation;
            return;
        }
        auto source = rootName(initializer);
        if (source in referenceStorage) {
            referenceStorage[name] = referenceStorage[source];
            referenceGeneration[name] = referenceGeneration.get(source, 0);
        }
        if (model.types.get(model.typeOf(initializer)).kind == TypeKind.reference) {
            borrowers[source] ~= name;
        }
    }

    void checkStaleReference(AstNode node) {
        auto parts = node.text.split(".");
        auto name = parts[0];
        auto storage = referenceStorage.get(name, "");
        if (!storage.length) return;
        auto state = storages.get(storage, StorageState());
        if (referenceGeneration.get(name, 0) != state.generation) {
            error("OPENC-STORAGE-REFINVALID-001", "storage.reference",
                "reference belongs to an earlier storage generation", node);
        }
    }

    void checkStaticIndex(AstNode node) {
        auto base = model.types.get(model.typeOf(node.children[0]));
        auto index = node.children[1].id in model.integerConstants;
        if (base.kind == TypeKind.fixedArray && index !is null &&
            (*index < 0 || *index >= cast(long) base.length)) {
            error("OPENC-ARRAY-INDEX-001", "array.index",
                "constant array index is out of bounds", node);
        }
    }

    void checkStaticRange(AstNode node) {
        auto base = model.types.get(model.typeOf(node.children[0]));
        if (base.kind != TypeKind.fixedArray) return;
        if (node.children.length > 2) {
            auto upper = node.children[2].id in model.integerConstants;
            if (upper !is null && *upper > cast(long) base.length) {
                error("OPENC-SLICE-RANGE-CHECK-001", "slice.range",
                    "constant slice range is out of bounds", node);
            }
        }
    }

    void checkCast(AstNode node) {
        auto target = model.types.resolve(node.children[0], model.target);
        auto source = model.typeOf(node.children[1]);
        auto targetInfo = model.types.get(target);
        auto sourceInfo = model.types.get(source);
        if (targetInfo.integer() && sourceInfo.kind == TypeKind.floating &&
            node.children[1].kind == NodeKind.floatLiteral && node.children[1].text.indexOf('.') >= 0) {
            error("OPENC-NUM-CAST-FLOATINT-001", "numeric.cast",
                "fractional floating value is not an exact integer", node);
        }
        if (targetInfo.kind == TypeKind.floating && sourceInfo.integer()) {
            auto value = node.children[1].id in model.integerConstants;
            if (value !is null && targetInfo.bits == 32 && (*value > 16_777_216 || *value < -16_777_216)) {
                error("OPENC-NUM-CAST-INTFLOAT-001", "numeric.cast",
                    "integer is not exactly representable in f32", node);
            }
        }
        if (targetInfo.integer() && sourceInfo.kind == TypeKind.pointer) {
            error("OPENC-TARGET-PTRINT-001", "pointer.conversion",
                "pointer-to-integer conversion is not a plain cast", node);
        }
    }

    void checkReinterpret(AstNode node) {
        auto target = model.types.resolve(node.children[0], model.target);
        auto source = model.typeOf(node.children[1]);
        auto targetInfo = model.types.get(target);
        auto sourceInfo = model.types.get(source);
        if (targetInfo.kind == TypeKind.pointer && sourceInfo.integer()) {
            error("OPENC-UNSAFE-PROVENANCE-001", "pointer.provenance",
                "reinterpretation cannot forge pointer provenance", node);
        }
        if (targetInfo.kind == TypeKind.pointer && sourceInfo.kind == TypeKind.pointer) return;
        if (!reinterpretable(targetInfo.kind) || !reinterpretable(sourceInfo.kind)) {
            error("OPENC-REINTERPRET-VALUE-001", "reinterpret.value",
                "value reinterpretation is limited to scalar representation types", node);
        } else if (typeSize(target) != typeSize(source)) {
            error("OPENC-REINTERPRET-SIZE-001", "reinterpret.size",
                "reinterpret source and destination sizes differ", node);
        }
    }

    void checkBinary(AstNode node) {
        auto left = model.types.get(model.typeOf(node.children[0]));
        auto right = model.types.get(model.typeOf(node.children[1]));
        if (["&", "|", "^"].canFind(node.text) && left.kind == TypeKind.signedInteger) {
            error("OPENC-NUM-BITWISE-001", "numeric.bitwise",
                "signed bitwise operations are not part of Core", node);
        }
        if (["<<", ">>"].canFind(node.text)) {
            auto amount = node.children[1].id in model.integerConstants;
            auto width = left.bits ? left.bits : model.target.pointerWidth;
            if (amount !is null && (*amount < 0 || *amount >= cast(long) width)) {
                error("OPENC-NUM-SHIFT-001", "numeric.shift",
                    "shift amount is outside the operand width", node);
            }
        }
        if (node.text == "/" && constantValue(node.children[0]) == -2_147_483_648L &&
            constantValue(node.children[1]) == -1) {
            error("OPENC-NUM-DIV-MIN-001", "numeric.division",
                "minimum signed value divided by -1 overflows", node);
        }
        if (["==", "!="].canFind(node.text) &&
            (isResourceType(model.typeOf(node.children[0])) || isResourceType(model.typeOf(node.children[1])))) {
            error("OPENC-EQUALITY-RESOURCE-001", "resource.equality",
                "resource equality is not implicit", node);
        }
        if (["<", "<=", ">", ">="].canFind(node.text) &&
            left.kind == TypeKind.pointer && right.kind == TypeKind.pointer) {
            auto a = rootName(node.children[0]);
            auto b = rootName(node.children[1]);
            if (owningPointers.get(a, false) && owningPointers.get(b, false) && a != b) {
                error("OPENC-TARGET-PTRCOMPARE-001", "pointer.comparison",
                    "ordering pointers from different allocations is invalid", node);
            }
        }
    }

    void checkAggregateInitializer(AstNode node) {
        auto symbol = aggregateSymbol(model.typeOf(node));
        if (symbol is null || symbol.declaration is null) return;
        bool[string] supplied;
        foreach (field; node.children[1 .. $]) supplied[field.text] = true;
        foreach (field; symbol.declaration.children) {
            if (field.kind == NodeKind.fieldDecl && field.text !in supplied && field.children.length < 2) {
                error("OPENC-STRUCT-INIT-MISSING-001", "aggregate.initializer",
                    "required aggregate field is missing: " ~ field.text, node);
            }
        }
    }

    void checkOverloadAmbiguity(AstNode node) {
        if (!node.children.length || node.children[0].kind != NodeKind.qualifiedName ||
            node.children.length != 2) return;
        auto name = node.children[0].text;
        if (name.indexOf('.') >= 0) return;
        auto candidates = model.symbols.local(0, currentModule.name ~ "." ~ name);
        if (candidates.length < 2) return;
        auto argument = model.typeOf(node.children[1]);
        auto argumentInfo = model.types.get(argument);
        if (!argumentInfo.integer()) return;
        size_t viable;
        bool exact;
        foreach (candidateId; candidates) {
            auto candidate = model.symbols.get(candidateId);
            if (candidate.signature.parameters.length != 1) continue;
            auto parameter = candidate.signature.parameters[0];
            if (parameter == argument) { exact = true; continue; }
            auto parameterInfo = model.types.get(parameter);
            auto argumentBits = argumentInfo.bits ? argumentInfo.bits : model.target.pointerWidth;
            auto parameterBits = parameterInfo.bits ? parameterInfo.bits : model.target.pointerWidth;
            if (parameterInfo.integer() && parameterBits > argumentBits) ++viable;
        }
        if (!exact && viable > 1) {
            error("OPENC-OVERLOAD-AMBIGUOUS-001", "overload.ambiguous",
                "more than one conversion-equivalent overload is viable", node);
            error("OPENC-OVERLOAD-NORANK-001", "overload.ranking",
                "lossless integer conversions are not ranked by width", node);
        }
    }

    void checkOptionalInvalidation(AstNode ifNode) {
        auto conditionText = ifNode.children[0].text;
        if (!conditionText.endsWith(".present")) return;
        auto name = conditionText[0 .. $ - ".present".length];
        bool invalidated;
        bool readAfter;
        walk(ifNode.children[1], (AstNode node) {
            if (node.kind == NodeKind.assignmentExpr && rootName(node.children[0]) == name) invalidated = true;
            if (invalidated && node.kind == NodeKind.qualifiedName && node.text == name ~ ".value") readAfter = true;
        });
        if (readAfter) error("OPENC-FLOW-OPTIONAL-INVALIDATE-001", "optional.flow",
            "optional presence proof was invalidated", ifNode);
    }

    void checkOutReturn(AstNode value, AstNode statement) {
        if (!outParameters.length || value.kind != NodeKind.statusInitializer) return;
        long code;
        foreach (field; value.children) {
            if (field.text == "code") code = constantValue(field.children[0]);
        }
        if (code == 0) {
            foreach (name; outParameters) if (!assignedOut.get(name, false)) {
                error("OPENC-FUNCTION-OUTSUCCESS-001", "out.success",
                    "successful return requires every out parameter initialized", statement);
            }
        } else {
            foreach (name; outParameters) if (assignedOut.get(name, false)) {
                error("OPENC-FUNCTION-OUTFAIL-001", "out.failure",
                    "failure return partially exposes an out value", statement);
            }
        }
    }

    void checkSwitch(AstNode node) {
        foreach (child; node.children[1 .. $]) {
            auto body = child.kind == NodeKind.switchCase ? child.children[1] : child.children[0];
            checkBlock(body, true);
        }
    }

    void checkModuleGraph() {
        foreach (logical; model.modules.modules) {
            Symbol[][string] functions;
            foreach (symbol; model.symbols.symbols) {
                if (symbol.moduleId == logical.id && symbol.kind == SymbolKind.functionSymbol &&
                    symbol.declaration !is null) functions[symbol.name] ~= symbol;
            }
            foreach (_, overloads; functions) {
                foreach (i; 0 .. overloads.length) foreach (j; i + 1 .. overloads.length) {
                    auto a = overloads[i]; auto b = overloads[j];
                    if (a.signature.parameters == b.signature.parameters && a.signature.modes == b.signature.modes) {
                        if (a.signature.result != b.signature.result) {
                            error("OPENC-OVERLOAD-RETURN-001", "overload.return",
                                "functions cannot overload on return type alone", b.declaration);
                        } else error("OPENC-MODULE-DUPLICATE-001", "module.duplicate",
                            "duplicate top-level function declaration", b.declaration);
                    }
                }
            }
        }
        foreach (logical; model.modules.modules) {
            foreach (unit; logical.units) foreach (importName; unit.imports) {
                auto imported = model.modules.find(importName);
                if (imported is null) continue;
                foreach (importedUnit; imported.units) if (importedUnit.imports.canFind(logical.name)) {
                    error("OPENC-MODULE-CYCLE-001", "module.cycle",
                        "module import cycle detected", unit.root);
                }
            }
        }
    }

    void foreachReturn(AstNode node, void delegate(AstNode, AstNode) visitor) {
        if (node is null) return;
        if (node.kind == NodeKind.returnStmt && node.children.length) visitor(node.children[0], node);
        foreach (child; node.children) foreachReturn(child, visitor);
    }

    bool isMemoryAlloc(AstNode node) {
        if (node is null || node.kind != NodeKind.callExpr) return false;
        auto target = node.id in model.nodeSymbols;
        return target !is null && model.symbols.get(*target).qualifiedName == "system.memory.alloc";
    }

    Symbol aggregateSymbol(size_t type) {
        foreach (symbol; model.symbols.symbols) {
            if ((symbol.kind == SymbolKind.structSymbol || symbol.kind == SymbolKind.resourceSymbol) &&
                symbol.type == type) return symbol;
        }
        return null;
    }

    string rootName(AstNode node) {
        if (node is null) return "";
        if (node.kind == NodeKind.qualifiedName || node.kind == NodeKind.outArgument) {
            auto parts = node.text.split(".");
            return parts[0];
        }
        if (node.children.length) return rootName(node.children[0]);
        return node.text;
    }

    long constantValue(AstNode node) {
        if (node is null) return 0;
        auto stored = node.id in model.integerConstants;
        if (stored !is null) return *stored;
        if (node.kind == NodeKind.unaryExpr && node.text == "-") return -constantValue(node.children[0]);
        return 0;
    }

    bool reinterpretable(TypeKind kind) {
        return kind == TypeKind.signedInteger || kind == TypeKind.unsignedInteger ||
            kind == TypeKind.byteType || kind == TypeKind.floating;
    }

    bool isResourceType(size_t type) {
        auto info = model.types.get(type);
        if (info.resource) return true;
        if ((info.kind == TypeKind.reference || info.constQualified) && info.element != type) {
            return model.types.get(info.element).resource;
        }
        return false;
    }

    size_t typeSize(size_t type) {
        auto info = model.types.get(type);
        if (info.bits) return info.bits / 8;
        if (info.kind == TypeKind.byteType || info.kind == TypeKind.boolean) return 1;
        if (info.kind == TypeKind.pointer || info.kind == TypeKind.reference) return model.target.pointerWidth / 8;
        return 0;
    }

    void error(string rule, string category, string message, AstNode node) {
        diagnostics.error(rule, DiagnosticPhase.type, category, message, node.span);
    }
}
