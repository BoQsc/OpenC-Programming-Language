"""Bootstrap a pinned baseline and compare authenticated compiler relinks."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from benchmark_sh27_paired_revision import bootstrap, resolve_commit
from benchmark_sh27_production import MIB, ROOT, sha256
from test_module_coff_set import coff_symbols
from windows_process_measure import run_measured


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-ref", required=True)
    parser.add_argument("--seed", type=Path, required=True)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--pairs", type=int, default=11)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.baseline_ref):
        parser.error("baseline must be a full pinned commit SHA")
    output = args.output.resolve()
    if output.exists():
        parser.error("refusing to replace an existing report")
    candidate = args.compiler.resolve(strict=True)
    seed = args.seed.resolve(strict=True)
    baseline_ref = resolve_commit(args.baseline_ref)
    run_root = output.parent / "saved-link-runs"
    run_root.mkdir(parents=True, exist_ok=False)
    report = {"schema": "openc.sh27.saved_link_ci.v1", "status": "FAIL",
              "baseline_commit": baseline_ref, "candidate_commit": resolve_commit("HEAD"),
              "candidate_source_matches_head": subprocess.run(
                  ["git", "diff", "--quiet", "HEAD", "--", "OpenC-1.0/compiler/selfhost/source"],
                  cwd=ROOT.parent, check=False).returncode == 0,
              "candidate_sha256": sha256(candidate)}
    with tempfile.TemporaryDirectory(prefix="openc-link-base-") as temporary:
        temporary_root = Path(temporary).resolve()
        tree = temporary_root / "baseline"
        created = False
        try:
            subprocess.run(["git", "worktree", "add", "--detach", str(tree), baseline_ref],
                           cwd=ROOT.parent, check=True, capture_output=True, text=True)
            created = True
            baseline, baseline_record = bootstrap("baseline", tree / "OpenC-1.0", seed, run_root)
            report["baseline_bootstrap"] = baseline_record
            canonical = ROOT / "compiler/selfhost"
            project = canonical / "openc.project.json"
            modules = json.loads(project.read_text(encoding="utf-8"))["modules"]
            module = [name for name, files in modules.items() if "source/main_driver.p" in files]
            assert len(module) == 1
            driver = (canonical / "source/main_driver.p").read_bytes()
            declarations = re.findall(rb"(?m)^unsafe i32 main\(\)\s*\{", driver)
            assert len(declarations) == 1
            signature = declarations[0][:-1]
            module_bytes = module[0].encode("utf-8")
            identity = (b"openc-coff-symbol-v1:windows-x86_64-llp64\n" +
                        str(len(module_bytes)).encode() + b":" + module_bytes + b":" +
                        str(len(signature)).encode() + b":" + signature)
            entry = "$openc$" + hashlib.sha256(identity).hexdigest()
            objects = run_root / "objects"
            objects.mkdir()
            prefix = objects / "part"
            expected = objects / "compiler.exe"
            priming = run_measured([str(candidate), "artifact", f"--project={project}",
                "--kind=module-coff-set", f"--output={prefix}",
                f"--linked-exe={expected}", "--source-partitions=32", "--source-chunks=4"],
                cwd=ROOT.parent, sample_interval=0.01,
                max_private_bytes=256 * MIB, max_working_set_bytes=64 * MIB,
                max_captured_output_bytes=MIB, timeout_seconds=120)
            report["object_build"] = priming
            assert priming["exit_code"] == 0 and not priming["memory_limit_exceeded"] and not priming["timed_out"]
            manifest = Path(str(prefix) + ".modules.json")
            manifest_data = json.loads(manifest.read_text(encoding="utf-8"))
            assert sum(entry in coff_symbols(Path(p["object"]).read_bytes())
                       for p in manifest_data["partitions"]) == 1
            oracle = subprocess.run([str(expected), "version"], capture_output=True, timeout=10)
            reference = subprocess.run([str(candidate), "version"], capture_output=True, timeout=10)
            assert oracle.returncode == reference.returncode == 0 and oracle.stdout == reference.stdout
            pairs = run_root / "pairs.json"
            compared = subprocess.run([sys.executable,
                str(Path(__file__).with_name("benchmark_sh27_saved_link.py")),
                "--baseline", str(baseline), "--candidate", str(candidate),
                "--manifest", str(manifest), "--object-root", str(ROOT.parent),
                f"--entry={entry}", "--expected-exe", str(expected),
                "--pairs", str(args.pairs), "--require-gain", "--output", str(pairs)],
                cwd=ROOT.parent, check=False)
            if pairs.is_file():
                record = json.loads(pairs.read_text(encoding="utf-8"))
                report["summary"] = record.get("summary")
                report["pair_status"] = record["status"]
            if compared.returncode == 0 and report.get("pair_status") == "PASS":
                report["status"] = "PASS"
        except Exception as error:
            report["error"] = str(error)
        finally:
            if created:
                target = tree.resolve()
                if not target.is_relative_to(temporary_root):
                    raise RuntimeError("refusing to remove unexpected worktree")
                subprocess.run(["git", "worktree", "remove", "--force", str(target)],
                               cwd=ROOT.parent, check=True, capture_output=True, text=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: report.get(key) for key in ("status", "summary", "error")}, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
