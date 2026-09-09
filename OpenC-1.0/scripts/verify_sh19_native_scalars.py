#!/usr/bin/env python3
"""Exercise SH-19 scalar/reference/aggregate IR; not the full SH-19 exit gate."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile

from verify_sh18_windows_modules import pe_imports

ROOT = Path(__file__).resolve().parents[1]


def run(command: list[str], cwd: Path = ROOT) -> subprocess.CompletedProcess[str]:
    environment = dict(os.environ)
    environment["PATH"] = str(Path(os.environ["SystemRoot"]) / "System32")
    return subprocess.run(command, cwd=cwd, env=environment, capture_output=True,
                          text=True, encoding="utf-8", errors="replace", timeout=30)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    compiler = args.compiler.resolve()
    checks: dict[str, bool] = {}
    observations = {}
    # Windows scanners can retain an executable briefly after it exits. Do not
    # discard the test report because cleanup of our temporary fixture is locked.
    with tempfile.TemporaryDirectory(prefix="openc-sh19-scalars-", ignore_cleanup_errors=True) as temporary:
        work = Path(temporary)
        binary = work / "scalars.exe"
        project = ROOT / "tests/sh19_native_scalars/openc.project.json"
        built = run([str(compiler), "--native-build", str(project), str(binary)], work)
        checks["general_project_native_build"] = built.returncode == 0 and binary.is_file()
        observations["build_stderr"] = built.stderr
        if binary.is_file():
            first = binary.read_bytes()
            executed = run([str(binary)], work)
            checks["recursion_loops_and_six_argument_abi"] = executed.returncode == 0
            observations["scalar_exit"] = executed.returncode
            checks["system_dlls_only"] = pe_imports(binary) == {"kernel32.dll"}
            pe = struct.unpack_from("<I", first, 0x3C)[0]
            optional = pe + 24
            pdata_rva, pdata_size = struct.unpack_from("<II", first, optional + 112 + 3 * 8)
            checks["unwind_for_startup_failure_and_five_functions"] = pdata_rva != 0 and pdata_size == 84
            second = work / "scalars-again.exe"
            repeated = run([str(compiler), "--native-build", str(project), str(second)], work)
            checks["deterministic_pe_bytes"] = repeated.returncode == 0 and second.read_bytes() == first
            observations["executable_sha256"] = hashlib.sha256(first).hexdigest()
            observations["executable_bytes"] = len(first)
        else:
            for name in ("recursion_loops_and_six_argument_abi", "system_dlls_only",
                         "unwind_for_startup_failure_and_five_functions", "deterministic_pe_bytes"):
                checks[name] = False
        probes = {
            "pointer_read_write": ("unsafe i32 main() { i32 x = 9; ptr i32 p = &x; *p = -7; return *p + 7; }", 0),
            "pointer_byte": ("unsafe i32 main() { u8 x = 255; ptr u8 p = &x; *p = 128; return cast(i32, *p) - 128; }", 0),
            "invalid_out_nonstatus": ("void assign(out i32 value) { value = 37; } i32 main() { i32 x; assign(out x); return x - 37; }", None),
            "invalid_reference_deref": ("unsafe void increment(ref i32 value) { *value = *value + 1; } unsafe i32 main() { i32 x = 10; increment(x); return x - 11; }", None),
            "aggregate_fields": ("struct Pair { u8 tag; i32 value; } i32 main() { Pair a = Pair{ tag = 255, value = -7 }; Pair b = a; b.tag = 2; b.value = 9; if a.tag != 255 || a.value != -7 { return 1; } return b.value - 9; }", 0),
            "aggregate_ref": ("struct Counter { i32 value; } void increment(ref Counter c) { c.value = c.value + 1; } i32 main() { Counter c = Counter{ value = 10 }; increment(c); return c.value - 11; }", 0),
            "aggregate_nested": ("struct Inner { u8 tag; i32 value; } struct Outer { u8 first; Inner inner; u16 last; } i32 main() { Outer x = Outer{ first = 1, inner = Inner{ tag = 2, value = -3 }, last = 65535 }; Outer y = x; y.inner.value = 4; if x.inner.value != -3 || y.last != 65535 { return 1; } return y.inner.value - 4; }", 0),
            "aggregate_pointer": ("struct Pair { u8 a; u8 b; i32 c; } unsafe i32 main() { Pair x = Pair{ a = 1, b = 2, c = 3 }; ptr Pair p = &x; Pair y = *p; if y.a != 1 || y.b != 2 { return 1; } return y.c - 3; }", 0),
            "aggregate_pointer_store": ("struct Pair { u8 a; i32 b; } unsafe i32 main() { Pair x = Pair{ a = 1, b = 2 }; ptr Pair p = &x; *p = Pair{ a = 255, b = -7 }; if x.a != 255 { return 1; } return x.b + 7; }", 0),
            "aggregate_field_replace": ("struct Inner { u8 a; i32 b; } struct Outer { u8 before; Inner inner; u8 after; } i32 main() { Outer x = Outer{ before = 1, inner = Inner{ a = 2, b = 3 }, after = 4 }; x.inner = Inner{ a = 255, b = -7 }; if x.before != 1 || x.after != 4 || x.inner.a != 255 { return 1; } return x.inner.b + 7; }", 0),
            "aggregate_by_value": ("struct Pair { i32 a; i32 b; } Pair echo(Pair x) { x.a = x.a + 3; return x; } i32 main() { Pair a = Pair{ a = 1, b = 2 }; Pair x = echo(a); if a.a != 1 || x.b != 2 { return 1; } return x.a - 4; }", 0),
            "aggregate_hidden_return": ("struct Big { i64 a; i64 b; i64 c; } Big change(Big x, i32 a, i32 b, i32 c, i32 d) { x.b = cast(i64, a + b + c + d); return x; } i32 main() { Big x = Big{ a = 1, b = 2, c = 3 }; Big y = change(x, 4, 5, 6, 7); if x.b != 2 || y.a != 1 || y.c != 3 { return 1; } return cast(i32, y.b) - 22; }", 0),
            "status_out_success": ('status make(out i32 x) { x = 37; return status{ code = 0, message = "" }; } i32 main() { i32 x; status s = make(out x); if s.ok { return x - 37; } return 1; }', 0),
            "status_failure": ('status fail() { return status{ code = -9 }; } i32 main() { status s = fail(); if s.ok { return 1; } return s.code + 9; }', 0),
            "status_copy": ('status echo(status s) { return s; } i32 main() { status s = echo(status{ code = 7, message = "" }); status t = s; if t.ok { return 1; } return t.code - 7; }', 0),
            "three_byte_recursive_return": ('struct Triple { u8 a; u8 b; u8 c; } Triple step(Triple t, i32 n) { if n == 0 { return t; } t.a = t.a + 1; return step(t, n - 1); } i32 main() { Triple a = Triple{ a = 1, b = 2, c = 3 }; Triple b = step(a, 5); if a.a != 1 || b.b != 2 || b.c != 3 { return 1; } return cast(i32, b.a) - 6; }', 0),
            "small_aggregate_registers": ('struct A { u8 x; } struct B { u16 x; } struct C { i32 x; } A fa(A a) { return a; } B fb(B b) { return b; } C fc(C c) { return c; } i32 main() { A a = fa(A{ x = 255 }); B b = fb(B{ x = 65535 }); C c = fc(C{ x = -7 }); if a.x != 255 || b.x != 65535 { return 1; } return c.x + 7; }', 0),
            "multiple_indirect_arguments": ('struct Big { i64 a; i64 b; i64 c; } Big merge(Big a, Big b, Big c, Big d, Big e) { a.b = b.a + c.a + d.a + e.a; return a; } i32 main() { Big x = Big{ a = 3, b = 4, c = 5 }; Big y = merge(x, x, x, x, x); if x.b != 4 || y.a != 3 || y.c != 5 { return 1; } return cast(i32, y.b) - 12; }', 0),
            "status_nonempty_message": ('status fail() { return status{ code = 1, message = "native message" }; } i32 main() { status s = fail(); if s.message != "native message" { return 1; } return s.code - 1; }', 0),
            "text_constants": ('import system.text; text make() { return "a\\0b\\n\\u{1F600}"; } i32 main() { text x = make(); if text.byte_length(x) != 8 { return 1; } if x != "a\\0b\\n😀" || x == "a" || x == "a\\0c\\n😀" { return 2; } if "" != "" { return 3; } return 0; }', 0),
            "array_copy": ('i32 main() { i32[3] a = {1,2,3}; i32[3] b = a; b[1] = 9; if a[1] != 2 || b.length != 3 { return 1; } return b[1] - 9; }', 0),
            "slice_mutation": ('i32 main() { i32[4] a = {1,2,3,4}; i32[] s = a[1..3]; s[0] = 9; if s.length != 2 || a[1] != 9 { return 1; } return s[1] - 3; }', 0),
            "array_bounds": ('i32 get(usize i) { i32[2] a = {1,2}; return a[i]; } i32 main() { return get(2); }', 70),
            "slice_implicit": ('i32 main() { i32[2] a = {1,2}; i32[] s = a; s[0] = 7; return a[0] - 7; }', 0),
            "slice_call": ('i32 sum(i32[] s) { i32 total = 0; usize i = 0; while i < s.length { total = total + s[i]; i = i + 1; } return total; } i32 main() { i32[3] a = {1,2,3}; return sum(a) - 6; }', 0),
            "slice_bad_range": ('i32 take(usize end) { i32[2] a = {1,2}; i32[] s = a[0..end]; return cast(i32, s.length); } i32 main() { return take(3); }', 70),
            "slice_empty": ('i32 main() { i32[2] a = {1,2}; i32[] s = a[2..2]; return cast(i32, s.length); }', 0),
            "optional_value": ('struct P { i32 x; } i32 main() { optional P p = P{ x = 7 }; optional P q = p; if q.present { return q.value.x - 7; } return 1; }', 0),
            "optional_none": ('i32 main() { optional i32 x = none; if x.present { return 1; } return 0; }', 0),
            "enum_switch": ('enum Choice { a, b } i32 choose(Choice c) { switch c { case Choice.a { return 1; } case Choice.b { return 2; } } } i32 main() { return choose(Choice.b) - 2; }', 0),
            "saturating_unsigned": ('i32 main() { u8 a = saturating_add(cast(u8, 250), cast(u8, 20)); u8 b = saturating_sub(cast(u8, 3), cast(u8, 5)); u8 c = saturating_mul(cast(u8, 20), cast(u8, 20)); if a != 255 || b != 0 || c != 255 { return 1; } return 0; }', 0),
            "saturating_signed": ('i32 main() { i8 a = saturating_add(cast(i8, 120), cast(i8, 20)); i8 b = saturating_sub(cast(i8, -120), cast(i8, 20)); i8 c = saturating_mul(cast(i8, 50), cast(i8, 5)); i8 d = saturating_mul(cast(i8, -50), cast(i8, 5)); if a != 127 || b != -128 || c != 127 || d != -128 { return 1; } return 0; }', 0),
            "float_abi_arithmetic": ('f64 twice(f64 value) { return value * 2.0; } f32 half(f32 value) { return value / cast(f32, 2.0); } i32 main() { if twice(1.5) != 3.0 { return 1; } if half(cast(f32, 3.0)) != cast(f32, 1.5) { return 2; } return 0; }', 0),
            "float_reinterpret": ('i32 main() { u32 bits = 0x3f800000; unsafe { f32 value = reinterpret(f32, bits); if value == 1.0 { return 0; } } return 1; }', 0),
            "float_nan_comparisons": ('i32 main() { f64 nan = 0.0 / 0.0; if nan == nan || nan < 1.0 || nan <= 1.0 || nan > 1.0 || nan >= 1.0 { return 1; } if nan != nan { return 0; } return 2; }', 0),
            "integer_console": ('import system.io; i32 main() { i8 low = -128; u64 high = 18446744073709551615; io.print(low); io.print(high); return 0; }', 0),
            "text_trim": ('import system.text; i32 main() { text value = text.trim(" hello "); if value == "hello" { return 0; } return 1; }', 0),
            "scope_lifo": ('import system.io; void show(text s) { io.print(s); } i32 main() { scope show("outer"); scope show("middle"); scope show("inner"); return 0; }', 0),
            "scope_owned_resource": ('import system.io; resource R { i32 id; } void finish(own R r) { if r.id == 7 { io.print("owned"); } } i32 main() { R r = R{ id = 7 }; scope finish(r); return 0; }', 0),
            "large_stack": ("i32 many(i32 a, i32 b, i32 c, i32 d, i32 e) { "
                + " ".join(f"i32 local_{i} = {i};" for i in range(600))
                + " return local_599 + a + b + c + d + e; } "
                + "i32 main() { return many(1, 2, 3, 4, 5) - 614; }", 0),
            "u64_maximum": ("i32 main() { u64 x = 0xffffffffffffffff; "
                "if x / cast(u64, 3) != 6148914691236517205 { return 1; } return 0; }", 0),
            "overflow": ("i32 main() { i32 x = 2147483647; return x + 1; }", 70),
            "underflow": ("i32 main() { i32 x = 0 - 2147483647; return x - 2; }", 70),
            "multiply_overflow": ("i32 main() { i32 x = 2147483647; return x * 2; }", 70),
            "divide_zero": ("i32 divide(i32 x) { return 5 / x; } i32 main() { return divide(0); }", 70),
            "negative_to_unsigned": ("i32 main() { i32 x = -1; u64 y = cast(u64, x); return cast(i32, y); }", 70),
            "narrow_cast": ("i32 main() { i32 x = 256; u8 y = cast(u8, x); return cast(i32, y); }", 70),
            "console_text": ('import system.io; i32 main() { io.println("OpenC native 😀"); io.error("stderr"); return 0; }', 0),
            "heap_allocation": ('import system.memory; unsafe i32 main() { ptr byte p = memory.alloc(16); *(p + 7) = cast(byte, 123); i32 value = cast(i32, *(p + 7)); memory.free(p); return value - 123; }', 0),
            "heap_single_allocation_budget": ('import system.memory; unsafe i32 main() { ptr byte p = memory.alloc(268435457); memory.free(p); return 0; }', 70),
            "scope_heap_reclamation": ('import system.memory; unsafe void once() { ptr byte p = memory.alloc(67108864); scope memory.free(p); *(p + 7) = cast(byte, 1); } unsafe i32 main() { usize i = 0; while i < 10 { once(); i = i + 1; } return 0; }', 0),
            "invalid_syntax": ("i32 main() { if true ) { return 0; } }", None),
        }
        for name, (source, expected) in probes.items():
            directory = work / name
            directory.mkdir()
            (directory / "main.p").write_text(source, encoding="utf-8")
            manifest = directory / "openc.project.json"
            manifest.write_text(json.dumps({"name": name, "edition": "OpenC 1.0",
                "version": "0.1.0", "profile": "standard", "target": "windows-x86_64",
                "modules": {"probe": ["main.p"]}}), encoding="utf-8")
            output = directory / "probe.exe"
            outcome = run([str(compiler), "--native-build", str(manifest), str(output)], work)
            execution_exit = None
            if expected is None:
                checks[name + "_rejected_without_artifact"] = outcome.returncode != 0 and not output.exists()
            else:
                if outcome.returncode == 0 and output.exists():
                    executed_probe = run([str(output)], work)
                    execution_exit = executed_probe.returncode
                    if name == "console_text":
                        checks["console_utf8_exact"] = executed_probe.stdout == "OpenC native 😀\n" and executed_probe.stderr == "stderr"
                    if name == "scope_lifo":
                        checks["scope_cleanup_lifo_exact"] = executed_probe.stdout == "innermiddleouter"
                    if name == "scope_owned_resource":
                        checks["scope_owned_resource_exact"] = executed_probe.stdout == "owned"
                    if name == "integer_console":
                        checks["integer_console_exact"] = executed_probe.stdout == "-12818446744073709551615"
                    if name == "heap_single_allocation_budget":
                        checks["heap_single_allocation_budget_diagnostic"] = (
                            "fatal[OPENC-NATIVE-ALLOC-BUDGET]: one allocation exceeds 256 MiB"
                            in executed_probe.stderr
                        )
                checks[name + f"_exits_{expected}"] = execution_exit == expected
            observations[name] = {"compile_exit": outcome.returncode, "stderr": outcome.stderr}
            if execution_exit is not None:
                observations[name]["execution_exit"] = execution_exit
            if expected is not None and (outcome.returncode != 0 or execution_exit != expected):
                diagnostic = run([str(compiler), "check", f"--project={manifest}"], work)
                observations[name]["check_output"] = diagnostic.stdout + diagnostic.stderr
                diagnostic = run([str(compiler), "--semantic-ir", str(manifest)], work)
                observations[name]["semantic_ir"] = diagnostic.stdout + diagnostic.stderr
        checks["no_generated_c_or_objects"] = not any(
            p.suffix.lower() in {".c", ".obj", ".o", ".rsp"} for p in work.rglob("*"))
    if work.exists():
        observations["temporary_directory_retained"] = str(work)
    result = {"schema": "openc.sh19_native_scalars.v1",
              "status": "PASS" if all(checks.values()) else "FAIL",
              "sh19_complete": False, "checks": checks, "observations": observations}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"SH-19 native lowering: {result['status']}; {sum(checks.values())}/{len(checks)}")
    return 0 if all(checks.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
