"""Falsify the opt-in COFF symbol identity boundary.

Usage: python test_coff_stable_symbols.py candidate-openc.exe previous-openc.exe
"""

from __future__ import annotations

import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile


ALPHA_ONE = "i32 hidden(i32 value) { return value + 1; }\n"
ALPHA_TWO = """export i32 api(i32 value) { return hidden(value); }
i32 signature_probe(i32 value) { return 1; }
"""
BETA = """import alpha;
i32 signature_probe(i32 value) { return 2; }
i32 main() { return alpha.api(1); }
"""


def build(
    compiler: Path,
    root: Path,
    *,
    alpha_one: str = ALPHA_ONE,
    alpha_two: str = ALPHA_TWO,
    beta: str = BETA,
    module_name: str = "alpha",
    source_order: tuple[str, str] = ("alpha-one.p", "alpha-two.p"),
    stable: bool = True,
) -> bytes:
    root.mkdir()
    (root / "alpha-one.p").write_text(alpha_one, encoding="utf-8")
    (root / "alpha-two.p").write_text(alpha_two, encoding="utf-8")
    (root / "beta.p").write_text(beta, encoding="utf-8")
    manifest = {
        "name": "coff-identity-test",
        "version": "0.1.0",
        "edition": "OpenC 1.0",
        "profile": "standard",
        "target": "windows-x86_64",
        "modules": {module_name: list(source_order), "beta": ["beta.p"]},
    }
    project = root / "openc.project.json"
    output = root / "module.obj"
    project.write_text(json.dumps(manifest), encoding="utf-8")
    command = [
        str(compiler), "artifact", f"--project={project}",
        "--kind=coff-object", f"--output={output}",
    ]
    if stable:
        command.append("--stable-coff-symbols")
    run = subprocess.run(command, capture_output=True, text=True, timeout=30)
    assert run.returncode == 0, f"{command}: {run.stdout}\n{run.stderr}"
    return output.read_bytes()


def symbols(coff: bytes) -> dict[str, int]:
    assert struct.unpack_from("<H", coff)[0] == 0x8664
    table, count = struct.unpack_from("<II", coff, 8)
    strings_at = table + count * 18
    size = struct.unpack_from("<I", coff, strings_at)[0]
    assert strings_at + size <= len(coff)
    result: dict[str, int] = {}
    index = 0
    while index < count:
        at = table + index * 18
        raw = coff[at : at + 8]
        if raw[:4] == b"\0\0\0\0":
            offset = struct.unpack_from("<I", raw, 4)[0]
            end = coff.index(0, strings_at + offset)
            name = coff[strings_at + offset : end].decode("ascii")
        else:
            name = raw.rstrip(b"\0").decode("ascii")
        storage_class = coff[at + 16]
        result[name] = storage_class
        index += 1 + coff[at + 17]
    return result


def private_symbols(coff: bytes) -> set[str]:
    return {name for name in symbols(coff) if name.startswith("$openc$")}


def ordinary_exe(compiler: Path, project: Path, output: Path) -> bytes:
    run = subprocess.run(
        [str(compiler), "build", f"--project={project}", f"--output={output}"],
        capture_output=True, text=True, timeout=30,
    )
    assert run.returncode == 0, f"ordinary PE build: {run.stdout}\n{run.stderr}"
    executed = subprocess.run([str(output)], capture_output=True, timeout=10)
    assert executed.returncode == 2, f"ordinary PE result: {executed.returncode}"
    return output.read_bytes()


def main() -> None:
    candidate = Path(sys.argv[1]).resolve()
    previous = Path(sys.argv[2]).resolve()
    with tempfile.TemporaryDirectory(prefix="openc-coff-identity-") as temp:
        root = Path(temp)
        baseline = build(candidate, root / "base")
        repeat = build(candidate, root / "repeat")
        assert baseline == repeat, "identical COFF must be byte-exact"
        names = private_symbols(baseline)
        assert len(names) == 4, names
        assert all(len(name) == 71 for name in names)
        assert all(symbols(baseline)[name] == 2 for name in names)
        # Identical private declaration in alpha and beta has distinct hash.
        assert len(names) == len(set(names))

        reordered = build(
            candidate, root / "reordered",
            source_order=("alpha-two.p", "alpha-one.p"),
        )
        assert private_symbols(reordered) == names

        inserted = build(
            candidate, root / "inserted",
            alpha_one="i32 pad() { return 0; }\n" + ALPHA_ONE,
        )
        assert names < private_symbols(inserted)
        assert len(private_symbols(inserted) - names) == 1

        body = build(
            candidate, root / "body",
            alpha_one=ALPHA_ONE.replace("value + 1", "value + 999"),
        )
        assert private_symbols(body) == names
        assert body != baseline

        signature = build(
            candidate, root / "signature",
            alpha_two=ALPHA_TWO.replace("signature_probe(i32", "signature_probe(i64"),
        )
        assert len(names - private_symbols(signature)) == 1
        assert len(private_symbols(signature) - names) == 1

        renamed_module = build(
            candidate,
            root / "module-rename",
            module_name="gamma",
            beta=BETA.replace("import alpha;", "import gamma;").replace("alpha.api", "gamma.api"),
        )
        assert len(names - private_symbols(renamed_module)) == 2
        assert len(private_symbols(renamed_module) - names) == 2

        ordinary_candidate = build(candidate, root / "ordinary-candidate", stable=False)
        ordinary_previous = build(previous, root / "ordinary-previous", stable=False)
        assert ordinary_candidate == ordinary_previous, "default COFF output changed"
        assert all(symbols(ordinary_candidate)[name] == 3 for name in private_symbols(ordinary_candidate))
        project = root / "base" / "openc.project.json"
        candidate_exe = ordinary_exe(candidate, project, root / "candidate.exe")
        previous_exe = ordinary_exe(previous, project, root / "previous.exe")
        assert candidate_exe == previous_exe, "default PE output changed"

        invalid = subprocess.run(
            [
                str(candidate), "artifact", f"--project={project}",
                "--kind=exe", f"--output={root / 'invalid.exe'}",
                "--stable-coff-symbols",
            ],
            capture_output=True, text=True, timeout=10,
        )
        assert invalid.returncode == 64
        assert not (root / "invalid.exe").exists()
        print("stable COFF identity: 10 deterministic/invalidation/default-parity checks passed")


if __name__ == "__main__":
    main()
