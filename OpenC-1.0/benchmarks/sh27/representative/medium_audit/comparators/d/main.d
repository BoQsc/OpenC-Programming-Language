// D counterpart of the checked-in OpenC file-audit application.
module sh27_representative_audit;

import std.file : read;
import std.format : format;
import std.stdio : stdout;

int main() {
    ubyte[] data;
    try {
        data = cast(ubyte[]) read("sample.log");
    } catch (Exception) {
        return 2;
    }

    size_t lines = 0;
    size_t digits = 0;
    size_t warnings = 0;
    size_t hash = 0;
    foreach (index, value; data) {
        if (value == 10) ++lines;
        if (value >= 48 && value <= 57) ++digits;
        hash = (hash * 31 + cast(size_t)value) % 65521;
        if (index + 4 <= data.length &&
            data[index] == 87 && data[index + 1] == 65 &&
            data[index + 2] == 82 && data[index + 3] == 78) {
            ++warnings;
        }
    }
    if (data.length != 0 && data[$ - 1] != 10) ++lines;
    stdout.rawWrite(format(
        "lines=%s\ndigits=%s\nwarnings=%s\nfingerprint=%s\n",
        lines, digits, warnings, hash
    ));
    return 0;
}
