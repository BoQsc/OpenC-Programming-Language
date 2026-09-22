import core.stdc.stdio : FILE, fopen, fclose, fread, fwrite, puts;
import core.stdc.stdlib : malloc, free;

int main() {
    foreach (size_t iteration; 0 .. 64) {
        ulong* block = cast(ulong*) malloc(4096);
        if (block is null) return 1;
        foreach (size_t offset; 0 .. 512) {
            block[offset] = cast(ulong)(iteration + offset * 8);
        }

        FILE* output = fopen("sh27-runtime-payload.bin", "wb");
        if (output is null) { free(block); return 2; }
        size_t written = fwrite(block, 1, 4096, output);
        if (fclose(output) != 0 || written != 4096) {
            free(block); return 2;
        }

        ulong* observed = cast(ulong*) malloc(4096);
        if (observed is null) { free(block); return 3; }
        FILE* input = fopen("sh27-runtime-payload.bin", "rb");
        if (input is null) { free(observed); free(block); return 3; }
        size_t read = fread(observed, 1, 4096, input);
        if (fclose(input) != 0 || read != 4096) {
            free(observed); free(block); return 3;
        }
        foreach (size_t offset; 0 .. 512) {
            if (observed[offset] != cast(ulong)(iteration + offset * 8)) {
                free(observed); free(block); return 5;
            }
        }
        free(observed);
        free(block);
    }
    puts("SH27_RUNTIME_OK");
    return 0;
}
