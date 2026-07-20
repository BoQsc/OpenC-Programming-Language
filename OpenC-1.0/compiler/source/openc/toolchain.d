module openc.toolchain;

import openc.backend : BackendOutput;
import openc.common : CompilerVersion, Result, TargetOS;
import openc.project : ProjectConfig;
import std.algorithm : sort;
import std.algorithm.searching : startsWith;
import std.array : array;
import std.datetime.systime : Clock;
import std.file : dirEntries, exists, isFile, mkdirRecurse, SpanMode, write;
import std.json : JSONValue;
import std.path : absolutePath, baseName, buildPath;
import std.process : environment, escapeShellCommand, execute, executeShell;
import std.string : join, splitLines, strip;

struct ToolchainResult {
    string compiler;
    string compilerVersion;
    string command;
    string executable;
    int exitCode;
    string output;

    bool success() const { return exitCode == 0; }

    JSONValue toJson() const {
        JSONValue value;
        value["compiler"] = compiler;
        value["version"] = compilerVersion;
        value["command"] = command;
        value["executable"] = executable;
        value["exit_code"] = exitCode;
        value["output"] = output;
        value["success"] = success();
        return value;
    }
}

final class DToolchain {
    Result!ToolchainResult build(
        BackendOutput generated,
        ProjectConfig project,
        string runtimeRoot,
        string libraryRoot,
        string outputPath,
        string recordPath = ""
    ) {
        auto selected = findCompiler();
        if (!selected.ok) return Result!ToolchainResult.failure(selected.error);
        auto compiler = selected.value;
        auto versionText = compilerVersion(compiler);

        string[] sources = generated.files.dup;
        sources ~= collectD(runtimeRoot);
        sources ~= collectD(libraryRoot);
        sources.sort();
        sources = unique(sources);

        auto outputDirectory = outputPath.length ? outputPath : buildPath(project.outputDirectory, defaultExecutableName(project));
        try mkdirRecurse(buildPath(outputDirectory, ".."));
        catch (Exception) {}

        string[] args;
        if (baseName(compiler).startsWith("gdc")) {
            args = [compiler, "-O2", "-g", "-Wall", "-o", outputDirectory];
            args ~= sources;
        } else if (baseName(compiler).startsWith("ldc")) {
            args = [compiler, "-O2", "-g", "-of=" ~ outputDirectory];
            args ~= sources;
        } else {
            args = [compiler, "-O", "-g", "-of=" ~ outputDirectory];
            args ~= sources;
        }

        auto command = escapeShellCommand(args);
        auto executed = executeShell(command);
        ToolchainResult result;
        result.compiler = compiler;
        result.compilerVersion = versionText;
        result.command = command;
        result.executable = outputDirectory;
        result.exitCode = executed.status;
        result.output = executed.output;

        if (recordPath.length) {
            JSONValue record;
            record["schema"] = "openc.build_record.v1";
            record["timestamp_utc"] = Clock.currTime().toISOExtString();
            record["target"] = project.target.toJson();
            record["toolchain"] = result.toJson();
            JSONValue[] sourceList;
            foreach (source; sources) sourceList ~= JSONValue(source);
            record["sources"] = JSONValue(sourceList);
            try write(recordPath, record.toPrettyString() ~ "\n");
            catch (Exception) {}
        }

        return result.success()
            ? Result!ToolchainResult.success(result)
            : Result!ToolchainResult.failure("D bootstrap toolchain failed:\n" ~ result.output);
    }

    Result!string findCompiler() {
        auto explicitCompiler = environment.get("OPENC_D_COMPILER", "");
        if (explicitCompiler.length) return Result!string.success(explicitCompiler);
        foreach (candidate; ["ldc2", "gdc", "gdc-14", "gdc-13", "dmd"]) {
            auto probe = executeShell(candidate ~ " --version");
            if (probe.status == 0) return Result!string.success(candidate);
        }
        return Result!string.failure(
            "no D compiler found; set OPENC_D_COMPILER to ldc2, gdc, or dmd");
    }

private:
    string compilerVersion(string compiler) {
        auto result = executeShell(escapeShellCommand(compiler, "--version"));
        auto line = result.output.splitLines();
        return line.length ? line[0].strip : "unknown";
    }

    string[] collectD(string root) {
        string[] result;
        if (!exists(root)) return result;
        foreach (entry; dirEntries(root, "*.d", SpanMode.depth)) {
            if (entry.isFile) result ~= entry.name;
        }
        return result;
    }

    string[] unique(string[] values) {
        string[] result;
        string previous;
        bool havePrevious;
        foreach (value; values) {
            if (!havePrevious || value != previous) result ~= value;
            previous = value;
            havePrevious = true;
        }
        return result;
    }

    string defaultExecutableName(ProjectConfig project) {
        version (Windows) return "openc-program.exe";
        else return "openc-program";
    }
}
