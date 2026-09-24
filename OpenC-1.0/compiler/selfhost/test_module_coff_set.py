"""Executable two-module COFF boundary probe; system linker is test oracle only.

Usage: python test_module_coff_set.py path/to/openc.exe
"""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile


ALPHA = "export i32 add(i32 left, i32 right) { return left + right; }\n"
BETA = "import alpha;\ni32 main() { return alpha.add(3, 4); }\n"


def coff_symbols(data: bytes) -> dict[str, tuple[int, int]]:
    assert struct.unpack_from("<H", data)[0] == 0x8664
    table, count = struct.unpack_from("<II", data, 8)
    strings = table + count * 18
    result: dict[str, tuple[int, int]] = {}
    index = 0
    while index < count:
        at = table + index * 18
        raw = data[at : at + 8]
        if raw[:4] == b"\0" * 4:
            offset = struct.unpack_from("<I", raw, 4)[0]
            end = data.index(0, strings + offset)
            name = data[strings + offset : end].decode("ascii")
        else:
            name = raw.rstrip(b"\0").decode("ascii")
        section = struct.unpack_from("<h", data, at + 12)[0]
        result[name] = (section, data[at + 16])
        index += 1 + data[at + 17]
    return result


def build(
    compiler: Path,
    root: Path,
    *,
    alpha: str = ALPHA,
    reverse_manifest: bool = False,
) -> tuple[dict[str, bytes], dict]:
    root.mkdir()
    (root / "alpha.p").write_text(alpha, encoding="utf-8")
    (root / "beta.p").write_text(BETA, encoding="utf-8")
    modules = {"alpha": ["alpha.p"], "beta": ["beta.p"]}
    if reverse_manifest:
        modules = {"beta": ["beta.p"], "alpha": ["alpha.p"]}
    project = {
        "name": "module-coff-probe", "version": "0.1.0",
        "edition": "OpenC 1.0", "profile": "standard",
        "target": "windows-x86_64", "modules": modules,
    }
    project_path = root / "openc.project.json"
    project_path.write_text(json.dumps(project), encoding="utf-8")
    prefix = root / "bundle"
    run = subprocess.run(
        [str(compiler), "artifact", f"--project={project_path}",
         "--kind=module-coff-set", f"--output={prefix}"],
        capture_output=True, text=True, timeout=30,
    )
    assert run.returncode == 0, f"module COFF: {run.stdout}\n{run.stderr}"
    manifest = json.loads((root / "bundle.modules.json").read_text(encoding="utf-8"))
    assert manifest["schema"] == "openc.module_coff_set.v1"
    assert manifest["status"] == "COMPLETE"
    assert [entry["module"] for entry in manifest["modules"]] == ["alpha", "beta"]
    objects = {}
    for entry in manifest["modules"]:
        payload = Path(entry["object"]).read_bytes()
        assert hashlib.sha256(payload).hexdigest() == entry["sha256"]
        objects[entry["module"]] = payload
    return objects, manifest


def link_and_run(root: Path, manifest: dict, objects: dict[str, bytes], expected: int) -> None:
    linker = shutil.which("lld-link")
    assert linker, "lld-link test oracle unavailable"
    import_library = Path(
        os.environ.get(
            "OPENC_TEST_KERNEL32_LIB",
            "C:/D/dmd2/windows/lib64/mingw/kernel32.lib",
        )
    )
    assert import_library.is_file(), "kernel32 import-library test oracle unavailable"
    beta = coff_symbols(objects["beta"])
    entry = next(
        name for name, (section, storage) in beta.items()
        if name.startswith("$openc$") and section == 1 and storage == 2
    )
    output = root / "linked.exe"
    command = [
        linker, "/nologo", "/nodefaultlib", "/subsystem:console",
        f"/entry:{entry}", f"/out:{output}",
        *[item["object"] for item in manifest["modules"]],
        str(import_library),
    ]
    linked = subprocess.run(command, capture_output=True, text=True, timeout=30)
    assert linked.returncode == 0, f"link: {linked.stdout}\n{linked.stderr}"
    executed = subprocess.run([str(output)], capture_output=True, timeout=10)
    assert executed.returncode == expected, executed.returncode


def main() -> None:
    compiler = Path(sys.argv[1]).resolve()
    with tempfile.TemporaryDirectory(prefix="openc-module-coff-") as temp:
        root = Path(temp)
        baseline, manifest = build(compiler, root / "base")
        alpha_names = coff_symbols(baseline["alpha"])
        beta_names = coff_symbols(baseline["beta"])
        alpha_definition = {
            name for name, (section, storage) in alpha_names.items()
            if name.startswith("$openc$") and section == 1 and storage == 2
        }
        beta_undefined = {
            name for name, (section, storage) in beta_names.items()
            if name.startswith("$openc$") and section == 0 and storage == 2
        }
        assert alpha_definition == beta_undefined and len(alpha_definition) == 1
        link_and_run(root / "base", manifest, baseline, 7)

        prefix = root / "base" / "bundle"
        existing = subprocess.run(
            [str(compiler), "artifact",
             f"--project={root / 'base' / 'openc.project.json'}",
             "--kind=module-coff-set", f"--output={prefix}"],
            capture_output=True, text=True, timeout=30,
        )
        assert existing.returncode == 0, existing.stdout + existing.stderr
        assert json.loads(
            (root / "base" / "bundle.modules.json").read_text(encoding="utf-8")
        ) == manifest
        assert {
            item["module"]: Path(item["object"]).read_bytes()
            for item in manifest["modules"]
        } == baseline

        # A late object write failure must not leave a believable COMPLETE set.
        failure, failure_manifest = build(compiler, root / "failure")
        blocked_object = Path(failure_manifest["modules"][1]["object"])
        blocked_object.unlink()
        blocked_object.mkdir()
        failed = subprocess.run(
            [str(compiler), "artifact",
             f"--project={root / 'failure' / 'openc.project.json'}",
             "--kind=module-coff-set", f"--output={root / 'failure' / 'bundle'}"],
            capture_output=True, text=True, timeout=30,
        )
        assert failed.returncode != 0
        incomplete = json.loads(
            (root / "failure" / "bundle.modules.json").read_text(encoding="utf-8")
        )
        assert incomplete == {
            "schema": "openc.module_coff_set.v1", "status": "INCOMPLETE"
        }
        blocked_object.rmdir()
        repaired = subprocess.run(
            [str(compiler), "artifact",
             f"--project={root / 'failure' / 'openc.project.json'}",
             "--kind=module-coff-set", f"--output={root / 'failure' / 'bundle'}"],
            capture_output=True, text=True, timeout=30,
        )
        assert repaired.returncode == 0, repaired.stdout + repaired.stderr
        recovered = json.loads(
            (root / "failure" / "bundle.modules.json").read_text(encoding="utf-8")
        )
        assert recovered == failure_manifest
        assert {
            item["module"]: Path(item["object"]).read_bytes()
            for item in recovered["modules"]
        } == failure

        reordered, _ = build(compiler, root / "reordered", reverse_manifest=True)
        assert reordered == baseline, "manifest key order changed module objects"

        inserted, _ = build(
            compiler, root / "inserted",
            alpha="i32 pad() { return 0; }\n" + ALPHA,
        )
        assert inserted["beta"] == baseline["beta"], "unrelated ID shift changed importer"
        assert inserted["alpha"] != baseline["alpha"]

        body, body_manifest = build(
            compiler, root / "body",
            alpha=ALPHA.replace("left + right", "left + right + 1"),
        )
        assert body["beta"] == baseline["beta"], "callee body changed importer"
        assert body["alpha"] != baseline["alpha"]
        link_and_run(root / "body", body_manifest, body, 8)
        print("module COFF set: boundary/link/failure-recovery checks passed")


if __name__ == "__main__":
    main()
