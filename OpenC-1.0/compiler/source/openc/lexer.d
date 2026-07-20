module openc.lexer;

import openc.diagnostic : DiagnosticEngine, DiagnosticPhase;
import openc.source : SourceFile, SourceSpan;
import openc.token : Token, TokenKind;
import std.algorithm.searching : canFind;
import std.ascii : isAlpha, isAlphaNum, isDigit, isHexDigit;
import std.array : appender;
import std.string : indexOf;
import std.utf : decodeFront;

private immutable string[] keywords = [
    "import", "export", "const", "struct", "resource", "enum", "unsafe",
    "void", "own", "out", "when", "ref", "ptr", "optional", "storage",
    "if", "else", "while", "for", "switch", "case", "default", "break",
    "continue", "return", "scope", "cast", "cast_unchecked", "reinterpret",
    "construct", "destroy", "size_of", "align_of", "true", "false", "null",
    "none", "i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64",
    "isize", "usize", "bool", "byte", "f32", "f64", "text", "status"
];

final class Lexer {
private:
    SourceFile source;
    DiagnosticEngine diagnostics;
    size_t cursor;

public:
    this(SourceFile source, DiagnosticEngine diagnostics) {
        this.source = source;
        this.diagnostics = diagnostics;
    }

    Token[] lex() {
        Token[] result;
        while (!atEnd()) {
            skipIgnored();
            if (atEnd()) break;
            const start = cursor;
            const c = current();
            if (isIdentifierStart(c)) {
                result ~= lexIdentifier(start);
            } else if (isDigit(c)) {
                result ~= lexNumber(start);
            } else if (c == '"') {
                result ~= lexText(start);
            } else {
                result ~= lexSymbol(start);
            }
        }
        result ~= Token(TokenKind.eofToken, "<eof>", span(cursor, 0));
        return result;
    }

private:
    bool atEnd() const { return cursor >= source.text.length; }
    char current() const { return source.text[cursor]; }
    char peek(size_t distance = 1) const {
        const index = cursor + distance;
        return index < source.text.length ? source.text[index] : '\0';
    }
    void advance(size_t count = 1) { cursor += count; }
    SourceSpan span(size_t start, size_t length) const {
        return SourceSpan(source.id, start, length);
    }

    bool isIdentifierStart(char c) const {
        return isAlpha(c) || c == '_';
    }
    bool isIdentifierContinue(char c) const {
        return isAlphaNum(c) || c == '_';
    }

    void skipIgnored() {
        while (!atEnd()) {
            const c = current();
            if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
                advance();
                continue;
            }
            if (c == '/' && peek() == '/') {
                advance(2);
                while (!atEnd() && current() != '\n' && current() != '\r') advance();
                continue;
            }
            if (c == '/' && peek() == '*') {
                const start = cursor;
                advance(2);
                bool closed;
                while (!atEnd()) {
                    if (current() == '*' && peek() == '/') {
                        advance(2);
                        closed = true;
                        break;
                    }
                    advance();
                }
                if (!closed) {
                    diagnostics.error("OPENC-LEX-COMMENT-001", DiagnosticPhase.lexical,
                        "lexical.comment", "unterminated block comment", span(start, cursor - start));
                }
                continue;
            }
            break;
        }
    }

    Token lexIdentifier(size_t start) {
        advance();
        while (!atEnd() && isIdentifierContinue(current())) advance();
        auto text = source.text[start .. cursor];
        auto kind = keywords.canFind(text) ? TokenKind.keyword : TokenKind.identifier;
        return Token(kind, text, span(start, cursor - start));
    }

    Token lexNumber(size_t start) {
        bool hexadecimal;
        bool binary;
        bool floating;
        if (current() == '0' && (peek() == 'x' || peek() == 'X')) {
            hexadecimal = true;
            advance(2);
            lexDigits(start, true, false);
        } else if (current() == '0' && (peek() == 'b' || peek() == 'B')) {
            binary = true;
            advance(2);
            lexDigits(start, false, true);
        } else {
            lexDigits(start, false, false);
            if (!atEnd() && current() == '.' && peek() != '.') {
                floating = true;
                advance();
                lexDigits(start, false, false);
            }
            if (!atEnd() && (current() == 'e' || current() == 'E')) {
                floating = true;
                advance();
                if (!atEnd() && (current() == '+' || current() == '-')) advance();
                lexDigits(start, false, false);
            }
        }
        auto text = source.text[start .. cursor];
        if (!atEnd() && isIdentifierStart(current())) {
            const suffixStart = cursor;
            while (!atEnd() && isIdentifierContinue(current())) advance();
            diagnostics.error("OPENC-LEX-NUMBER-SUFFIX-001", DiagnosticPhase.lexical,
                "lexical.number", "numeric suffixes are not part of OpenC Core",
                span(suffixStart, cursor - suffixStart));
        }
        return Token(floating ? TokenKind.floatLiteral : TokenKind.integerLiteral,
            text, span(start, cursor - start));
    }

    void lexDigits(size_t literalStart, bool hex, bool binary) {
        bool sawDigit;
        bool lastSeparator;
        while (!atEnd()) {
            const c = current();
            const valid = hex ? isHexDigit(c) : binary ? (c == '0' || c == '1') : isDigit(c);
            if (valid) {
                sawDigit = true;
                lastSeparator = false;
                advance();
            } else if (c == '_') {
                if (!sawDigit || lastSeparator) {
                    diagnostics.error("OPENC-LEX-NUMBER-SEPARATOR-001", DiagnosticPhase.lexical,
                        "lexical.number", "numeric separators must occur between digits",
                        span(cursor, 1));
                }
                lastSeparator = true;
                advance();
            } else {
                break;
            }
        }
        if (!sawDigit || lastSeparator) {
            diagnostics.error("OPENC-LEX-NUMBER-001", DiagnosticPhase.lexical,
                "lexical.number", "malformed numeric literal", span(literalStart, cursor - literalStart));
        }
    }

    Token lexText(size_t start) {
        advance();
        bool closed;
        while (!atEnd()) {
            const c = current();
            if (c == '"') {
                advance();
                closed = true;
                break;
            }
            if (c == '\n' || c == '\r') {
                diagnostics.error("OPENC-LEX-TEXT-LINE-001", DiagnosticPhase.lexical,
                    "lexical.text", "text literal cannot contain an unescaped line break",
                    span(start, cursor - start));
                break;
            }
            if (c == '\\') {
                const escapeStart = cursor;
                advance();
                if (atEnd()) break;
                const escape = current();
                if (escape == 'u') {
                    advance();
                    if (atEnd() || current() != '{') {
                        diagnostics.error("OPENC-LEX-TEXT-ESCAPE-001", DiagnosticPhase.lexical,
                            "lexical.text", "Unicode escape requires u{...}", span(escapeStart, cursor - escapeStart));
                    } else {
                        advance();
                        size_t digits;
                        uint scalar;
                        while (!atEnd() && isHexDigit(current()) && digits < 6) {
                            auto digit = current() >= '0' && current() <= '9'
                                ? cast(uint) (current() - '0')
                                : current() >= 'a' && current() <= 'f'
                                    ? cast(uint) (current() - 'a' + 10)
                                    : cast(uint) (current() - 'A' + 10);
                            scalar = scalar * 16 + digit;
                            ++digits;
                            advance();
                        }
                        if (digits == 0 || atEnd() || current() != '}') {
                            diagnostics.error("OPENC-LEX-TEXT-UNICODE-001", DiagnosticPhase.lexical,
                                "lexical.text", "Unicode escape requires one to six hexadecimal digits",
                                span(escapeStart, cursor - escapeStart));
                        } else {
                            if ((scalar >= 0xD800 && scalar <= 0xDFFF) || scalar > 0x10FFFF) {
                                diagnostics.error("OPENC-LITERAL-UNICODE-001", DiagnosticPhase.lexical,
                                    "literal.unicode", "Unicode escape is not a scalar value",
                                    span(escapeStart, cursor - escapeStart + 1));
                            }
                            advance();
                        }
                    }
                } else {
                    if ("\\\"nrt0".indexOf(escape) < 0) {
                        diagnostics.error("OPENC-LEX-TEXT-ESCAPE-001", DiagnosticPhase.lexical,
                            "lexical.text", "unknown text escape", span(escapeStart, 2));
                    }
                    advance();
                }
                continue;
            }
            advance();
        }
        if (!closed) {
            diagnostics.error("OPENC-LEX-TEXT-001", DiagnosticPhase.lexical,
                "lexical.text", "unterminated text literal", span(start, cursor - start));
        }
        return Token(TokenKind.textLiteral, source.text[start .. cursor], span(start, cursor - start));
    }

    Token lexSymbol(size_t start) {
        immutable string[] three = ["<<=", ">>="];
        immutable string[] two = [
            "==", "!=", "<=", ">=", "<<", ">>", "&&", "||", "+=", "-=",
            "*=", "/=", "%=", "&=", "|=", "^=", ".."
        ];
        foreach (symbol; three) {
            if (startsWith(symbol)) {
                advance(symbol.length);
                return Token(TokenKind.symbol, symbol, span(start, symbol.length));
            }
        }
        foreach (symbol; two) {
            if (startsWith(symbol)) {
                advance(symbol.length);
                return Token(TokenKind.symbol, symbol, span(start, symbol.length));
            }
        }
        const c = current();
        if (";,.(){}[]:+-*/%&|^!~=<>".indexOf(c) >= 0) {
            advance();
            return Token(TokenKind.symbol, source.text[start .. cursor], span(start, 1));
        }
        advance();
        diagnostics.error(c == '?' ? "OPENC-SYNTAX-OPTIONAL-001" : "OPENC-LEX-TOKEN-001",
            DiagnosticPhase.lexical, "lexical.token",
            c == '?' ? "optional types use the word-shaped 'optional T' syntax" :
                "invalid source character", span(start, 1));
        return Token(TokenKind.symbol, source.text[start .. cursor], span(start, 1));
    }

    bool startsWith(string text) const {
        return cursor + text.length <= source.text.length &&
            source.text[cursor .. cursor + text.length] == text;
    }
}
