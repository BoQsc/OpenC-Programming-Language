#!/usr/bin/env python3
"""Prove exact stage-0/stage-1 project and module frontend parity."""
from __future__ import annotations

import argparse
import difflib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def run(command: list[str]) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(command, cwd=ROOT, capture_output=True)


def canonical_projects() -> list[Path]:
    return sorted(
        path
        for path in ROOT.rglob("*.project.json")
        if "build-output" not in path.relative_to(ROOT).parts
    )


def focused_cases() -> list[tuple[str, str, dict[str, str]]]:
    return [
        ("empty_modules", '{"modules":{}}', {}),
        (
            "module_sort",
            '{"modules":{"z":["z.p"],"a":["a.p"]}}',
            {"a.p": "i32 a(){return 1;}\n", "z.p": "i32 z(){return 2;}\n"},
        ),
        (
            "multi_source_order",
            '{"modules":{"app":["a.p","b.p","c.p"]}}',
            {
                "a.p": "i32 a(){return 1;}\n",
                "b.p": "i32 b(){return 2;}\n",
                "c.p": "i32 c(){return 3;}\n",
            },
        ),
        (
            "builtin_imports",
            '{"modules":{"app":["main.p"]}}',
            {"main.p": "import system.io; import system.text; i32 main(){return 0;}\n"},
        ),
        (
            "repeated_import",
            '{"modules":{"app":["main.p"],"math":["math.p"]}}',
            {
                "main.p": "import math; import math; i32 main(){return math.one();}\n",
                "math.p": "export i32 one(){return 1;}\n",
            },
        ),
        (
            "missing_import",
            '{"modules":{"app":["main.p"]}}',
            {"main.p": "import missing.module; i32 main(){return 0;}\n"},
        ),
        (
            "ambiguous_short_qualifier",
            '{"modules":{"app":["main.p"],"debug.io":["debug.p"],"system.io":["system.p"]}}',
            {
                "main.p": "import system.io; import debug.io; i32 main(){return 0;}\n",
                "debug.p": "export i32 debug_value(){return 1;}\n",
                "system.p": "export i32 system_value(){return 2;}\n",
            },
        ),
        (
            "direct_cycle",
            '{"modules":{"a":["a.p"],"b":["b.p"]}}',
            {
                "a.p": "import b; export i32 a(){return 1;}\n",
                "b.p": "import a; export i32 b(){return 2;}\n",
            },
        ),
        (
            "parser_recovery",
            '{"modules":{"app":["bad.p"],"other":["good.p"]}}',
            {
                "bad.p": "i32 broken(){return 1}\n",
                "good.p": "i32 good(){return 2;}\n",
            },
        ),
        (
            "missing_source",
            '{"modules":{"app":["absent.p"]}}',
            {},
        ),
        (
            "malformed_project",
            '{"modules":{"app":["main.p"]}',
            {"main.p": "i32 main(){return 0;}\n"},
        ),
        (
            "ignored_nested_values",
            '{"name":"probe","target":{"name":"windows-x86_64","values":{"feature":true}},'
            '"metadata":[1,false,null,{"nested":["x"]}],"modules":{"app":["main.p"]}}',
            {"main.p": "i32 main(){return 0;}\n"},
        ),
        (
            "json_whitespace",
            '{\r\n  "profile" : "standard",\r\n  "modules" : {\r\n    "app" : [ "main.p" ]\r\n  }\r\n}\r\n',
            {"main.p": "i32 main() { return 0; }\r\n"},
        ),
        (
            "unit_local_imports",
            '{"modules":{"app":["a.p","b.p"],"math":["math.p"]}}',
            {
                "a.p": "import math; i32 a(){return math.one();}\n",
                "b.p": "i32 b(){return 2;}\n",
                "math.p": "export i32 one(){return 1;}\n",
            },
        ),
        (
            "full_and_short_names",
            '{"modules":{"app.main":["main.p"],"vendor.math":["math.p"]}}',
            {
                "main.p": "import vendor.math; i32 main(){return math.one();}\n",
                "math.p": "export i32 one(){return 1;}\n",
            },
        ),
    ]


def compare_case(
    name: str,
    project: Path,
    stage0: Path,
    stage1: Path,
) -> tuple[bool, subprocess.CompletedProcess[bytes], subprocess.CompletedProcess[bytes]]:
    left = run([str(stage0), "project-observe", str(project.resolve())])
    right = run([str(stage1), "--project", str(project.resolve())])
    return (
        left.returncode == right.returncode
        and left.stdout == right.stdout
        and left.stderr == right.stderr,
        left,
        right,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage0", type=Path, default=ROOT / "compiler" / "openc.exe")
    parser.add_argument("--stage1", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "build-output" / "selfhost")
    args = parser.parse_args()

    stage0 = args.stage0.resolve()
    stage1 = args.stage1.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    cases: list[tuple[str, Path]] = [
        (f"canonical:{path.relative_to(ROOT).as_posix()}", path)
        for path in canonical_projects()
    ]
    focused = focused_cases()
    observed_rules: set[str] = set()
    failures: list[str] = []

    with tempfile.TemporaryDirectory(prefix="project-parity-", dir=output) as temporary:
        temporary_root = Path(temporary)
        for name, project_text, files in focused:
            case_root = temporary_root / name
            case_root.mkdir()
            project = case_root / "openc.project.json"
            project.write_text(project_text, encoding="utf-8", newline="")
            for relative, content in files.items():
                path = case_root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8", newline="")
            cases.append((f"probe:{name}", project))

        for name, project in cases:
            exact, left, right = compare_case(name, project, stage0, stage1)
            for line in left.stdout.decode("utf-8", errors="replace").splitlines():
                if line.startswith("ERROR OPENC-MODULE-"):
                    observed_rules.add(line.split()[1])
            if exact:
                continue
            diff = "".join(
                difflib.unified_diff(
                    left.stdout.decode("utf-8", errors="replace").splitlines(True),
                    right.stdout.decode("utf-8", errors="replace").splitlines(True),
                    fromfile="stage0",
                    tofile="stage1",
                )
            )
            failures.append(
                f"{name}: exits {left.returncode}/{right.returncode}\n"
                f"stage0 stderr: {left.stderr.decode(errors='replace')}\n"
                f"stage1 stderr: {right.stderr.decode(errors='replace')}\n{diff}"
            )

    required_rules = {
        "OPENC-MODULE-IMPORT-MISSING-001",
        "OPENC-MODULE-QUALIFIER-AMBIGUOUS-001",
        "OPENC-MODULE-CYCLE-001",
    }
    missing_rules = sorted(required_rules - observed_rules)
    if missing_rules:
        failures.append("missing project/module rule coverage: " + ", ".join(missing_rules))

    result = {
        "schema": "openc.self_host_project_parity.v1",
        "status": "PASS" if not failures else "FAIL",
        "protocol": "OPENC-PROJECT-OBSERVATION 1",
        "canonical_projects": len(canonical_projects()),
        "focused_probes": len(focused),
        "comparisons": len(cases),
        "module_graph_rules": len(observed_rules),
        "observed_module_graph_rules": sorted(observed_rules),
        "failures": failures,
    }
    (output / "project-parity-result.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n"
    )
    if failures:
        print(failures[0])
        return 1
    print(
        "self-host project parity: PASS; "
        f"canonical={result['canonical_projects']} probes={result['focused_probes']} "
        f"comparisons={result['comparisons']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
