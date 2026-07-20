module openc.runtime.platform;

import openc.runtime.types : OpenCText, usize;

version (Windows) {
    enum platformOS = "windows";
} else version (linux) {
    enum platformOS = "linux";
} else {
    enum platformOS = "freestanding";
}

enum platformArch = size_t.sizeof == 8 ? "x86_64-or-aarch64" : "unknown";
enum pointerWidth = size_t.sizeof * 8;
