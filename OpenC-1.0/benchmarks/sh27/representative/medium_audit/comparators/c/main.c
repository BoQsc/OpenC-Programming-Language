/* C17 counterpart of the checked-in OpenC file-audit application. */
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <io.h>

static unsigned char *read_input(size_t *length) {
    FILE *stream = fopen("sample.log", "rb");
    if (stream == NULL) return NULL;
    if (fseek(stream, 0, SEEK_END) != 0) { fclose(stream); return NULL; }
    long end = ftell(stream);
    if (end < 0 || fseek(stream, 0, SEEK_SET) != 0) {
        fclose(stream);
        return NULL;
    }
    *length = (size_t)end;
    unsigned char *data = (unsigned char *)malloc(*length + 1);
    if (data == NULL || fread(data, 1, *length, stream) != *length) {
        free(data);
        fclose(stream);
        return NULL;
    }
    fclose(stream);
    return data;
}

int main(void) {
    size_t length = 0;
    unsigned char *data = read_input(&length);
    if (data == NULL) return 2;

    size_t lines = 0;
    size_t digits = 0;
    size_t warnings = 0;
    size_t hash = 0;
    for (size_t index = 0; index < length; ++index) {
        unsigned char value = data[index];
        if (value == 10) ++lines;
        if (value >= 48 && value <= 57) ++digits;
        hash = (hash * 31 + (size_t)value) % 65521;
        if (index + 4 <= length &&
            data[index] == 87 && data[index + 1] == 65 &&
            data[index + 2] == 82 && data[index + 3] == 78) {
            ++warnings;
        }
    }
    if (length != 0 && data[length - 1] != 10) ++lines;
    free(data);
    if (_setmode(_fileno(stdout), _O_BINARY) == -1) return 3;
    printf("lines=%zu\ndigits=%zu\nwarnings=%zu\nfingerprint=%zu\n",
           lines, digits, warnings, hash);
    return 0;
}
