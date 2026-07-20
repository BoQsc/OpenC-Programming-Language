module openc.native;

import openc.ast : AstArena, AstNode, NodeKind;
import openc.common : Result, TypeId;
import openc.diagnostic : DiagnosticEngine, DiagnosticPhase;
import openc.source : SourceSpan;
import openc.token : Token, TokenKind;
import openc.types : TypeTable;

struct NativeParameter {
    string name;
    TypeId type;
    string mode;
}

struct ExternalFunction {
    string abi;
    string sourceName;
    string symbolName;
    TypeId result;
    NativeParameter[] parameters;
    bool unsafeFunction;
    SourceSpan span;
}

struct NativeLayoutField {
    string name;
    TypeId type;
    size_t offset;
}

struct NativeLayout {
    string abi;
    string name;
    NativeLayoutField[] fields;
    size_t size;
    size_t alignment;
    SourceSpan span;
}

final class NativeRegistry {
    ExternalFunction[] functions;
    NativeLayout[] layouts;
    string[] linkInputs;

    ExternalFunction* findFunction(string name) {
        foreach (ref functionValue; functions) if (functionValue.sourceName == name) return &functionValue;
        return null;
    }
}

final class NativeDeclarationParser {
private:
    Token[] tokens;
    size_t cursor;
    DiagnosticEngine diagnostics;
    TypeTable types;

public:
    this(Token[] tokens, DiagnosticEngine diagnostics, TypeTable types) {
        this.tokens = tokens;
        this.diagnostics = diagnostics;
        this.types = types;
    }

    NativeRegistry parse() {
        auto registry = new NativeRegistry();
        while (!atEnd()) {
            if (match("external")) registry.functions ~= parseExternal(previous().span);
            else if (match("layout")) registry.layouts ~= parseLayout(previous().span);
            else advance();
        }
        return registry;
    }

private:
    ExternalFunction parseExternal(SourceSpan start) {
        ExternalFunction result;
        result.span = start;
        expect("(");
        result.abi = expectIdentifier().text;
        expect(")");
        result.unsafeFunction = match("unsafe");
        result.result = parseSimpleType();
        result.sourceName = expectIdentifier().text;
        result.symbolName = result.sourceName;
        if (match("as")) result.symbolName = expectText().text[1 .. $ - 1];
        expect("(");
        if (!check(")")) {
            do {
                NativeParameter parameter;
                if (match("out")) parameter.mode = "out";
                else if (match("own")) parameter.mode = "own";
                else parameter.mode = "value";
                parameter.type = parseSimpleType();
                parameter.name = expectIdentifier().text;
                result.parameters ~= parameter;
            } while (match(","));
        }
        expect(")");
        expect(";");
        return result;
    }

    NativeLayout parseLayout(SourceSpan start) {
        NativeLayout result;
        result.span = start;
        expect("(");
        result.abi = expectIdentifier().text;
        expect(")");
        expect("struct");
        result.name = expectIdentifier().text;
        expect("{");
        while (!atEnd() && !check("}")) {
            NativeLayoutField field;
            field.type = parseSimpleType();
            field.name = expectIdentifier().text;
            expect(";");
            result.fields ~= field;
        }
        expect("}");
        return result;
    }

    TypeId parseSimpleType() {
        bool pointer = match("ptr");
        bool constQualified = pointer && match("const");
        auto name = expectIdentifier().text;
        auto base = types.find(name);
        if (base == types.errorType) base = types.declareNamed(name);
        return pointer ? types.pointer(base, constQualified) : base;
    }

    Token current() const { return tokens[cursor]; }
    Token previous() const { return cursor ? tokens[cursor - 1] : tokens[0]; }
    bool atEnd() const { return current().kind == TokenKind.eofToken; }
    Token advance() { if (!atEnd()) ++cursor; return previous(); }
    bool check(string text) const { return current().text == text; }
    bool match(string text) { if (!check(text)) return false; advance(); return true; }
    Token expect(string text) {
        if (match(text)) return previous();
        diagnostics.error("OPENC-NATIVE-SYNTAX-001", DiagnosticPhase.syntax,
            "native.syntax", "expected '" ~ text ~ "'", current().span);
        return Token(TokenKind.symbol, text, current().span);
    }
    Token expectIdentifier() {
        if (current().kind == TokenKind.identifier || current().kind == TokenKind.keyword) return advance();
        diagnostics.error("OPENC-NATIVE-SYNTAX-001", DiagnosticPhase.syntax,
            "native.syntax", "expected identifier", current().span);
        return Token(TokenKind.identifier, "<missing>", current().span);
    }
    Token expectText() {
        if (current().kind == TokenKind.textLiteral) return advance();
        diagnostics.error("OPENC-NATIVE-SYMBOL-001", DiagnosticPhase.syntax,
            "native.symbol", "expected text literal symbol name", current().span);
        return Token(TokenKind.textLiteral, "\"\"", current().span);
    }
}
