"""Race the first native SHA resolver call and compare every digest with Python."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import ctypes
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import threading

from benchmark_sh27_production import MIB, ROOT, sha256
from windows_process_measure import run_measured

SOURCE = """unsafe bool cli_cache_sha256_runtime(ptr byte data, usize length, ptr byte digest) {
    return false;
}
export unsafe i32 hash_bytes(ptr byte data, usize length, ptr byte digest) {
    if cli_cache_sha256_runtime(data, length, digest) { return 1; }
    return 0;
}
i32 main() { return 0; }
"""


def worker(path: Path) -> int:
    library = ctypes.WinDLL(str(path.resolve()))
    library.hash_bytes.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p]
    library.hash_bytes.restype = ctypes.c_int32
    barrier = threading.Barrier(16)

    def query(ordinal: int) -> bool:
        payloads = [bytes((i * 29 + ordinal) & 255 for i in range(length))
                    for length in (0, 1, 55, 56, 63, 64, 65, 4095, 4096, 65536)]
        barrier.wait(timeout=15)
        for repeat in range(8):
            for payload in payloads:
                source = ctypes.create_string_buffer(payload)
                result = ctypes.create_string_buffer(32)
                if library.hash_bytes(source, len(payload), result) != 1:
                    return False
                if result.raw != hashlib.sha256(payload).digest():
                    return False
        return True

    with ThreadPoolExecutor(max_workers=16) as pool:
        passed = all(pool.map(query, range(16)))
    print(json.dumps({"passed": passed, "threads": 16, "hashes": 1280}))
    return 0 if passed else 1


def main() -> int:
    if len(sys.argv) > 2 and sys.argv[1] == "--worker":
        return worker(Path(sys.argv[2]))
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("compiler", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    report = {"schema": "openc.sh27.hash_context.v1", "status": "FAIL",
              "compiler_sha256": sha256(compiler), "builds": [], "races": []}
    try:
        with tempfile.TemporaryDirectory(prefix="hc-", dir=ROOT / "build-output") as temporary:
            root = Path(temporary)
            (root / "main.p").write_text(SOURCE, encoding="utf-8")
            project = root / "openc.project.json"
            project.write_text(json.dumps({"name": "hash-context", "version": "1.0.0",
                "edition": "OpenC 1.0", "profile": "standard", "target": "windows-x86_64",
                "modules": {"hash_context": ["main.p"]}}), encoding="utf-8")

            def guarded(command: list[str]) -> dict:
                sample = run_measured(command, cwd=root, sample_interval=0.01,
                    max_private_bytes=256 * MIB, max_working_set_bytes=64 * MIB,
                    max_captured_output_bytes=MIB, timeout_seconds=120)
                assert sample["exit_code"] == 0 and not sample["memory_limit_exceeded"] and not sample["timed_out"], sample
                assert not sample["stdout_truncated"] and not sample["stderr_truncated"]
                return sample

            for chunks in (1,):
                library = root / f"hash{chunks}.dll"
                report["builds"].append(guarded([str(compiler), "artifact", f"--project={project}",
                    "--kind=dll", f"--output={library}", "--dll-name=hash.dll",
                    f"--source-chunks={chunks}"]))
                for repeat in range(3):
                    report["races"].append(guarded([sys.executable, str(Path(__file__).resolve()),
                                                   "--worker", str(library)]))
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
