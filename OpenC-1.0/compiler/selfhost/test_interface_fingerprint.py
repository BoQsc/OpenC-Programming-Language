"""Falsification tests for the opt-in public-interface projection.

Usage: python test_interface_fingerprint.py path/to/openc.exe
The test projects are temporary and do not touch the compiler checkout.
"""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile


ALPHA = """export i32 snap(i32 value) { return 1; }
export struct Packet { i32 count; }
const i32 FLAG = 7;
"""
BETA = """import alpha;
i32 main() { return 0; }
"""


def fingerprint(
    compiler: Path,
    root: Path,
    alpha: str,
    beta: str,
    *,
    expect_unsupported: bool = False,
    reverse_modules: bool = False,
) -> dict:
    root.mkdir(exist_ok=True)
    (root / "alpha.p").write_text(alpha, encoding="utf-8")
    (root / "beta.p").write_text(beta, encoding="utf-8")
    project = {
        "name": "interface-test",
        "version": "0.1.0",
        "edition": "OpenC 1.0",
        "profile": "standard",
        "target": "windows-x86_64",
        "modules": (
            {"beta": ["beta.p"], "alpha": ["alpha.p"]}
            if reverse_modules
            else {"alpha": ["alpha.p"], "beta": ["beta.p"]}
        ),
    }
    project_path = root / "openc.project.json"
    report_path = root / "fingerprint.json"
    project_path.write_text(json.dumps(project), encoding="utf-8")
    run = subprocess.run(
        [
            str(compiler),
            "interface-fingerprint",
            f"--project={project_path}",
            f"--output={report_path}",
        ],
        capture_output=True,
        text=True,
        timeout=30,
    )
    if bool(run.returncode) != expect_unsupported:
        raise AssertionError(
            f"unexpected fingerprint status ({run.returncode}): "
            f"{run.stdout}\n{run.stderr}"
        )
    if expect_unsupported:
        assert "OPENC-INTERFACE-UNSUPPORTED" in run.stderr + run.stdout
    return json.loads(report_path.read_text(encoding="utf-8"))


def modules(report: dict) -> dict:
    return {entry["name"]: entry for entry in report["modules"]}


def main() -> None:
    compiler = Path(sys.argv[1]).resolve()
    with tempfile.TemporaryDirectory(prefix="openc-interface-test-") as temp:
        root = Path(temp)
        baseline = fingerprint(compiler, root / "base", ALPHA, BETA)
        repeat = fingerprint(compiler, root / "repeat", ALPHA, BETA)
        assert baseline == repeat, "identical inputs must produce identical report"
        reversed_manifest = fingerprint(
            compiler, root / "reversed-manifest", ALPHA, BETA,
            reverse_modules=True,
        )
        assert baseline == reversed_manifest, "manifest key order is not an interface fact"
        assert baseline["supported"] and baseline["schema"] == "openc.interface_fingerprint.v1"
        assert modules(baseline)["beta"]["imports"] == ["alpha"]

        variants = {
            "same-length rename": (ALPHA.replace("snap", "swap"), BETA),
            "signature": (ALPHA.replace("snap(i32", "snap(i64"), BETA),
            "layout": (ALPHA.replace("i32 count", "i64 count"), BETA),
            "constant value": (ALPHA.replace("FLAG = 7", "FLAG = 8"), BETA),
            "visibility": (ALPHA.replace("export i32 snap", "i32 snap"), BETA),
            "import graph": (ALPHA, BETA.replace("import alpha;\n", "")),
        }
        for name, (a_source, b_source) in variants.items():
            changed = fingerprint(compiler, root / name.replace(" ", "-"), a_source, b_source)
            affected = "beta" if name == "import graph" else "alpha"
            assert modules(changed)[affected]["sha256"] != modules(baseline)[affected]["sha256"], name
            assert changed["project_sha256"] != baseline["project_sha256"], name

        body = fingerprint(
            compiler,
            root / "body-only",
            ALPHA.replace("return 1;", "return 999;"),
            BETA,
        )
        assert modules(body)["alpha"]["sha256"] == modules(baseline)["alpha"]["sha256"]
        assert body["project_sha256"] == baseline["project_sha256"]

        external_one = fingerprint(
            compiler, root / "abi-one", ALPHA + 'external(c, "one") i32 remote();\n', BETA
        )
        external_two = fingerprint(
            compiler, root / "abi-two", ALPHA + 'external(c, "two") i32 remote();\n', BETA
        )
        assert modules(external_one)["alpha"]["sha256"] != modules(external_two)["alpha"]["sha256"]

        unsupported = fingerprint(
            compiler,
            root / "unsupported-when",
            ALPHA + "when true { i32 selected() { return 1; } }\n",
            BETA,
            expect_unsupported=True,
        )
        assert not unsupported["supported"]
        assert modules(unsupported)["alpha"]["unsupported_kinds"] == ["when_decl"]
        print("interface fingerprint: 11 deterministic/falsification checks passed")


if __name__ == "__main__":
    main()
