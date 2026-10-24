"""Replay contributions across body spans, named layouts and rejected exports."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import tempfile

from benchmark_sh27_production import MIB, ROOT, sha256
from windows_process_measure import run_measured

ALPHA = ("export i32 helper(i32 x) { return x + 1; }\n"
         "export struct Pair { i32 x; i32 y; }\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("compiler", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    report = {"schema": "openc.sh27.frontend_edges.v1", "status": "FAIL", "cases": []}
    try:
        with tempfile.TemporaryDirectory(prefix="fe-", dir=ROOT / "build-output") as temporary:
            root = Path(temporary)
            (root / "a.p").write_text(ALPHA)
            (root / "b.p").write_text("export Pair make_pair(i32 x) { return Pair{ x = x, y = x + 1 }; }\n")
            (root / "c.p").write_text("export i32 spare() { return 1; }\n")
            (root / "d.p").write_text("import alpha; import beta;\n"
                "i32 main() { alpha.Pair p = alpha.make_pair(3); return cast(i32, p.x) + p.y + "
                "alpha.helper(1) + beta.spare() + cast(i32, size_of(alpha.Pair)) + "
                "cast(i32, align_of(alpha.Pair)); }\n")
            project = root / "openc.project.json"
            project.write_text(json.dumps({"name": "frontend-edges", "version": "1.0.0",
                "edition": "OpenC 1.0", "profile": "standard", "target": "windows-x86_64",
                "modules": {"alpha": ["a.p", "b.p"], "beta": ["c.p"], "zapp": ["d.p"]}}))
            prefix = root / "cache/objects"

            def build(cached: bool) -> dict:
                image = root / ("cached.exe" if cached else "fresh.exe")
                if image.exists(): image.unlink()
                timing = image.with_suffix(".json")
                command = [str(compiler), "artifact", f"--project={project}",
                    "--kind=" + ("cached-exe" if cached else "exe"), f"--output={image}",
                    f"--timings={timing}", "--source-chunks=4"]
                if cached: command.append(f"--cache-prefix={prefix}")
                sample = run_measured(command, cwd=root, sample_interval=0.01,
                    max_private_bytes=256 * MIB, max_working_set_bytes=64 * MIB,
                    max_captured_output_bytes=MIB, timeout_seconds=60)
                assert not sample["memory_limit_exceeded"] and not sample["timed_out"], sample
                assert not sample["stdout_truncated"] and not sample["stderr_truncated"]
                data = json.loads(timing.read_text())
                result = {"measurement": sample, "timings": data,
                          "sha256": sha256(image) if image.exists() else None}
                if sample["exit_code"] == 0:
                    executed = run_measured([str(image)], cwd=root, sample_interval=0.01,
                        max_private_bytes=128 * MIB, max_working_set_bytes=64 * MIB,
                        max_captured_output_bytes=MIB, timeout_seconds=10)
                    assert not executed["memory_limit_exceeded"] and not executed["timed_out"]
                    assert not executed["stdout"] and not executed["stderr"]
                    result["runtime_exit"] = executed["exit_code"]
                return result

            for name, source, expected in (
                ("cold", ALPHA, 22), ("warm", ALPHA, 22),
                ("body", ALPHA.replace("x + 1", "x + 2"), 23),
                ("shifted-named-span", ALPHA.replace("x + 1;", "x + 1; /* larger body */"), 22),
                ("field-layout", ALPHA.replace("i32 x;", "i64 x;"), 34),
            ):
                (root / "a.p").write_text(source)
                cached, fresh = build(True), build(False)
                report["cases"].append({"name": name, "cached": cached, "fresh": fresh})
                assert cached["measurement"]["exit_code"] == fresh["measurement"]["exit_code"] == 0, report["cases"][-1]
                assert cached["sha256"] == fresh["sha256"]
                assert cached["runtime_exit"] == fresh["runtime_exit"] == expected
                if name in ("warm", "body"):
                    count = 4 if name == "warm" else 3
                    assert cached["timings"]["frontend_cache"]["resolution_hits"] == count
                if name == "field-layout": assert cached["timings"]["object_cache"]["hits"] == 0
                if name == "shifted-named-span": assert cached["timings"]["object_cache"]["hits"] == 3
            (root / "a.p").write_text(ALPHA.replace("helper", "helpex"))
            before = {p.name: sha256(p) for p in prefix.parent.iterdir() if p.is_file()}
            cached, fresh = build(True), build(False)
            report["cases"].append({"name": "rejected-provider-rename", "cached": cached, "fresh": fresh})
            for result in (cached, fresh):
                assert result["measurement"]["exit_code"] != 0 and result["sha256"] is None
            normalize = lambda result: (result["measurement"]["exit_code"], result["measurement"]["stderr"],
                "\n".join(line for line in result["measurement"]["stdout"].splitlines()
                          if not line.startswith("OpenC Windows artifact:")))
            assert normalize(cached) == normalize(fresh)
            assert before == {p.name: sha256(p) for p in prefix.parent.iterdir() if p.is_file()}
            (root / "a.p").write_text(ALPHA.replace("Pair", "Paar"))
            cached, fresh = build(True), build(False)
            report["cases"].append({"name": "rejected-type-rename", "cached": cached, "fresh": fresh})
            assert cached["measurement"]["exit_code"] != 0 and fresh["measurement"]["exit_code"] != 0
            assert normalize(cached) == normalize(fresh)
            assert before == {p.name: sha256(p) for p in prefix.parent.iterdir() if p.is_file()}
            (root / "a.p").write_text("import missing;\n" + ALPHA.replace(
                "return x + 1;", "return missing.value(x);"))
            cached, fresh = build(True), build(False)
            report["cases"].append({"name": "rejected-import-use", "cached": cached, "fresh": fresh})
            assert cached["measurement"]["exit_code"] != 0 and fresh["measurement"]["exit_code"] != 0
            assert normalize(cached) == normalize(fresh)
            assert before == {p.name: sha256(p) for p in prefix.parent.iterdir() if p.is_file()}
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
