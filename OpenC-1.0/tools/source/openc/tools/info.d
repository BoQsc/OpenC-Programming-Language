module openc.tools.info;

import openc.common : canonicalSourceExtension, CompilerVersion, Result, TargetContext;
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
    root["canonical_source_extension"] = canonicalSourceExtension;
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

JSONValue commandInfo(string option, TargetContext target) {
    JSONValue root;
    root["schema"] = "openc.info.v1";
    if (option == "--limits") {
        root["usize_bits"] = cast(long) target.pointerWidth;
        root["isize_bits"] = cast(long) target.pointerWidth;
    } else if (option == "--target") {
        root["pointer_bits"] = cast(long) target.pointerWidth;
        root["endianness"] = target.endian;
        JSONValue alignment;
        alignment["pointer"] = cast(long) (target.pointerWidth / 8);
        alignment["maximum_scalar"] = cast(long) (target.pointerWidth / 8);
        root["alignment"] = alignment;
        root["floating_mode"] = "IEEE-754";
        root["unsafe_fault_model"] = "bounded-target-fault";
    } else if (option.length >= "--layout=".length &&
        option[0 .. "--layout=".length] == "--layout=") {
        root["type"] = option["--layout=".length .. $];
        root["array_stride"] = "element-size-rounded-to-alignment";
        root["struct_offsets"] = JSONValue();
        root["padding"] = "target-alignment-derived";
    } else if (option == "--diagnostic-trace") {
        JSONValue[] trace = [
            JSONValue("unsafe origin"), JSONValue("wrapper"), JSONValue("caller")
        ];
        root["trace"] = JSONValue(trace);
    }
    return root;
}
