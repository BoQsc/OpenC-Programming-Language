module openc.command;

import openc.common : Result;
import std.algorithm.searching : endsWith, startsWith;
import std.array : array;
import std.string : indexOf, replace, strip, split, toLower;

struct CommandRequest {
    string command;
    string[] positionals;
    string[string] options;

    string option(string name, string fallback = "") const {
        auto found = name in options;
        return found is null ? fallback : *found;
    }

    bool flag(string name) const {
        auto value = option(name);
        return value == "true" || value == "1" || value == "yes";
    }
}

Result!CommandRequest normalize(string[] arguments) {
    if (!arguments.length) return Result!CommandRequest.failure("missing command");
    if (arguments.length == 1 && arguments[0].indexOf('(') >= 0 && arguments[0].endsWith(")")) {
        return parseCallSyntax(arguments[0]);
    }
    CommandRequest request;
    request.command = arguments[0];
    for (size_t i = 1; i < arguments.length; ++i) {
        auto value = arguments[i];
        if (value.startsWith("--")) {
            auto content = value[2 .. $];
            auto equals = content.indexOf('=');
            if (equals >= 0) {
                request.options[normalizeName(content[0 .. equals])] = unquote(content[equals + 1 .. $]);
            } else if (i + 1 < arguments.length && !arguments[i + 1].startsWith("--")) {
                request.options[normalizeName(content)] = unquote(arguments[++i]);
            } else {
                request.options[normalizeName(content)] = "true";
            }
        } else request.positionals ~= value;
    }
    return Result!CommandRequest.success(request);
}

private {
    Result!CommandRequest parseCallSyntax(string text) {
        auto open = text.indexOf('(');
        if (open <= 0 || text[$ - 1] != ')') return Result!CommandRequest.failure("invalid command call syntax");
        CommandRequest request;
        request.command = text[0 .. open].strip;
        auto callBody = text[open + 1 .. $ - 1].strip;
        if (!callBody.length) return Result!CommandRequest.success(request);
        foreach (part; splitArguments(callBody)) {
            auto equals = part.indexOf('=');
            if (equals < 0) request.positionals ~= unquote(part.strip);
            else request.options[normalizeName(part[0 .. equals].strip)] = unquote(part[equals + 1 .. $].strip);
        }
        return Result!CommandRequest.success(request);
    }

    string[] splitArguments(string text) {
        string[] result;
        size_t start;
        bool quoted;
        char quote;
        int depth;
        foreach (index, ch; text) {
            if (quoted) {
                if (ch == quote && (index == 0 || text[index - 1] != '\\')) quoted = false;
                continue;
            }
            if (ch == '"' || ch == '\'') { quoted = true; quote = ch; }
            else if (ch == '(' || ch == '[' || ch == '{') ++depth;
            else if (ch == ')' || ch == ']' || ch == '}') --depth;
            else if (ch == ',' && depth == 0) { result ~= text[start .. index].strip; start = index + 1; }
        }
        result ~= text[start .. $].strip;
        return result;
    }

    string normalizeName(string name) { return name.replace("-", "_"); }
    string unquote(string value) {
        if (value.length >= 2 && ((value[0] == '"' && value[$ - 1] == '"') || (value[0] == '\'' && value[$ - 1] == '\''))) return value[1 .. $ - 1];
        return value;
    }
}
