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
    native_link: bool = False,
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
    command = [
        str(compiler), "artifact", f"--project={project_path}",
        "--kind=module-coff-set", f"--output={prefix}",
    ]
    if native_link:
        command.append(f"--linked-exe={root / 'native-linked.exe'}")
    run = subprocess.run(
        command,
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
    if not linker:
        installed_linker = Path("C:/Program Files/LLVM/bin/lld-link.exe")
        if installed_linker.is_file():
            linker = str(installed_linker)
    assert linker, "lld-link test oracle unavailable"
    override = os.environ.get("OPENC_TEST_KERNEL32_LIB")
    sdk_libraries = sorted(
        Path("C:/Program Files (x86)/Windows Kits/10/Lib").glob("*/um/x64/kernel32.lib")
    )
    import_library = (
        Path(override) if override else sdk_libraries[-1] if sdk_libraries
        else Path("C:/D/dmd2/windows/lib64/mingw/kernel32.lib")
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
        baseline, manifest = build(compiler, root / "base", native_link=True)
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
        native_exe = root / "base" / "native-linked.exe"
        native_bytes = native_exe.read_bytes()
        assert subprocess.run([str(native_exe)], timeout=10).returncode == 7
        entry = next(
            name for name, (section, storage) in beta_names.items()
            if name.startswith("$openc$") and section == 1 and storage == 2
        )
        saved_exe = root / "base" / "saved-linked.exe"
        saved_pairs = [
            option
            for item in manifest["modules"]
            for option in (f"--object={item['object']}", f"--sha256={item['sha256']}")
        ]
        project_path = root / "base" / "openc.project.json"
        hidden_project = root / "base" / "openc.project.hidden"
        project_path.rename(hidden_project)
        try:
            saved = subprocess.run(
                [str(compiler), "module-coff-link", f"--entry={entry}",
                 f"--output={saved_exe}", *saved_pairs],
                capture_output=True, text=True, timeout=30,
            )
        finally:
            hidden_project.rename(project_path)
        assert saved.returncode == 0, saved.stdout + saved.stderr
        assert saved_exe.read_bytes() == native_bytes
        assert subprocess.run([str(saved_exe)], timeout=10).returncode == 7

        bad_hash_exe = root / "base" / "bad-hash.exe"
        bad_hash_pairs = saved_pairs.copy()
        bad_hash_pairs[1] = "--sha256=" + "0" * 64
        bad_hash = subprocess.run(
            [str(compiler), "module-coff-link", f"--entry={entry}",
             f"--output={bad_hash_exe}", *bad_hash_pairs],
            capture_output=True, text=True, timeout=30,
        )
        assert bad_hash.returncode != 0 and not bad_hash_exe.exists()
        assert "OPENC-COFF-LINK-SAVED" in bad_hash.stderr

        tampered = root / "base" / "tampered.obj"
        tampered_bytes = bytearray(Path(manifest["modules"][0]["object"]).read_bytes())
        tampered_bytes[20] ^= 1
        tampered.write_bytes(tampered_bytes)
        tampered_exe = root / "base" / "tampered.exe"
        tampered_pairs = saved_pairs.copy()
        tampered_pairs[0] = f"--object={tampered}"
        rejected = subprocess.run(
            [str(compiler), "module-coff-link", f"--entry={entry}",
             f"--output={tampered_exe}", *tampered_pairs],
            capture_output=True, text=True, timeout=30,
        )
        assert rejected.returncode != 0 and not tampered_exe.exists()
        assert "OPENC-COFF-LINK-SAVED" in rejected.stderr
        malformed_exe = root / "base" / "malformed.exe"
        malformed_pairs = tampered_pairs.copy()
        malformed_pairs[1] = "--sha256=" + hashlib.sha256(tampered_bytes).hexdigest()
        malformed = subprocess.run(
            [str(compiler), "module-coff-link", f"--entry={entry}",
             f"--output={malformed_exe}", *malformed_pairs],
            capture_output=True, text=True, timeout=30,
        )
        assert malformed.returncode != 0 and not malformed_exe.exists()
        assert "OPENC-COFF-LINK-PARSE" in malformed.stderr
        pe_report = root / "base" / "native-linked-pe-audit.json"
        audited = subprocess.run(
            [str(compiler), "pe-audit", f"--input={native_exe}",
             f"--output={pe_report}"],
            capture_output=True, text=True, timeout=30,
        )
        assert audited.returncode == 0, audited.stdout + audited.stderr
        audit = json.loads(pe_report.read_text(encoding="utf-8"))
        assert audit["status"] == "PASS", audit
        assert audit["checks"]["kernel32_only"] is True
        assert audit["checks"]["forbidden_crt_absent"] is True
        assert audit["checks"]["unwind_sorted_nonoverlapping"] is True

        prefix = root / "base" / "bundle"
        existing = subprocess.run(
            [str(compiler), "artifact",
             f"--project={root / 'base' / 'openc.project.json'}",
             "--kind=module-coff-set", f"--output={prefix}",
             f"--linked-exe={native_exe}"],
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
        assert native_exe.read_bytes() == native_bytes

        # A late native PE write failure must invalidate the output set too.
        native_exe.unlink()
        native_exe.mkdir()
        blocked_link = subprocess.run(
            [str(compiler), "artifact",
             f"--project={root / 'base' / 'openc.project.json'}",
             "--kind=module-coff-set", f"--output={prefix}",
             f"--linked-exe={native_exe}"],
            capture_output=True, text=True, timeout=30,
        )
        assert blocked_link.returncode != 0
        assert "OPENC-COFF-LINK-PE" in blocked_link.stderr
        assert json.loads(
            (root / "base" / "bundle.modules.json").read_text(encoding="utf-8")
        ) == {"schema": "openc.module_coff_set.v1", "status": "INCOMPLETE"}
        native_exe.rmdir()
        restored_link = subprocess.run(
            [str(compiler), "artifact",
             f"--project={root / 'base' / 'openc.project.json'}",
             "--kind=module-coff-set", f"--output={prefix}",
             f"--linked-exe={native_exe}"],
            capture_output=True, text=True, timeout=30,
        )
        assert restored_link.returncode == 0, restored_link.stdout + restored_link.stderr
        assert native_exe.read_bytes() == native_bytes

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

        reordered, _ = build(
            compiler, root / "reordered", reverse_manifest=True,
            native_link=True,
        )
        assert reordered == baseline, "manifest key order changed module objects"
        assert (root / "reordered" / "native-linked.exe").read_bytes() == native_bytes

        inserted, _ = build(
            compiler, root / "inserted",
            alpha="i32 pad() { return 0; }\n" + ALPHA,
        )
        assert inserted["beta"] == baseline["beta"], "unrelated ID shift changed importer"
        assert inserted["alpha"] != baseline["alpha"]

        body, body_manifest = build(
            compiler, root / "body",
            alpha=ALPHA.replace("left + right", "left + right + 1"),
            native_link=True,
        )
        assert body["beta"] == baseline["beta"], "callee body changed importer"
        assert body["alpha"] != baseline["alpha"]
        link_and_run(root / "body", body_manifest, body, 8)
        assert subprocess.run(
            [str(root / "body" / "native-linked.exe")], timeout=10
        ).returncode == 8
        print("module COFF set: boundary/native/saved-link/failure-recovery checks passed")


if __name__ == "__main__":
    main()
