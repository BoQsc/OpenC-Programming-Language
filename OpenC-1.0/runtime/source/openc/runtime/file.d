module openc.runtime.file;

import openc.runtime.types : OpenCByte, OpenCText, Status, i32, usize;
import core.stdc.stdio : FILE, fclose, fopen, fread, fwrite, fflush, fseek, ftell, SEEK_END, SEEK_SET;
import std.string : toStringz;

struct FileHandle {
    FILE* native;
    bool open;
}

Status openRead(OpenCText path, out FileHandle handle) {
    auto file = fopen(path.toStringz, "rb");
    if (file is null) return Status.failure(2, "cannot open file for reading");
    handle = FileHandle(file, true);
    return Status.success();
}

Status openWrite(OpenCText path, out FileHandle handle) {
    auto file = fopen(path.toStringz, "wb");
    if (file is null) return Status.failure(3, "cannot open file for writing");
    handle = FileHandle(file, true);
    return Status.success();
}

void close(ref FileHandle handle) {
    if (handle.open && handle.native !is null) {
        fclose(handle.native);
        handle.native = null;
        handle.open = false;
    }
}

Status size(ref FileHandle handle, out usize value) {
    if (!handle.open || handle.native is null) return Status.failure(4, "file handle is closed");
    auto original = ftell(handle.native);
    if (original < 0 || fseek(handle.native, 0, SEEK_END) != 0) return Status.failure(5, "cannot seek file");
    auto end = ftell(handle.native);
    fseek(handle.native, original, SEEK_SET);
    if (end < 0) return Status.failure(5, "cannot determine file size");
    value = cast(usize) end;
    return Status.success();
}

Status read(ref FileHandle handle, OpenCByte[] buffer, out usize count) {
    if (!handle.open || handle.native is null) return Status.failure(4, "file handle is closed");
    count = fread(buffer.ptr, 1, buffer.length, handle.native);
    return Status.success();
}

Status writeBytes(ref FileHandle handle, const(OpenCByte)[] buffer, out usize count) {
    if (!handle.open || handle.native is null) return Status.failure(4, "file handle is closed");
    count = fwrite(buffer.ptr, 1, buffer.length, handle.native);
    if (count != buffer.length) return Status.failure(6, "short file write");
    return Status.success();
}

Status flush(ref FileHandle handle) {
    if (!handle.open || handle.native is null) return Status.failure(4, "file handle is closed");
    return fflush(handle.native) == 0 ? Status.success() : Status.failure(7, "file flush failed");
}
