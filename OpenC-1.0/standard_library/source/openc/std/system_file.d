module openc.std.system_file;

import openc.runtime.file : FileHandle, close, flush, openRead, openWrite, read, size, writeBytes;
import openc.runtime.memory : opencAlloc, opencFree;
import openc.runtime.types : OpenCByte, OpenCText, Status, usize;
import std.utf : UTFException, validate;

struct File {
private:
    FileHandle handle;

public:
    @disable this(this);

    @property bool open() const nothrow {
        return handle.open;
    }
}

Status open_read(OpenCText path, out File file) {
    FileHandle handle;
    auto result = openRead(path, handle);
    if (!result.ok) return result;
    file.handle = handle;
    return Status.success();
}

Status open_write(OpenCText path, out File file) {
    FileHandle handle;
    auto result = openWrite(path, handle);
    if (!result.ok) return result;
    file.handle = handle;
    return Status.success();
}

void close_file(ref File file) {
    close(file.handle);
}

Status length(ref File file, out usize value) {
    return size(file.handle, value);
}

Status read_bytes(ref File file, OpenCByte[] buffer, out usize count) {
    return read(file.handle, buffer, count);
}

Status write_bytes(ref File file, const(OpenCByte)[] buffer, out usize count) {
    return writeBytes(file.handle, buffer, count);
}

Status flush_file(ref File file) {
    return flush(file.handle);
}

Status read_all_bytes(ref File file, out OpenCByte[] bytes) {
    usize count;
    auto sizeResult = length(file, count);
    if (!sizeResult.ok) return sizeResult;
    bytes = new OpenCByte[count];
    usize readCount;
    auto readResult = read_bytes(file, bytes, readCount);
    if (!readResult.ok) return readResult;
    if (readCount != count) bytes.length = readCount;
    return Status.success();
}

Status read_text(ref File file, out OpenCText text) {
    OpenCByte[] bytes;
    auto result = read_all_bytes(file, bytes);
    if (!result.ok) return result;
    auto candidate = cast(string) bytes;
    try {
        validate(candidate);
    } catch (UTFException) {
        return Status.failure(8, "file is not valid UTF-8 text");
    }
    text = candidate.idup;
    return Status.success();
}
