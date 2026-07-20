module openc.tools.info;

import openc.common : CompilerVersion, Result;
import openc.project : ProjectConfig;
import std.json : JSONValue;

JSONValue projectInfo(ProjectConfig project, CompilerVersion compilerVersion) {
    JSONValue root;
    root["schema"] = "openc.tool_context.v1";
    root["implementation"] = compilerVersion.toJson();
    root["edition"] = project.edition;
    root["profile"] = project.profile;
    root["project"] = project.path;
    root["root"] = project.root;
    root["output_directory"] = project.outputDirectory;
    root["target"] = project.target.toJson();
    JSONValue[] modules;
    foreach (moduleConfig; project.modules) {
        JSONValue moduleValue;
        moduleValue["name"] = moduleConfig.name;
        JSONValue[] sources;
        foreach (source; moduleConfig.sources) sources ~= JSONValue(source);
        moduleValue["sources"] = JSONValue(sources);
        modules ~= moduleValue;
    }
    root["modules"] = JSONValue(modules);
    return root;
}
