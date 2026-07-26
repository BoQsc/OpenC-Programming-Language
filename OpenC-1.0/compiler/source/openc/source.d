module openc.source;

import openc.common : Result;
import std.array : appender;
import std.conv : to;
import std.file : readText;
import std.path : absolutePath, buildNormalizedPath;
import std.string : splitLines;
import std.utf : UTFException, validate;

private string withoutInitialBom(string text) {
    enum bom = "\xEF\xBB\xBF";
    return text.length >= bom.length && text[0 .. bom.length] == bom
        ? text[bom.length .. $]
        : text;
}

struct SourceId {
    size_t value;
}

struct SourcePosition {
    size_t offset;
    size_t line;
    size_t column;
}

struct SourceSpan {
    SourceId source;
    size_t start;
    size_t length;

    size_t end() const {
        return start + length;
    }

    bool empty() const {
        return length == 0;
    }
}

final class SourceFile {
    SourceId id;
    string path;
    string logicalName;
    string text;
    size_t[] lineStarts;

    this(SourceId id, string path, string logicalName, string text) {
        this.id = id;
        this.path = path;
        this.logicalName = logicalName;
        this.text = text;
        buildLines();
    }

    SourcePosition position(size_t offset) const {
        size_t low = 0;
        size_t high = lineStarts.length;
        while (low + 1 < high) {
            const mid = low + (high - low) / 2;
            if (lineStarts[mid] <= offset) {
                low = mid;
            } else {
                high = mid;
            }
        }
        return SourcePosition(offset, low + 1, offset - lineStarts[low] + 1);
    }

    string lineText(size_t oneBasedLine) const {
        if (oneBasedLine == 0 || oneBasedLine > lineStarts.length) {
            return "";
        }
        const start = lineStarts[oneBasedLine - 1];
        size_t finish = oneBasedLine < lineStarts.length ? lineStarts[oneBasedLine] : text.length;
        while (finish > start && (text[finish - 1] == '\n' || text[finish - 1] == '\r')) {
            --finish;
        }
        return text[start .. finish];
    }

private:
    void buildLines() {
        lineStarts = [0];
        foreach (index, ch; text) {
            if (ch == '\n') {
                lineStarts ~= index + 1;
            } else if (ch == '\r') {
                if (index + 1 >= text.length || text[index + 1] != '\n') {
                    lineStarts ~= index + 1;
                }
            }
        }
    }
}

final class SourceManager {
private:
    SourceFile[] files;
    SourceId[string] byPath;

public:
    Result!SourceId load(string path, string logicalName = "") {
        string normalized;
        try {
            normalized = buildNormalizedPath(absolutePath(path));
        } catch (Exception error) {
            return Result!SourceId.failure("cannot normalize source path: " ~ error.msg);
        }

        auto existing = normalized in byPath;
        if (existing !is null) {
            return Result!SourceId.success(*existing);
        }

        string text;
        try {
            text = readText(normalized);
        } catch (UTFException) {
            return Result!SourceId.failure("source file is not valid UTF-8: " ~ normalized);
        } catch (Exception error) {
            return Result!SourceId.failure("cannot read source file '" ~ normalized ~ "': " ~ error.msg);
        }

        try {
            validate(text);
        } catch (UTFException) {
            return Result!SourceId.failure("source file is not valid UTF-8: " ~ normalized);
        }
        text = withoutInitialBom(text);

        auto id = SourceId(files.length);
        auto file = new SourceFile(id, normalized, logicalName.length ? logicalName : normalized, text);
        files ~= file;
        byPath[normalized] = id;
        return Result!SourceId.success(id);
    }

    SourceId addVirtual(string logicalName, string text) {
        text = withoutInitialBom(text);
        auto id = SourceId(files.length);
        files ~= new SourceFile(id, "<" ~ logicalName ~ ">", logicalName, text);
        return id;
    }

    SourceFile get(SourceId id) {
        assert(id.value < files.length);
        return files[id.value];
    }

    const(SourceFile) get(SourceId id) const {
        assert(id.value < files.length);
        return files[id.value];
    }

    size_t count() const {
        return files.length;
    }

    SourceFile[] all() {
        return files.dup;
    }

    const(SourceFile)[] all() const {
        return files;
    }
}
