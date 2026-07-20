module openc.diagnostic;

import openc.source : SourceManager, SourceSpan;
import std.algorithm : sort;
import std.array : array;
import std.format : format;
import std.json : JSONValue;
import std.stdio : File, stderr;
import std.string : join;

enum DiagnosticSeverity : string {
    error = "error",
    warning = "warning",
    note = "note",
    help = "help"
}

enum DiagnosticPhase : string {
    source = "source",
    lexical = "lexical",
    syntax = "syntax",
    declaration = "declaration",
    name = "name",
    type = "type",
    constant = "constant",
    flow = "flow",
    ownership = "ownership",
    borrow = "borrow",
    unsafePhase = "unsafe",
    target = "target",
    runtime = "runtime",
    tooling = "tooling"
}

struct RelatedLocation {
    DiagnosticSeverity severity = DiagnosticSeverity.note;
    string message;
    SourceSpan span;
}

struct Diagnostic {
    string rule;
    string category;
    DiagnosticSeverity severity = DiagnosticSeverity.error;
    DiagnosticPhase phase = DiagnosticPhase.syntax;
    string message;
    SourceSpan span;
    RelatedLocation[] related;
    string[] help;

    JSONValue toJson(SourceManager sources) const {
        auto source = sources.get(span.source);
        auto pos = source.position(span.start);
        JSONValue result;
        result["rule"] = rule;
        result["category"] = category;
        result["severity"] = cast(string) severity;
        result["phase"] = cast(string) phase;
        result["message"] = message;
        result["file"] = source.path;
        result["logical_source"] = source.logicalName;
        result["line"] = pos.line;
        result["column"] = pos.column;
        result["offset"] = span.start;
        result["length"] = span.length;

        JSONValue[] relatedJson;
        foreach (item; related) {
            auto relatedSource = sources.get(item.span.source);
            auto relatedPos = relatedSource.position(item.span.start);
            JSONValue node;
            node["severity"] = cast(string) item.severity;
            node["message"] = item.message;
            node["file"] = relatedSource.path;
            node["line"] = relatedPos.line;
            node["column"] = relatedPos.column;
            node["offset"] = item.span.start;
            node["length"] = item.span.length;
            relatedJson ~= node;
        }
        result["related"] = JSONValue(relatedJson);

        JSONValue[] helpJson;
        foreach (line; help) {
            helpJson ~= JSONValue(line);
        }
        result["help"] = JSONValue(helpJson);
        return result;
    }
}

final class DiagnosticEngine {
private:
    Diagnostic[] diagnostics;
    size_t errorCount;
    size_t warningCount;

public:
    void emit(Diagnostic diagnostic) {
        diagnostics ~= diagnostic;
        if (diagnostic.severity == DiagnosticSeverity.error) {
            ++errorCount;
        } else if (diagnostic.severity == DiagnosticSeverity.warning) {
            ++warningCount;
        }
    }

    void error(string rule, DiagnosticPhase phase, string category, string message, SourceSpan span) {
        emit(Diagnostic(rule, category, DiagnosticSeverity.error, phase, message, span));
    }

    void warning(string rule, DiagnosticPhase phase, string category, string message, SourceSpan span) {
        emit(Diagnostic(rule, category, DiagnosticSeverity.warning, phase, message, span));
    }

    bool hasErrors() const { return errorCount != 0; }
    size_t errors() const { return errorCount; }
    size_t warnings() const { return warningCount; }
    const(Diagnostic)[] all() const { return diagnostics; }

    JSONValue toJson(SourceManager sources) const {
        JSONValue[] values;
        foreach (diagnostic; diagnostics) {
            values ~= diagnostic.toJson(sources);
        }
        JSONValue result;
        result["errors"] = errorCount;
        result["warnings"] = warningCount;
        result["diagnostics"] = JSONValue(values);
        return result;
    }

    void writeHuman(SourceManager sources, File output = stderr) const {
        foreach (diagnostic; diagnostics) {
            auto source = sources.get(diagnostic.span.source);
            auto pos = source.position(diagnostic.span.start);
            output.writefln("%s %s [%s] %s:%s:%s: %s",
                cast(string) diagnostic.severity,
                diagnostic.rule,
                cast(string) diagnostic.phase,
                source.path,
                pos.line,
                pos.column,
                diagnostic.message);
            auto line = source.lineText(pos.line);
            if (line.length) {
                output.writeln("  " ~ line);
                string caret = "  ";
                foreach (_; 1 .. pos.column) caret ~= " ";
                caret ~= "^";
                output.writeln(caret);
            }
            foreach (related; diagnostic.related) {
                auto rs = sources.get(related.span.source);
                auto rp = rs.position(related.span.start);
                output.writefln("  %s: %s (%s:%s:%s)",
                    cast(string) related.severity, related.message,
                    rs.path, rp.line, rp.column);
            }
            foreach (help; diagnostic.help) {
                output.writeln("  help: " ~ help);
            }
        }
    }
}
