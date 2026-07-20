module openc.project;

import openc.common : Result, TargetArch, TargetContext, TargetOS;
import std.algorithm : sort;
import std.file : readText;
import std.json : JSONType, JSONValue, parseJSON;
import std.path : absolutePath, buildNormalizedPath, dirName;

struct ProjectModule {
    string name;
    string[] sources;
}

struct ProjectConfig {
    string path;
    string root;
    string edition = "1.0";
    string profile = "standard";
    string outputDirectory = "build";
    string runtimeDirectory;
    string standardLibraryDirectory;
    ProjectModule[] modules;
    TargetContext target;
    string[string] options;

    static Result!ProjectConfig load(string path) {
        JSONValue rootJson;
        try {
            rootJson = parseJSON(readText(path));
        } catch (Exception error) {
            return Result!ProjectConfig.failure("cannot read project configuration: " ~ error.msg);
        }
        if (rootJson.type != JSONType.object) {
            return Result!ProjectConfig.failure("project configuration must be a JSON object");
        }
        ProjectConfig config;
        config.path = buildNormalizedPath(absolutePath(path));
        config.root = dirName(config.path);
        auto object = rootJson.object;
        if (auto value = "edition" in object) config.edition = value.str;
        if (auto value = "profile" in object) config.profile = value.str;
        if (auto value = "output_directory" in object) config.outputDirectory = value.str;
        if (auto value = "runtime_directory" in object) {
            config.runtimeDirectory = buildNormalizedPath(config.root, value.str);
        }
        if (auto value = "standard_library_directory" in object) {
            config.standardLibraryDirectory = buildNormalizedPath(config.root, value.str);
        }
        if (auto modules = "modules" in object) {
            foreach (name, value; modules.object) {
                ProjectModule moduleConfig;
                moduleConfig.name = name;
                foreach (source; value.array) {
                    moduleConfig.sources ~= buildNormalizedPath(config.root, source.str);
                }
                config.modules ~= moduleConfig;
            }
            config.modules.sort!((a, b) => a.name < b.name);
        }
        if (auto target = "target" in object) {
            if (target.type == JSONType.string) {
                applyTargetName(config.target, target.str);
            } else if (target.type == JSONType.object) {
                auto targetObject = target.object;
                if (auto value = "name" in targetObject) applyTargetName(config.target, value.str);
                if (auto value = "os" in targetObject) config.target.os = parseOS(value.str);
                if (auto value = "arch" in targetObject) config.target.arch = parseArch(value.str);
                if (auto value = "pointer_width" in targetObject) config.target.pointerWidth = cast(size_t)value.integer;
                if (auto value = "endian" in targetObject) config.target.endian = value.str;
                if (auto value = "abi" in targetObject) config.target.abi = value.str;
                if (auto values = "values" in targetObject) {
                    foreach (key, item; values.object) config.target.values[key] = item.toString();
                }
            } else {
                return Result!ProjectConfig.failure("project target must be a string or object");
            }
        } else {
            applyHostDefaults(config.target);
        }
        return Result!ProjectConfig.success(config);
    }

    static ProjectConfig singleSource(string sourcePath, string moduleName = "app.main") {
        ProjectConfig config;
        config.root = dirName(buildNormalizedPath(absolutePath(sourcePath)));
        config.path = "<single-source>";
        config.modules = [ProjectModule(moduleName, [buildNormalizedPath(absolutePath(sourcePath))])];
        applyHostDefaults(config.target);
        return config;
    }

private:
    static void applyTargetName(ref TargetContext target, string value) {
        if (value == "linux-x86_64") {
            target.os = TargetOS.linux; target.arch = TargetArch.x86_64; target.pointerWidth = 64; target.endian = "little"; target.abi = "sysv";
        } else if (value == "windows-x86_64") {
            target.os = TargetOS.windows; target.arch = TargetArch.x86_64; target.pointerWidth = 64; target.endian = "little"; target.abi = "win64";
        } else if (value == "freestanding-x86_64" || value == "freestanding") {
            target.os = TargetOS.freestanding; target.arch = TargetArch.x86_64; target.pointerWidth = 64; target.endian = "little"; target.abi = "target";
        }
        target.values["target.name"] = value;
    }

    static void applyHostDefaults(ref TargetContext target) {
        version (Windows) applyTargetName(target, "windows-x86_64");
        else version (linux) applyTargetName(target, "linux-x86_64");
        else applyTargetName(target, "freestanding");
    }

    static TargetOS parseOS(string value) {
        if (value == "linux") return TargetOS.linux;
        if (value == "windows") return TargetOS.windows;
        if (value == "freestanding") return TargetOS.freestanding;
        return TargetOS.unknown;
    }

    static TargetArch parseArch(string value) {
        if (value == "x86_64") return TargetArch.x86_64;
        if (value == "aarch64") return TargetArch.aarch64;
        return TargetArch.unknown;
    }
}
