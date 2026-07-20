module openc.token;

import openc.source : SourceSpan;

enum TokenKind {
    eofToken,
    identifier,
    integerLiteral,
    floatLiteral,
    textLiteral,
    keyword,
    symbol
}

struct Token {
    TokenKind kind;
    string text;
    SourceSpan span;

    bool matches(string value) const {
        return text == value;
    }

    bool isIdentifier() const {
        return kind == TokenKind.identifier;
    }
}
