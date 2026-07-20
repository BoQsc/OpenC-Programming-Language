module openc.tools.formatter;

import openc.common : Result;
import std.algorithm.searching : canFind;
import std.array : appender, replace;
import std.string : strip;

struct FormatterConfig {
    size_t indentWidth = 4;
    size_t targetWidth = 100;
    string lineEnding = "\n";
    bool finalNewline = true;
}

final class Formatter {
    FormatterConfig config;

    this(FormatterConfig config = FormatterConfig()) {
        this.config = config;
    }

    Result!string format(string source) {
        auto output = appender!(char[])();
        size_t indent;
        bool lineStart = true;
        bool pendingSpace;
        bool inText;
        bool inLineComment;
        bool inBlockComment;
        bool escaped;
        char previousSignificant;

        void writeIndent() {
            if (!lineStart) return;
            foreach (_; 0 .. indent * config.indentWidth) output.put(' ');
            lineStart = false;
        }

        void newline() {
            while (output.data.length && (output.data[$ - 1] == ' ' || output.data[$ - 1] == '\t')) {
                output.shrinkTo(output.data.length - 1);
            }
            if (!output.data.length || output.data[$ - 1] != '\n') output.put(config.lineEnding);
            lineStart = true;
            pendingSpace = false;
        }

        for (size_t i = 0; i < source.length; ++i) {
            char ch = source[i];
            char next = i + 1 < source.length ? source[i + 1] : '\0';

            if (inLineComment) {
                if (ch == '\r' || ch == '\n') {
                    inLineComment = false;
                    newline();
                    if (ch == '\r' && next == '\n') ++i;
                } else {
                    writeIndent();
                    output.put(ch);
                }
                continue;
            }

            if (inBlockComment) {
                writeIndent();
                output.put(ch);
                if (ch == '*' && next == '/') {
                    output.put('/');
                    ++i;
                    inBlockComment = false;
                    pendingSpace = true;
                } else if (ch == '\r' || ch == '\n') {
                    if (ch == '\r' && next == '\n') ++i;
                    newline();
                }
                continue;
            }

            if (inText) {
                writeIndent();
                output.put(ch);
                if (escaped) escaped = false;
                else if (ch == '\\') escaped = true;
                else if (ch == '"') inText = false;
                continue;
            }

            if (ch == '/' && next == '/') {
                if (pendingSpace && !lineStart) output.put(' ');
                writeIndent();
                output.put("//");
                ++i;
                inLineComment = true;
                continue;
            }
            if (ch == '/' && next == '*') {
                if (pendingSpace && !lineStart) output.put(' ');
                writeIndent();
                output.put("/*");
                ++i;
                inBlockComment = true;
                continue;
            }
            if (ch == '"') {
                if (pendingSpace && needsSpace(previousSignificant, ch)) output.put(' ');
                writeIndent();
                output.put(ch);
                inText = true;
                pendingSpace = false;
                previousSignificant = ch;
                continue;
            }
            if (ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n') {
                pendingSpace = true;
                continue;
            }
            if (ch == '{') {
                if (pendingSpace && !lineStart) output.put(' ');
                writeIndent();
                output.put('{');
                ++indent;
                newline();
                previousSignificant = ch;
                continue;
            }
            if (ch == '}') {
                if (!lineStart) newline();
                if (indent) --indent;
                writeIndent();
                output.put('}');
                pendingSpace = false;
                previousSignificant = ch;
                if (next != ';' && next != ',' && next != ')' && next != ']') newline();
                continue;
            }
            if (ch == ';') {
                writeIndent();
                output.put(';');
                newline();
                previousSignificant = ch;
                continue;
            }
            if (ch == ',') {
                writeIndent();
                output.put(',');
                output.put(' ');
                pendingSpace = false;
                previousSignificant = ch;
                continue;
            }
            if (ch == '(' || ch == '[' || ch == '.') {
                writeIndent();
                output.put(ch);
                pendingSpace = false;
                previousSignificant = ch;
                continue;
            }
            if (ch == ')' || ch == ']') {
                writeIndent();
                output.put(ch);
                pendingSpace = false;
                previousSignificant = ch;
                continue;
            }
            if (isOperator(ch)) {
                if (!lineStart && output.data[$ - 1] != ' ') output.put(' ');
                writeIndent();
                output.put(ch);
                if ((ch == '<' || ch == '>' || ch == '=' || ch == '!' || ch == '&' || ch == '|') && next == '=') {
                    output.put(next); ++i;
                } else if ((ch == '&' && next == '&') || (ch == '|' && next == '|') || (ch == '<' && next == '<') || (ch == '>' && next == '>')) {
                    output.put(next); ++i;
                }
                output.put(' ');
                pendingSpace = false;
                previousSignificant = ch;
                continue;
            }

            if (pendingSpace && needsSpace(previousSignificant, ch) && !lineStart) output.put(' ');
            writeIndent();
            output.put(ch);
            pendingSpace = false;
            previousSignificant = ch;
        }

        if (!lineStart && config.finalNewline) newline();
        auto formatted = output.data.idup;
        if (config.lineEnding != "\n") formatted = formatted.replace("\n", config.lineEnding);
        return Result!string.success(formatted);
    }

private:
    bool isOperator(char ch) const {
        return "+-*/%&|^!~=<>".canFind(ch);
    }

    bool needsSpace(char left, char right) const {
        if (left == '\0') return false;
        bool leftWord = isWord(left) || left == '"' || left == ')' || left == ']';
        bool rightWord = isWord(right) || right == '"';
        return leftWord && rightWord;
    }

    bool isWord(char ch) const {
        return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') ||
            (ch >= '0' && ch <= '9') || ch == '_';
    }
}
