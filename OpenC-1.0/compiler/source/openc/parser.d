module openc.parser;

import openc.ast : AstArena, AstNode, NodeKind, ParsedUnit;
import openc.diagnostic : Diagnostic, DiagnosticEngine, DiagnosticPhase, DiagnosticSeverity;
import openc.source : SourceSpan;
import openc.token : Token, TokenKind;
import std.algorithm.searching : canFind;
import std.array : array;
import std.conv : to;

final class Parser {
private:
    Token[] tokens;
    DiagnosticEngine diagnostics;
    AstArena arena;
    size_t cursor;
    size_t functionDepth;
    size_t loopDepth;
    size_t unsafeDepth;
    bool allowAggregateInitializer = true;

public:
    this(Token[] tokens, DiagnosticEngine diagnostics, AstArena arena) {
        this.tokens = tokens;
        this.diagnostics = diagnostics;
        this.arena = arena;
    }

    ParsedUnit parse() {
        auto start = current().span;
        auto root = arena.make(NodeKind.sourceUnit, start);
        while (match("import")) {
            root.add(parseImport(previous()));
        }
        while (!atEnd()) {
            const before = cursor;
            auto declaration = parseTopDeclaration();
            if (declaration !is null) {
                root.add(declaration);
            } else {
                synchronizeTop();
            }
            ensureProgress(before, "top-level declaration");
        }
        root.span = combinedSpan(start, current().span);
        return ParsedUnit(root, !diagnostics.hasErrors());
    }

private:
    Token current() const { return tokens[cursor]; }
    Token previous() const { return cursor == 0 ? tokens[0] : tokens[cursor - 1]; }
    Token peek(size_t distance) const {
        const index = cursor + distance;
        return index < tokens.length ? tokens[index] : tokens[$ - 1];
    }
    bool atEnd() const { return current().kind == TokenKind.eofToken; }
    Token advance() { if (!atEnd()) ++cursor; return previous(); }
    bool check(string text) const { return current().text == text; }
    bool match(string text) {
        if (!check(text)) return false;
        advance();
        return true;
    }
    bool checkKind(TokenKind kind) const { return current().kind == kind; }
    SourceSpan combinedSpan(SourceSpan first, SourceSpan last) const {
        const finish = last.start + last.length;
        return SourceSpan(first.source, first.start, finish >= first.start ? finish - first.start : first.length);
    }

    Token expect(string text, string rule, string message) {
        if (match(text)) return previous();
        syntaxError(rule, message, current().span);
        return Token(TokenKind.symbol, text, current().span);
    }

    Token expectIdentifier(string rule = "OPENC-SYNTAX-IDENTIFIER-001", string message = "expected identifier") {
        if (checkKind(TokenKind.identifier)) return advance();
        syntaxError(rule, message, current().span);
        return Token(TokenKind.identifier, "<missing>", current().span);
    }

    void syntaxError(string rule, string message, SourceSpan span) {
        diagnostics.error(rule, DiagnosticPhase.syntax, "syntax", message, span);
    }

    AstNode parseImport(Token begin) {
        auto name = parseQualifiedName();
        auto end = expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' after import");
        return arena.make(NodeKind.importDecl, combinedSpan(begin.span, end.span), name.text).add(name);
    }

    AstNode parseTopDeclaration() {
        const start = current().span;
        bool exported = match("export");
        AstNode declaration;
        if (match("struct")) {
            declaration = parseAggregateDeclaration(NodeKind.structDecl, previous());
        } else if (match("resource")) {
            declaration = parseAggregateDeclaration(NodeKind.resourceDecl, previous());
        } else if (match("enum")) {
            declaration = parseEnumDeclaration(previous());
        } else if (match("when")) {
            declaration = parseWhenDeclaration(previous());
        } else if (check("const") && looksLikeModuleConst()) {
            declaration = parseModuleConstant();
        } else if (looksLikeFunction()) {
            declaration = parseFunctionDeclaration();
        } else {
            syntaxError("OPENC-SYNTAX-TOP-DECL-001", "expected a top-level declaration", current().span);
            return null;
        }
        declaration.set("export", exported ? "true" : "false");
        declaration.span = combinedSpan(start, declaration.span);
        return declaration;
    }

    bool looksLikeModuleConst() const {
        size_t i = cursor + 1;
        while (i < tokens.length && tokens[i].text != ";" && tokens[i].text != "{") {
            if (tokens[i].text == "=") return true;
            if (tokens[i].text == "(") return false;
            ++i;
        }
        return false;
    }

    bool looksLikeFunction() const {
        size_t i = cursor;
        if (tokens[i].text == "unsafe") ++i;
        if (tokens[i].text == "own") ++i;
        int nesting;
        for (; i + 1 < tokens.length; ++i) {
            auto text = tokens[i].text;
            if (text == "[" || text == "(") ++nesting;
            if (text == "]" || text == ")") --nesting;
            if (nesting == 0 && tokens[i].kind == TokenKind.identifier && tokens[i + 1].text == "(") return true;
            if (nesting == 0 && (text == ";" || text == "{" || text == "=")) return false;
        }
        return false;
    }

    AstNode parseAggregateDeclaration(NodeKind kind, Token begin) {
        auto name = expectIdentifier();
        expect("{", "OPENC-SYNTAX-BRACES-001", "expected '{' after aggregate name");
        auto node = arena.make(kind, begin.span, name.text);
        while (!atEnd() && !check("}")) {
            const before = cursor;
            node.add(parseFieldDeclaration(kind == NodeKind.resourceDecl));
            ensureProgress(before, "aggregate field declaration");
        }
        auto end = expect("}", "OPENC-SYNTAX-BRACES-001", "expected '}' after aggregate declaration");
        node.span = combinedSpan(begin.span, end.span);
        return node;
    }

    AstNode parseFieldDeclaration(bool resource) {
        const start = current().span;
        bool owns = resource && match("own");
        auto type = parseType();
        auto name = expectIdentifier();
        AstNode initializer;
        if (match("=")) initializer = parseConstantExpression();
        auto end = expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' after field declaration");
        auto node = arena.make(NodeKind.fieldDecl, combinedSpan(start, end.span), name.text)
            .set("own", owns ? "true" : "false");
        node.add(type).add(initializer);
        return node;
    }

    AstNode parseEnumDeclaration(Token begin) {
        string underlying;
        if (isUnsignedIntegerType(current().text) && peek(1).kind == TokenKind.identifier) {
            underlying = advance().text;
        }
        auto name = expectIdentifier();
        expect("{", "OPENC-SYNTAX-BRACES-001", "expected '{' after enum name");
        auto node = arena.make(NodeKind.enumDecl, begin.span, name.text).set("underlying", underlying);
        if (!check("}")) {
            do {
                auto itemToken = expectIdentifier();
                auto item = arena.make(NodeKind.enumItem, itemToken.span, itemToken.text);
                if (match("=")) item.add(parseConstantExpression());
                node.add(item);
            } while (match(",") && !check("}"));
        }
        auto end = expect("}", "OPENC-SYNTAX-BRACES-001", "expected '}' after enum declaration");
        node.span = combinedSpan(begin.span, end.span);
        return node;
    }

    AstNode parseWhenDeclaration(Token begin) {
        auto condition = parseControlCondition();
        expect("{", "OPENC-SYNTAX-BRACES-001", "expected '{' after when condition");
        auto node = arena.make(NodeKind.whenDecl, begin.span).add(condition);
        while (!atEnd() && !check("}")) {
            const before = cursor;
            auto nested = parseTopDeclaration();
            if (nested !is null) node.add(nested); else synchronizeTop();
            ensureProgress(before, "conditional declaration");
        }
        auto end = expect("}", "OPENC-SYNTAX-BRACES-001", "expected '}' after when declaration");
        node.span = combinedSpan(begin.span, end.span);
        return node;
    }

    AstNode parseModuleConstant() {
        auto begin = expect("const", "OPENC-SYNTAX-CONST-001", "expected const");
        auto type = parseType();
        auto name = expectIdentifier();
        expect("=", "OPENC-SYNTAX-INITIALIZER-001", "module constant requires initializer");
        auto value = parseConstantExpression();
        auto end = expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' after module constant");
        return arena.make(NodeKind.moduleConstDecl, combinedSpan(begin.span, end.span), name.text)
            .add(type).add(value);
    }

    AstNode parseFunctionDeclaration() {
        const start = current().span;
        bool unsafeFunction = match("unsafe");
        bool owningResult = match("own");
        AstNode resultType;
        if (match("void")) {
            resultType = arena.make(NodeKind.typeRef, previous().span, "void").set("base", "void");
        } else {
            resultType = parseType();
        }
        auto name = expectIdentifier("OPENC-SYNTAX-FUNCTION-001", "expected function name");
        expect("(", "OPENC-SYNTAX-PAREN-001", "expected '(' after function name");
        auto node = arena.make(NodeKind.functionDecl, start, name.text)
            .set("unsafe", unsafeFunction ? "true" : "false")
            .set("own_result", owningResult ? "true" : "false")
            .add(resultType);
        if (!check(")")) {
            do node.add(parseParameter()); while (match(","));
        }
        expect(")", "OPENC-SYNTAX-PAREN-001", "expected ')' after parameters");
        ++functionDepth;
        auto body = parseBlock();
        --functionDepth;
        node.add(body);
        node.span = combinedSpan(start, body.span);
        return node;
    }

    AstNode parseParameter() {
        const start = current().span;
        string mode = "value";
        if (match("out")) {
            mode = "out";
            if (match("own")) mode = "out_own";
        } else if (match("own")) {
            mode = "own";
        }
        auto type = parseType();
        auto name = expectIdentifier();
        return arena.make(NodeKind.parameter, combinedSpan(start, name.span), name.text)
            .set("mode", mode).add(type);
    }

    AstNode parseType() {
        const start = current().span;
        bool leadingConst;
        string constructor = "value";
        bool constructorConst;

        if (match("const")) leadingConst = true;
        if (match("ref")) {
            constructor = "ref";
            constructorConst = match("const");
            if (leadingConst) syntaxError("OPENC-TYPE-CONSTRUCTOR-ORDER-001", "const must follow ref", start);
        } else if (match("ptr")) {
            constructor = "ptr";
            constructorConst = match("const");
            if (leadingConst) syntaxError("OPENC-TYPE-CONSTRUCTOR-ORDER-001", "const must follow ptr", start);
        } else if (match("optional")) {
            constructor = "optional";
        } else if (match("storage")) {
            constructor = "storage";
            if (leadingConst) syntaxError("OPENC-TYPE-CONSTRUCTOR-ORDER-001", "storage is not const-qualified", start);
        }

        AstNode base;
        if (checkKind(TokenKind.keyword) && isBuiltinTypeName(current().text)) {
            auto builtin = advance();
            base = arena.make(NodeKind.qualifiedName, builtin.span, builtin.text);
        } else {
            base = parseQualifiedName();
        }
        auto node = arena.make(NodeKind.typeRef, combinedSpan(start, base.span), base.text)
            .set("constructor", constructor)
            .set("const", (leadingConst || constructorConst) ? "true" : "false")
            .set("base", base.text);

        if (match("[")) {
            if (match("]")) {
                node.set("suffix", "slice");
            } else {
                auto length = parseConstantExpression();
                auto end = expect("]", "OPENC-SYNTAX-BRACKET-001", "expected ']' after array length");
                node.set("suffix", "array").add(length);
                node.span = combinedSpan(start, end.span);
            }
            if (check("[")) {
                syntaxError("OPENC-TYPE-SUFFIX-001", "nested type suffixes are not part of OpenC Core 1.0", current().span);
            }
        }
        return node;
    }

    AstNode parseBlock() {
        auto begin = expect("{", "OPENC-SYNTAX-BRACES-001", "expected '{'");
        auto node = arena.make(NodeKind.block, begin.span);
        while (!atEnd() && !check("}")) {
            const before = cursor;
            if (looksLikeLocalDeclaration()) node.add(parseLocalDeclaration());
            else node.add(parseStatement());
            ensureProgress(before, "block item");
        }
        auto end = expect("}", "OPENC-SYNTAX-BRACES-001", "expected '}'");
        node.span = combinedSpan(begin.span, end.span);
        return node;
    }

    bool looksLikeLocalDeclaration() const {
        size_t i = cursor;
        if (["const", "ref", "ptr", "optional", "storage"].canFind(tokens[i].text)) ++i;
        if (i < tokens.length && tokens[i].text == "const") ++i;
        if (i >= tokens.length ||
            !(tokens[i].kind == TokenKind.identifier ||
              (tokens[i].kind == TokenKind.keyword && isBuiltinTypeName(tokens[i].text)))) return false;
        ++i;
        while (i < tokens.length && tokens[i].text == ".") i += 2;
        if (i < tokens.length && tokens[i].text == "[") {
            int depth = 1;
            ++i;
            while (i < tokens.length && depth) {
                if (tokens[i].text == "[") ++depth;
                else if (tokens[i].text == "]") --depth;
                ++i;
            }
        }
        return i < tokens.length && tokens[i].kind == TokenKind.identifier;
    }

    AstNode parseLocalDeclaration() {
        const start = current().span;
        auto type = parseType();
        auto name = expectIdentifier();
        AstNode initializer;
        if (match("=")) initializer = parseExpression();
        auto end = expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' after local declaration");
        return arena.make(NodeKind.localDecl, combinedSpan(start, end.span), name.text)
            .add(type).add(initializer);
    }

    AstNode parseStatement() {
        if (check("{")) return parseBlock();
        if (match("if")) return parseIf(previous());
        if (match("while")) return parseWhile(previous());
        if (match("for")) return parseFor(previous());
        if (match("switch")) return parseSwitch(previous());
        if (match("break")) return parseLoopControl(NodeKind.breakStmt, previous(), "break");
        if (match("continue")) return parseLoopControl(NodeKind.continueStmt, previous(), "continue");
        if (match("return")) return parseReturn(previous());
        if (match("scope")) return parseScope(previous());
        if (match("unsafe")) return parseUnsafe(previous());
        if (match("when")) return parseWhenStatement(previous());
        const start = current().span;
        auto expression = parseExpression();
        auto end = expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' after expression");
        return arena.make(NodeKind.expressionStmt, combinedSpan(start, end.span)).add(expression);
    }

    AstNode parseIf(Token begin) {
        auto condition = parseControlCondition();
        auto thenBlock = parseBlock();
        auto node = arena.make(NodeKind.ifStmt, begin.span).add(condition).add(thenBlock);
        if (match("else")) {
            if (check("if")) {
                advance();
                node.add(parseIf(previous()));
            } else {
                node.add(parseBlock());
            }
        }
        node.span = combinedSpan(begin.span, node.children[$ - 1].span);
        return node;
    }

    AstNode parseWhile(Token begin) {
        auto condition = parseControlCondition();
        ++loopDepth;
        auto body = parseBlock();
        --loopDepth;
        return arena.make(NodeKind.whileStmt, combinedSpan(begin.span, body.span)).add(condition).add(body);
    }

    AstNode parseFor(Token begin) {
        expect("(", "OPENC-SYNTAX-PAREN-001", "expected '(' after for");
        auto node = arena.make(NodeKind.forStmt, begin.span);
        if (!check(";")) {
            if (looksLikeLocalDeclarationWithoutSemicolon()) {
                const start = current().span;
                auto type = parseType();
                auto name = expectIdentifier();
                AstNode initializer;
                if (match("=")) initializer = parseExpression();
                node.add(arena.make(NodeKind.localDecl, combinedSpan(start, previous().span), name.text).add(type).add(initializer));
            } else node.add(parseExpression());
        }
        expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' in for header");
        if (!check(";")) node.add(parseExpression()); else node.add(null);
        expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected second ';' in for header");
        if (!check(")")) node.add(parseExpression()); else node.add(null);
        expect(")", "OPENC-SYNTAX-PAREN-001", "expected ')' after for header");
        ++loopDepth;
        auto body = parseBlock();
        --loopDepth;
        node.add(body);
        node.span = combinedSpan(begin.span, body.span);
        return node;
    }

    bool looksLikeLocalDeclarationWithoutSemicolon() const {
        return looksLikeLocalDeclaration();
    }

    AstNode parseSwitch(Token begin) {
        auto subject = parseControlCondition();
        expect("{", "OPENC-SYNTAX-BRACES-001", "expected '{' after switch subject");
        auto node = arena.make(NodeKind.switchStmt, begin.span).add(subject);
        ++loopDepth;
        while (!atEnd() && !check("}")) {
            if (match("case")) {
                auto value = parseControlCondition();
                auto body = parseBlock();
                node.add(arena.make(NodeKind.switchCase, combinedSpan(previous().span, body.span)).add(value).add(body));
            } else if (match("default")) {
                auto body = parseBlock();
                node.add(arena.make(NodeKind.defaultCase, body.span).add(body));
            } else {
                syntaxError("OPENC-SYNTAX-SWITCH-001", "expected case or default", current().span);
                advance();
            }
        }
        --loopDepth;
        auto end = expect("}", "OPENC-SYNTAX-BRACES-001", "expected '}' after switch");
        node.span = combinedSpan(begin.span, end.span);
        return node;
    }

    AstNode parseLoopControl(NodeKind kind, Token begin, string word) {
        if (loopDepth == 0) syntaxError("OPENC-LOOP-CONTEXT-001", word ~ " is only valid inside a loop or switch", begin.span);
        auto end = expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' after " ~ word);
        return arena.make(kind, combinedSpan(begin.span, end.span));
    }

    AstNode parseReturn(Token begin) {
        AstNode value;
        if (!check(";")) value = parseExpression();
        auto end = expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' after return");
        if (functionDepth == 0) syntaxError("OPENC-RETURN-CONTEXT-001", "return is only valid inside a function", begin.span);
        return arena.make(NodeKind.returnStmt, combinedSpan(begin.span, end.span)).add(value);
    }

    AstNode parseScope(Token begin) {
        auto action = parseExpression();
        auto end = expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' after scope action");
        return arena.make(NodeKind.scopeStmt, combinedSpan(begin.span, end.span)).add(action);
    }

    AstNode parseUnsafe(Token begin) {
        ++unsafeDepth;
        auto body = parseBlock();
        --unsafeDepth;
        return arena.make(NodeKind.unsafeStmt, combinedSpan(begin.span, body.span)).add(body);
    }

    AstNode parseWhenStatement(Token begin) {
        auto condition = parseControlCondition();
        auto body = parseBlock();
        return arena.make(NodeKind.whenStmt, combinedSpan(begin.span, body.span)).add(condition).add(body);
    }

    AstNode parseExpression() { return parseAssignment(); }
    AstNode parseConstantExpression() { return parseLogicalOr(); }
    AstNode parseWhenExpression() { return parseLogicalOr(); }

    AstNode parseControlCondition() {
        auto previous = allowAggregateInitializer;
        allowAggregateInitializer = false;
        auto condition = parseExpression();
        allowAggregateInitializer = previous;
        return condition;
    }

    AstNode parseAssignment() {
        auto left = parseLogicalOr();
        immutable string[] ops = ["=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<=", ">>="];
        if (ops.canFind(current().text)) {
            auto op = advance();
            auto right = parseAssignment();
            return arena.make(NodeKind.assignmentExpr, combinedSpan(left.span, right.span), op.text).add(left).add(right);
        }
        return left;
    }

    AstNode parseLogicalOr() { return parseBinary(&parseLogicalAnd, ["||"]); }
    AstNode parseLogicalAnd() { return parseBinary(&parseBitwiseOr, ["&&"]); }
    AstNode parseBitwiseOr() { return parseBinary(&parseBitwiseXor, ["|"]); }
    AstNode parseBitwiseXor() { return parseBinary(&parseBitwiseAnd, ["^"]); }
    AstNode parseBitwiseAnd() { return parseBinary(&parseEquality, ["&"]); }
    AstNode parseEquality() { return parseBinary(&parseRelational, ["==", "!="]); }
    AstNode parseRelational() { return parseBinary(&parseShift, ["<", "<=", ">", ">="]); }
    AstNode parseShift() { return parseBinary(&parseAdditive, ["<<", ">>"]); }
    AstNode parseAdditive() { return parseBinary(&parseMultiplicative, ["+", "-"]); }
    AstNode parseMultiplicative() { return parseBinary(&parseUnary, ["*", "/", "%"]); }

    alias ParseFn = AstNode delegate();
    AstNode parseBinary(ParseFn lower, string[] operators) {
        auto expression = lower();
        while (operators.canFind(current().text)) {
            auto op = advance();
            auto right = lower();
            expression = arena.make(NodeKind.binaryExpr, combinedSpan(expression.span, right.span), op.text)
                .add(expression).add(right);
        }
        return expression;
    }

    AstNode parseUnary() {
        immutable string[] unaryOps = ["!", "~", "+", "-", "&", "*"];
        if (unaryOps.canFind(current().text)) {
            auto op = advance();
            auto value = parseUnary();
            return arena.make(NodeKind.unaryExpr, combinedSpan(op.span, value.span), op.text).add(value)
                .set("unsafe_context", unsafeDepth ? "true" : "false");
        }
        if (match("cast")) return parseTypedIntrinsic(NodeKind.castExpr, previous(), false);
        if (match("cast_unchecked")) return parseTypedIntrinsic(NodeKind.castExpr, previous(), true);
        if (match("reinterpret")) return parseTypedIntrinsic(NodeKind.reinterpretExpr, previous(), true);
        if (match("construct")) return parseConstruct(previous());
        if (match("destroy")) return parseDestroy(previous());
        if (match("size_of") || match("align_of")) return parseTypeQuery(previous());
        return parsePostfix();
    }

    AstNode parseTypedIntrinsic(NodeKind kind, Token begin, bool unsafeOperation) {
        expect("(", "OPENC-SYNTAX-PAREN-001", "expected '('");
        auto type = parseType();
        expect(",", "OPENC-SYNTAX-COMMA-001", "expected ',' after type");
        auto value = parseExpression();
        auto end = expect(")", "OPENC-SYNTAX-PAREN-001", "expected ')' after expression");
        return arena.make(kind, combinedSpan(begin.span, end.span), begin.text)
            .set("unsafe_operation", unsafeOperation ? "true" : "false").add(type).add(value);
    }

    AstNode parseConstruct(Token begin) {
        expect("(", "OPENC-SYNTAX-PAREN-001", "expected '(' after construct");
        auto typeName = expectIdentifier();
        expect(",", "OPENC-SYNTAX-COMMA-001", "expected ',' after constructed type");
        auto storage = parseExpression();
        auto end = expect(")", "OPENC-SYNTAX-PAREN-001", "expected ')' after construct");
        return arena.make(NodeKind.constructExpr, combinedSpan(begin.span, end.span), typeName.text).add(storage);
    }

    AstNode parseDestroy(Token begin) {
        expect("(", "OPENC-SYNTAX-PAREN-001", "expected '(' after destroy");
        auto owner = parseQualifiedName();
        auto end = expect(")", "OPENC-SYNTAX-PAREN-001", "expected ')' after destroy");
        return arena.make(NodeKind.destroyExpr, combinedSpan(begin.span, end.span), owner.text).add(owner);
    }

    AstNode parseTypeQuery(Token begin) {
        expect("(", "OPENC-SYNTAX-PAREN-001", "expected '(' after type query");
        auto type = parseType();
        auto end = expect(")", "OPENC-SYNTAX-PAREN-001", "expected ')' after type query");
        return arena.make(NodeKind.typeQueryExpr, combinedSpan(begin.span, end.span), begin.text).add(type);
    }

    AstNode parsePostfix() {
        auto expression = parsePrimary();
        while (true) {
            if (match("(")) {
                auto call = arena.make(NodeKind.callExpr, expression.span).add(expression);
                if (!check(")")) {
                    do {
                        if (match("out")) {
                            auto name = expectIdentifier();
                            call.add(arena.make(NodeKind.outArgument, combinedSpan(previous().span, name.span), name.text));
                        } else call.add(parseExpression());
                    } while (match(","));
                }
                auto end = expect(")", "OPENC-SYNTAX-PAREN-001", "expected ')' after arguments");
                call.span = combinedSpan(expression.span, end.span);
                expression = call;
            } else if (match(".")) {
                auto member = expectIdentifier();
                expression = arena.make(NodeKind.memberExpr, combinedSpan(expression.span, member.span), member.text).add(expression);
            } else if (match("[")) {
                const begin = previous();
                AstNode first;
                if (!check("..") && !check("]")) first = parseExpression();
                if (match("..")) {
                    AstNode last;
                    if (!check("]")) last = parseExpression();
                    auto end = expect("]", "OPENC-SYNTAX-BRACKET-001", "expected ']' after range");
                    expression = arena.make(NodeKind.rangeExpr, combinedSpan(expression.span, end.span)).add(expression).add(first).add(last);
                } else {
                    auto end = expect("]", "OPENC-SYNTAX-BRACKET-001", "expected ']' after index");
                    expression = arena.make(NodeKind.indexExpr, combinedSpan(expression.span, end.span)).add(expression).add(first);
                }
            } else break;
        }
        return expression;
    }

    AstNode parsePrimary() {
        auto token = current();
        if (match("(")) {
            auto expression = parseExpression();
            expect(")", "OPENC-SYNTAX-PAREN-001", "expected ')' after expression");
            return expression;
        }
        if (token.kind == TokenKind.integerLiteral) {
            advance(); return arena.make(NodeKind.integerLiteral, token.span, token.text);
        }
        if (token.kind == TokenKind.floatLiteral) {
            advance(); return arena.make(NodeKind.floatLiteral, token.span, token.text);
        }
        if (token.kind == TokenKind.textLiteral) {
            advance(); return arena.make(NodeKind.textLiteral, token.span, token.text);
        }
        if (match("true") || match("false")) return arena.make(NodeKind.boolLiteral, previous().span, previous().text);
        if (match("null")) return arena.make(NodeKind.nullLiteral, previous().span, "null");
        if (match("none")) return arena.make(NodeKind.noneLiteral, previous().span, "none");
        if (check("status") && peek(1).text == "{") return parseStatusInitializer();
        if (check("{")) return parseArrayInitializer();
        if (token.kind == TokenKind.identifier || token.kind == TokenKind.keyword) {
            auto name = parseQualifiedName();
            if (allowAggregateInitializer && check("{")) return parseAggregateInitializer(name);
            return name;
        }
        syntaxError("OPENC-SYNTAX-EXPR-001", "expected expression", current().span);
        advance();
        return arena.make(NodeKind.missing, token.span, "<missing-expression>");
    }

    AstNode parseStatusInitializer() {
        auto begin = advance();
        expect("{", "OPENC-SYNTAX-BRACES-001", "expected '{' after status");
        auto node = arena.make(NodeKind.statusInitializer, begin.span, "status");
        if (!check("}")) {
            do {
                auto field = expectIdentifier();
                if (field.text != "code" && field.text != "message") {
                    syntaxError("OPENC-STATUS-FIELD-001", "status initializer accepts only code and message", field.span);
                }
                expect("=", "OPENC-SYNTAX-INITIALIZER-001", "expected '=' in status initializer");
                node.add(arena.make(NodeKind.aggregateField, field.span, field.text).add(parseExpression()));
            } while (match(",") && !check("}"));
        }
        auto end = expect("}", "OPENC-SYNTAX-BRACES-001", "expected '}' after status initializer");
        node.span = combinedSpan(begin.span, end.span);
        return node;
    }

    AstNode parseAggregateInitializer(AstNode name) {
        auto begin = expect("{", "OPENC-SYNTAX-BRACES-001", "expected '{'");
        auto node = arena.make(NodeKind.aggregateInitializer, name.span, name.text).add(name);
        if (!check("}")) {
            do {
                bool owns = match("own");
                auto field = expectIdentifier();
                expect("=", "OPENC-SYNTAX-INITIALIZER-001", "expected '=' in aggregate initializer");
                auto value = owns ? parseQualifiedName() : parseExpression();
                node.add(arena.make(NodeKind.aggregateField, combinedSpan(field.span, value.span), field.text)
                    .set("own", owns ? "true" : "false").add(value));
            } while (match(",") && !check("}"));
        }
        auto end = expect("}", "OPENC-SYNTAX-BRACES-001", "expected '}' after aggregate initializer");
        node.span = combinedSpan(name.span, end.span);
        return node;
    }

    AstNode parseArrayInitializer() {
        auto begin = expect("{", "OPENC-SYNTAX-BRACES-001", "expected '{'");
        auto node = arena.make(NodeKind.arrayInitializer, begin.span);
        if (!check("}")) {
            do node.add(parseExpression()); while (match(",") && !check("}"));
        }
        auto end = expect("}", "OPENC-SYNTAX-BRACES-001", "expected '}' after array initializer");
        node.span = combinedSpan(begin.span, end.span);
        return node;
    }

    AstNode parseQualifiedName() {
        auto first = expectIdentifier();
        string text = first.text;
        auto last = first.span;
        while (match(".")) {
            auto part = expectIdentifier();
            text ~= "." ~ part.text;
            last = part.span;
        }
        return arena.make(NodeKind.qualifiedName, combinedSpan(first.span, last), text);
    }

    bool isUnsignedIntegerType(string text) const {
        return ["u8", "u16", "u32", "u64"].canFind(text);
    }

    bool isBuiltinTypeName(string text) const {
        return [
            "void", "i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64",
            "isize", "usize", "bool", "byte", "f32", "f64", "text", "status"
        ].canFind(text);
    }

    void ensureProgress(size_t before, string context) {
        if (cursor != before || atEnd()) return;
        syntaxError("OPENC-SYNTAX-PROGRESS-001", "parser could not make progress while reading " ~ context, current().span);
        advance();
    }

    void synchronizeTop() {
        while (!atEnd()) {
            if (previous().text == ";" || previous().text == "}") return;
            if (["export", "struct", "resource", "enum", "const", "when", "unsafe", "void"].canFind(current().text)) return;
            advance();
        }
    }
}
