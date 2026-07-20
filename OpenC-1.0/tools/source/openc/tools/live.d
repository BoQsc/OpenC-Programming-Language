module openc.tools.live;

import openc.compiler : CompilationOptions, Compiler;
import openc.project : ProjectConfig;
import std.algorithm.searching : startsWith;
import std.file : tempDir, write;
import std.path : buildPath;
import std.stdio : stdin, stdout;
import std.string : strip;

final class LiveEvaluator {
private:
    Compiler compiler;
    string[] declarations;
    string[] statements;
    size_t sequence;

public:
    this(Compiler compiler) { this.compiler = compiler; }

    int run() {
        stdout.writeln("OpenC live evaluator source implementation");
        stdout.writeln("Commands: :state, :reset, :quit");
        while (true) {
            stdout.write("> ");
            stdout.flush();
            auto line = stdin.readln();
            if (!line.length) break;
            if (line == ":quit\n" || line == ":quit\r\n") break;
            if (line.startsWith(":reset")) { declarations = []; statements = []; stdout.writeln("state reset"); continue; }
            if (line.startsWith(":state")) { showState(); continue; }
            if (looksLikeDeclaration(line)) declarations ~= line;
            else statements ~= line;
            auto status = checkSession();
            if (status != 0) {
                if (looksLikeDeclaration(line)) declarations.length = declarations.length - 1;
                else statements.length = statements.length - 1;
            }
        }
        return 0;
    }

private:
    int checkSession() {
        auto directory = buildPath(tempDir(), "openc-live");
        auto path = buildPath(directory, "session");
        string source;
        foreach (declaration; declarations) source ~= declaration;
        source ~= "i32 main() {\n";
        foreach (statement; statements) source ~= "    " ~ statement;
        source ~= "    return 0;\n}\n";
        write(path, source);
        auto project = ProjectConfig.singleSource(path, "live.session");
        CompilationOptions options; options.stopAfterCheck = true;
        auto result = compiler.compile(project, options);
        if (!result.ok) { stdout.writeln(result.error); return 2; }
        result.value.diagnostics.writeHuman(result.value.sources, stdout);
        return result.value.success() ? 0 : 1;
    }

    void showState() {
        stdout.writeln("declarations:");
        foreach (value; declarations) stdout.write("  " ~ value);
        stdout.writeln("statements:");
        foreach (value; statements) stdout.write("  " ~ value);
    }

    bool looksLikeDeclaration(string line) {
        auto trimmed = line.strip;
        return trimmed.startsWith("struct ") || trimmed.startsWith("resource ") || trimmed.startsWith("enum ") ||
            trimmed.startsWith("const ") || trimmed.startsWith("i8 ") || trimmed.startsWith("i16 ") ||
            trimmed.startsWith("i32 ") || trimmed.startsWith("i64 ") || trimmed.startsWith("u8 ") ||
            trimmed.startsWith("u16 ") || trimmed.startsWith("u32 ") || trimmed.startsWith("u64 ") ||
            trimmed.startsWith("bool ") || trimmed.startsWith("text ");
    }
}
