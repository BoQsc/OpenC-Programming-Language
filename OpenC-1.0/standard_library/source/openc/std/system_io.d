module openc.std.system_io;

import openc.runtime.console : writeLine, writeStderr, writeStdout;
import openc.runtime.types : OpenCText, Status, i32, i64, u32, u64;
import std.conv : to;

Status print(OpenCText value) { return writeStdout(value); }
Status print(bool value) { return writeStdout(value ? "true" : "false"); }
Status print(i32 value) { return writeStdout(value.to!string); }
Status print(i64 value) { return writeStdout(value.to!string); }
Status print(u32 value) { return writeStdout(value.to!string); }
Status print(u64 value) { return writeStdout(value.to!string); }
Status print(float value) { return writeStdout(value.to!string); }
Status print(double value) { return writeStdout(value.to!string); }

Status println(OpenCText value) { return writeLine(value); }
Status println(bool value) { return writeLine(value ? "true" : "false"); }
Status println(i32 value) { return writeLine(value.to!string); }
Status println(i64 value) { return writeLine(value.to!string); }
Status println(u32 value) { return writeLine(value.to!string); }
Status println(u64 value) { return writeLine(value.to!string); }
Status println(float value) { return writeLine(value.to!string); }
Status println(double value) { return writeLine(value.to!string); }

Status error(OpenCText value) { return writeStderr(value); }
