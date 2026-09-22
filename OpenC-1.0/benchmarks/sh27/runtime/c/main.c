#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

int main(void) {
    for (size_t iteration = 0; iteration < 64; ++iteration) {
        uint64_t *block = (uint64_t *)malloc(4096);
        if (block == NULL) return 1;
        for (size_t offset = 0; offset < 4096; offset += 8) {
            block[offset / 8] = (uint64_t)(iteration + offset);
        }

        FILE *output = fopen("sh27-runtime-payload.bin", "wb");
        if (output == NULL) { free(block); return 2; }
        size_t written = fwrite(block, 1, 4096, output);
        if (fclose(output) != 0 || written != 4096) { free(block); return 2; }

        uint64_t *observed = (uint64_t *)malloc(4096);
        if (observed == NULL) { free(block); return 3; }
        FILE *input = fopen("sh27-runtime-payload.bin", "rb");
        if (input == NULL) { free(observed); free(block); return 3; }
        size_t read = fread(observed, 1, 4096, input);
        if (fclose(input) != 0 || read != 4096) {
            free(observed); free(block); return 3;
        }
        for (size_t offset = 0; offset < 4096; offset += 8) {
            if (observed[offset / 8] != (uint64_t)(iteration + offset)) {
                free(observed); free(block); return 5;
            }
        }
        free(observed);
        free(block);
    }
    puts("SH27_RUNTIME_OK");
    return 0;
}
