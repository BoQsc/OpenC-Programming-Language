module apps.fmt_main;

import openc.tools.formatter : Formatter, FormatterConfig;
import std.algorithm.searching : startsWith;
import std.conv : to;
import std.file : readText, write;
import std.stdio : stderr, stdout;

int main(string[] argv) {
    if (argv.length < 2) {
        stderr.writeln("usage: openc-fmt <source> [--check] [--stdout] [--indent=N] [--width=N]");
        return 2;
    }
    string path;
    bool checkOnly;
    bool toStdout;
    FormatterConfig config;
    foreach (arg; argv[1 .. $]) {
        if (arg == "--check") checkOnly = true;
        else if (arg == "--stdout") toStdout = true;
        else if (arg.startsWith("--indent=")) config.indentWidth = arg[9 .. $].to!size_t;
        else if (arg.startsWith("--width=")) config.targetWidth = arg[8 .. $].to!size_t;
        else if (!path.length) path = arg;
        else { stderr.writeln("unexpected argument: ", arg); return 2; }
    }
    if (!path.length) { stderr.writeln("source path is required"); return 2; }
    string source;
    try source = readText(path);
    catch (Exception error) { stderr.writeln(error.msg); return 2; }
    auto formatted = new Formatter(config).format(source);
    if (!formatted.ok) { stderr.writeln(formatted.error); return 1; }
    if (checkOnly) return formatted.value == source ? 0 : 1;
    if (toStdout) stdout.write(formatted.value);
    else write(path, formatted.value);
    return 0;
}
