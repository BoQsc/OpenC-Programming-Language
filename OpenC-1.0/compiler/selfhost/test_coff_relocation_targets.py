"""Repeated symbol resolution must never bypass later relocation validation."""
from __future__ import annotations

import hashlib
from pathlib import Path
import struct
import subprocess
import sys
import tempfile

from test_module_coff_set import build, coff_symbols, link_and_run


def main() -> None:
    compiler = Path(sys.argv[1]).resolve(strict=True)
    with tempfile.TemporaryDirectory(prefix="openc-reloc-") as temporary:
        root = Path(temporary)
        objects, manifest = build(compiler, root / "project", beta=(
            "import alpha;\ni32 main() { i32 x = alpha.add(3, 4); "
            "x = x + alpha.add(3, 4); x = x + alpha.add(3, 4); return x; }\n"
        ), native_link=True)
        link_and_run(root / "project", manifest, objects, 21)
        native = root / "project/native-linked.exe"
        assert subprocess.run([str(native)], timeout=10).returncode == 21
        names = coff_symbols(objects["beta"])
        entry = next(name for name, (section, storage) in names.items()
                     if name.startswith("$openc$") and section == 1 and storage == 2)
        payload = objects["beta"]
        code_size, code_raw, reloc_raw = struct.unpack_from("<III", payload, 36)
        count = struct.unpack_from("<H", payload, 52)[0]
        rows: dict[int, list[tuple[int, int]]] = {}
        for i in range(count):
            row = reloc_raw + i * 10
            offset, symbol, kind = struct.unpack_from("<IIH", payload, row)
            assert kind == 4
            rows.setdefault(symbol, []).append((row, offset))
        # The last symbol is the only cross-module function in this fixture.
        symbols, symbol_count = struct.unpack_from("<II", payload, 8)
        external = symbol_count - 1
        assert struct.unpack_from("<h", payload, symbols + external * 18 + 12)[0] == 0
        assert len(rows[external]) == 3
        row, code_offset = rows[external][1]
        paths = {item["module"]: Path(item["object"]) for item in manifest["modules"]}

        def link(name: str, beta: bytes, expected: bool) -> Path:
            changed = root / (name + ".obj")
            changed.write_bytes(beta)
            executable = root / (name + ".exe")
            command = [str(compiler), "module-coff-link", f"--entry={entry}",
                       f"--output={executable}"]
            for module in ("alpha", "beta"):
                path = paths[module] if module == "alpha" else changed
                digest = hashlib.sha256(path.read_bytes()).hexdigest()
                command += [f"--object={path}", f"--sha256={digest}"]
            result = subprocess.run(command, capture_output=True, text=True, timeout=30)
            if expected:
                assert result.returncode == 0, result.stdout + result.stderr
                assert executable.read_bytes() == native.read_bytes()
                assert subprocess.run([str(executable)], timeout=10).returncode == 21
            else:
                assert result.returncode != 0 and not executable.exists(), name
                assert "OPENC-COFF-LINK" in result.stderr, result.stderr
            return executable

        link("valid-repeated-target", payload, True)
        wrong_kind = bytearray(payload)
        struct.pack_into("<H", wrong_kind, row + 8, 3)
        link("later-wrong-kind", wrong_kind, False)
        wrong_offset = bytearray(payload)
        struct.pack_into("<I", wrong_offset, row, code_size - 3)
        link("later-outside-code", wrong_offset, False)
        wrong_symbol = bytearray(payload)
        struct.pack_into("<I", wrong_symbol, row + 4, symbol_count)
        link("later-outside-symbol-table", wrong_symbol, False)
        wrong_addend = bytearray(payload)
        struct.pack_into("<I", wrong_addend, code_raw + code_offset, 0x80000000)
        link("later-invalid-addend", wrong_addend, False)
        unresolved = bytearray(payload)
        strings = symbols + symbol_count * 18
        name_offset = struct.unpack_from("<I", unresolved, symbols + external * 18 + 4)[0]
        name_at = strings + name_offset + 7
        unresolved[name_at] = ord("a") if unresolved[name_at] != ord("a") else ord("b")
        link("unresolved-external", unresolved, False)
        print("COFF symbol targets: repeated success and five authenticated corruptions pass")


if __name__ == "__main__":
    main()
