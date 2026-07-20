module openc.backend;

import openc.common : Result, TargetContext;
import openc.ir : IrProgram;
import openc.semantic_model : SemanticModel;
import openc.source : SourceManager;

struct BackendOutput {
    string[] files;
    string primarySource;
    string entryObject;
    string executable;
}

interface Backend {
    string name() const;
    string description() const;
    Result!BackendOutput emit(IrProgram program, SemanticModel model, SourceManager sources, string outputDirectory);
}
