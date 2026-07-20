module openc.backend_ir;

import openc.backend : Backend, BackendOutput;
import openc.common : Result;
import openc.ir : IrProgram;
import openc.semantic_model : SemanticModel;
import openc.source : SourceManager;
import std.file : mkdirRecurse, write;
import std.json : toJSON;
import std.path : buildPath;

final class JsonIrBackend : Backend {
    string name() const { return "json-ir"; }
    string description() const { return "Writes the reference OpenC Core IR as deterministic JSON"; }

    Result!BackendOutput emit(IrProgram program, SemanticModel model, SourceManager sources, string outputDirectory) {
        try mkdirRecurse(outputDirectory);
        catch (Exception error) return Result!BackendOutput.failure(error.msg);
        auto path = buildPath(outputDirectory, "program.openc-ir.json");
        try write(path, program.toJson().toPrettyString() ~ "\n");
        catch (Exception error) return Result!BackendOutput.failure(error.msg);
        BackendOutput output;
        output.files = [path];
        output.primarySource = path;
        return Result!BackendOutput.success(output);
    }
}
