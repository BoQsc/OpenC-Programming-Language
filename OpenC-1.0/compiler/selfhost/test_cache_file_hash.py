"""Verify bounded mapped-file SHA, resource cleanup, and unavailable-API fallback."""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile

from benchmark_sh27_production import MIB, ROOT, sha256
from windows_process_measure import run_measured

SOURCE = """import system.text;
unsafe bool cli_cache_file_sha256_runtime(text path, usize limit, ptr byte digest) {
    return false;
}
export unsafe i32 hash_file(ptr byte path, usize length, usize limit, ptr byte digest) {
    if cli_cache_file_sha256_runtime(text.from_utf8(path, length), limit, digest) { return 1; }
    return 0;
}
i32 main() { return 0; }
"""


def worker(library_path: Path, root: Path, available: bool) -> int:
    library = ctypes.WinDLL(str(library_path.resolve()))
    library.hash_file.argtypes = [ctypes.c_void_p, ctypes.c_size_t,
                                  ctypes.c_size_t, ctypes.c_void_p]
    library.hash_file.restype = ctypes.c_int32
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.GetCurrentProcess.restype = ctypes.c_void_p
    kernel.GetProcessHandleCount.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32)]
    kernel.CreateFileW.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32,
                                  ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p]
    kernel.CreateFileW.restype = ctypes.c_void_p
    kernel.CloseHandle.argtypes = [ctypes.c_void_p]

    def handles() -> int:
        count = ctypes.c_uint32()
        assert kernel.GetProcessHandleCount(kernel.GetCurrentProcess(), ctypes.byref(count))
        return count.value

    calls = 0

    def query(path: Path, limit: int, succeeds: bool) -> None:
        nonlocal calls
        encoded = str(path).encode("utf-8")
        digest = ctypes.create_string_buffer(b"\xa5" * 32, 32)
        result = library.hash_file(encoded, len(encoded), limit, digest)
        assert result == int(available and succeeds), (path, limit, result)
        if result:
            assert digest.raw.hex() == sha256(path), path
        else:
            assert digest.raw == b"\xa5" * 32, path
        calls += 1

    # Warm optional DLL resolution before counting handles. Each file/mapping
    # reference must then be released on success and on every failure branch.
    query(root / "small.bin", 32 * MIB, True)
    before = handles()
    for name, limit, succeeds in (
        ("empty.bin", 32 * MIB, False), ("small.bin", 32 * MIB, True),
        ("unicode-\u00e9-\u0416.bin", 32 * MIB, True), ("missing.bin", 32 * MIB, False),
        ("small.bin", 62, False), ("small.bin", 63, True),
        ("limit.bin", 32 * MIB, True), ("oversize.bin", 32 * MIB, False),
        ("oversize.bin", 64 * MIB, False), ("small.bin", 0, False),
    ):
        query(root / name, limit, succeeds)
    query(root, 32 * MIB, False)
    for repeat in range(256):
        query(root / ("small.bin" if repeat % 2 == 0 else "missing.bin"), 32 * MIB, repeat % 2 == 0)
    writer = kernel.CreateFileW(str(root / "small.bin"), 0x40000000, 7, None, 3, 128, None)
    assert writer != ctypes.c_void_p(-1).value
    try:
        query(root / "small.bin", 32 * MIB, False)
    finally:
        assert kernel.CloseHandle(writer)
    assert handles() == before, (before, handles())
    print(json.dumps({"passed": True, "calls": calls, "handles_before": before,
                      "handles_after": handles(), "mapping_api_available": available}))
    return 0


def main() -> int:
    if len(sys.argv) > 2 and sys.argv[1] == "--worker":
        return worker(Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4] == "available")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("compiler", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    report = {"schema": "openc.sh27.cache_file_hash.v1", "status": "FAIL",
              "compiler_sha256": sha256(compiler), "builds": [], "workers": [], "fallbacks": {}}
    try:
        with tempfile.TemporaryDirectory(prefix="fh-", dir=ROOT / "build-output") as temporary:
            root = Path(temporary)
            (root / "main.p").write_text(SOURCE, encoding="utf-8")
            fixture = root / "openc.project.json"
            fixture.write_text(json.dumps({"name": "file-hash", "version": "1.0.0",
                "edition": "OpenC 1.0", "profile": "standard", "target": "windows-x86_64",
                "modules": {"file_hash": ["main.p"]}}), encoding="utf-8")
            (root / "empty.bin").write_bytes(b"")
            (root / "small.bin").write_bytes(bytes(range(63)))
            (root / "unicode-\u00e9-\u0416.bin").write_bytes(bytes(range(256)) * 32)
            with (root / "limit.bin").open("wb") as stream:
                for block in range(512):
                    stream.write(bytes([block % 251]) * 65536)
            with (root / "oversize.bin").open("wb") as stream:
                stream.truncate(32 * MIB + 1)

            def guarded(command: list[str]) -> dict:
                result = run_measured(command, cwd=root, sample_interval=0.01,
                    max_private_bytes=256 * MIB, max_working_set_bytes=64 * MIB,
                    max_captured_output_bytes=MIB, timeout_seconds=120)
                assert result["exit_code"] == 0 and not result["timed_out"] and not result["memory_limit_exceeded"], result
                assert not result["stdout_truncated"] and not result["stderr_truncated"], result
                return result

            def probe(tool: Path, label: str, available: bool) -> None:
                library = root / f"{label}.dll"
                report["builds"].append(guarded([str(tool), "artifact", f"--project={fixture}",
                    "--kind=dll", f"--output={library}", "--dll-name=file-hash.dll"]))
                report["workers"].append(guarded([sys.executable, str(Path(__file__).resolve()),
                    "--worker", str(library), str(root), "available" if available else "unavailable"]))

            probe(compiler, "mapped", True)
            canonical = ROOT / "compiler/selfhost"
            runtime = (canonical / "source/backend_native_cache.p").read_text(encoding="utf-8")
            for api in ("CreateFileMappingW", "MapViewOfFile", "UnmapViewOfFile"):
                fault = root / f"missing-{api}.p"
                assert runtime.count(f'"{api}"') == 1
                fault.write_text(runtime.replace(f'"{api}"', f'"OpenC_Missing_{api}"'), encoding="utf-8")
                data = json.loads((canonical / "openc.project.json").read_text())
                for module, files in data["modules"].items():
                    data["modules"][module] = [os.path.relpath(
                        fault if name == "source/backend_native_cache.p" else canonical / name,
                        root).replace(os.sep, "/") for name in files]
                for name in ("standard_library_directory", "runtime_directory"):
                    data[name] = str((canonical / data[name]).resolve(strict=True))
                data["output_directory"] = "build"
                project = root / f"{api}.json"
                project.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
                current = compiler
                hashes = []
                builds = []
                for generation in range(1, 4):
                    output = root / f"{api}-{generation}.exe"
                    builds.append(guarded([str(current), "build", f"--project={project}", f"--output={output}"]))
                    hashes.append(sha256(output))
                    current = output
                assert hashes[1] == hashes[2], (api, hashes)
                probe(current, api, False)
                target = root / f"{api}-cached.exe"
                timing = root / f"{api}-timing.json"
                for repeat in range(2):
                    builds.append(guarded([str(current), "build", f"--project={project}",
                        f"--output={target}", f"--timings={timing}"]))
                    assert sha256(target) == hashes[2]
                timings = json.loads(timing.read_text())
                assert timings["frontend_cache"]["predeclare_hits"] == sum(map(len, data["modules"].values()))
                assert timings["frontend_cache"]["resolution_hits"] == sum(map(len, data["modules"].values()))
                assert timings["object_cache"]["hits"] == 32
                report["fallbacks"][api] = {"builds": builds, "sha256": hashes[2],
                    "frontend_cache": timings["frontend_cache"], "object_cache": timings["object_cache"]}
                print(f"file mapping unavailable: {api} PASS", flush=True)
            report["status"] = "PASS"
    except Exception as error:
        report["error"] = repr(error)
    finally:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: report.get(k) for k in ("status", "error")}, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
