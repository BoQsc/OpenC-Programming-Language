module apps.lsp_main;

import openc.compiler : Compiler;
import openc.tools.lsp : LanguageServer;

int main(string[] argv) {
    return new LanguageServer(new Compiler()).run();
}
