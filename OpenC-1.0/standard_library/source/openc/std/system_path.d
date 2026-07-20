module openc.std.system_path;

import openc.runtime.types : OpenCText;
import std.array : appender;
import std.path : baseName, buildNormalizedPath, dirName, extension, isAbsolute, setExtension;

OpenCText join(OpenCText left, OpenCText right) {
    return buildNormalizedPath(left, right).idup;
}

OpenCText normalize(OpenCText value) {
    return buildNormalizedPath(value).idup;
}

OpenCText directory(OpenCText value) {
    return dirName(value).idup;
}

OpenCText name(OpenCText value) {
    return baseName(value).idup;
}

OpenCText suffix(OpenCText value) {
    return extension(value).idup;
}

OpenCText with_suffix(OpenCText value, OpenCText suffixValue) {
    return setExtension(value, suffixValue).idup;
}

bool absolute(OpenCText value) {
    return isAbsolute(value);
}
