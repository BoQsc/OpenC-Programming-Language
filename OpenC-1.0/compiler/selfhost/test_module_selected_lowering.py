"""Prove isolated module lowering, exact COFF identity, and full diagnostics.

Usage: python test_module_selected_lowering.py COMPILER
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

from test_module_coff_set import ALPHA, BETA, coff_symbols


def artifact(compiler: Path, root: Path, prefix: str, module: str | None = None):
    command = [str(compiler), "artifact", f"--project={root / 'openc.project.json'}",
               "--kind=module-coff-set", f"--output={root / prefix}",
               f"--timings={root / (prefix + '.timings.json')}"]
    if module is not None:
        command.append(f"--module={module}")
    else:
        command.append(f"--linked-exe={root / (prefix + '.exe')}")
    return subprocess.run(command, capture_output=True, text=True, timeout=30)


def load_set(root: Path, prefix: str):
    manifest = json.loads((root / (prefix + ".modules.json")).read_text())
    assert manifest["status"] == "COMPLETE"
    entries = {entry["module"]: entry for entry in manifest["modules"]}
    for entry in entries.values():
        assert hashlib.sha256(Path(entry["object"]).read_bytes()).hexdigest() == entry["sha256"]
    return entries


def relink(compiler: Path, root: Path, entry: str, entries: list[dict], name: str):
    output = root / (name + ".exe")
    command = [str(compiler), "module-coff-link", f"--entry={entry}", f"--output={output}"]
    for item in entries:
        command.extend([f"--object={item['object']}", f"--sha256={item['sha256']}"])
    run = subprocess.run(command, capture_output=True, text=True, timeout=30)
    assert run.returncode == 0, run.stdout + run.stderr
    return output


def main():
    compiler = Path(sys.argv[1]).resolve(strict=True)
    with tempfile.TemporaryDirectory(prefix="openc-module-select-") as temp:
        root = Path(temp)
        (root / "alpha.p").write_text(ALPHA)
        (root / "beta.p").write_text(BETA)
        (root / "gamma.p").write_text("i32 unrelated() { return 9; }\n")
        (root / "openc.project.json").write_text(json.dumps({
            "name": "selected-module-proof", "version": "0.1.0",
            "edition": "OpenC 1.0", "profile": "standard", "target": "windows-x86_64",
            "modules": {"alpha": ["alpha.p"], "beta": ["beta.p"], "gamma": ["gamma.p"]},
        }))
        full = artifact(compiler, root, "full")
        assert full.returncode == 0, full.stdout + full.stderr
        baseline = load_set(root, "full")
        assert list(baseline) == ["alpha", "beta", "gamma"]
        selected = {}
        for module in baseline:
            prefix = "selected-" + module
            run = artifact(compiler, root, prefix, module)
            assert run.returncode == 0, run.stdout + run.stderr
            only = load_set(root, prefix)
            assert list(only) == [module], only
            selected[module] = only[module]
            assert Path(only[module]["object"]).read_bytes() == Path(baseline[module]["object"]).read_bytes()
            timings = json.loads((root / (prefix + ".timings.json")).read_text())
            assert timings["module_selection"] == {"sources_lowered": 1, "sources_validation_only": 2}, timings
            assert timings["source_files"] == 3 and timings["work"]["functions"] == 1, timings

        names = coff_symbols(Path(selected["beta"]["object"]).read_bytes())
        entry = next(name for name, (section, storage) in names.items()
                     if name.startswith("$openc$") and section == 1 and storage == 2)
        linked = relink(compiler, root, entry, list(selected.values()), "selected-link")
        assert linked.read_bytes() == (root / "full.exe").read_bytes()
        assert subprocess.run([str(linked)], timeout=10).returncode == 7

        # Compile only the changed provider, retain both other saved objects,
        # and prove mixed fresh/saved output against a complete fresh build.
        (root / "alpha.p").write_text(ALPHA.replace("left + right", "left + right + 1"))
        changed = artifact(compiler, root, "edited-alpha", "alpha")
        assert changed.returncode == 0, changed.stdout + changed.stderr
        changed_alpha = load_set(root, "edited-alpha")["alpha"]
        assert changed_alpha["sha256"] != selected["alpha"]["sha256"]
        edited = relink(compiler, root, entry,
                        [changed_alpha, selected["beta"], selected["gamma"]], "edited-link")
        clean = artifact(compiler, root, "edited-clean")
        assert clean.returncode == 0, clean.stdout + clean.stderr
        assert edited.read_bytes() == (root / "edited-clean.exe").read_bytes()
        assert subprocess.run([str(edited)], timeout=10).returncode == 8

        # A module may span several sources; selection must lower all of them
        # and still exclude both other modules from IR/native emission.
        (root / "alpha_extra.p").write_text("export i32 extra() { return 2; }\n")
        project_path = root / "openc.project.json"
        project = json.loads(project_path.read_text())
        project["modules"]["alpha"].append("alpha_extra.p")
        project_path.write_text(json.dumps(project))
        multi_full = artifact(compiler, root, "multi-full")
        multi_selected = artifact(compiler, root, "multi-selected", "alpha")
        assert multi_full.returncode == 0, multi_full.stdout + multi_full.stderr
        assert multi_selected.returncode == 0, multi_selected.stdout + multi_selected.stderr
        multi_all = load_set(root, "multi-full")
        multi_one = load_set(root, "multi-selected")
        assert list(multi_one) == ["alpha"]
        assert Path(multi_one["alpha"]["object"]).read_bytes() == Path(multi_all["alpha"]["object"]).read_bytes()
        multi_timings = json.loads((root / "multi-selected.timings.json").read_text())
        assert multi_timings["module_selection"] == {"sources_lowered": 2, "sources_validation_only": 2}
        assert multi_timings["source_files"] == 4 and multi_timings["work"]["functions"] == 2

        unknown = artifact(compiler, root, "unknown", "missing")
        assert unknown.returncode != 0 and "OPENC-MODULE-SELECT" in unknown.stderr
        assert not (root / "unknown.modules.json").exists()

        # Selection must never suppress rejection in an unselected module.
        (root / "beta.p").write_text('import alpha;\ni32 main() { return "bad"; }\n')
        selected_invalid = artifact(compiler, root, "invalid-selected", "alpha")
        full_invalid = artifact(compiler, root, "invalid-full")
        assert selected_invalid.returncode != 0 and full_invalid.returncode != 0
        assert selected_invalid.stdout == full_invalid.stdout
        assert selected_invalid.stderr == full_invalid.stderr
        assert not (root / "invalid-selected.modules.json").exists()
        print("selected module lowering: exact objects/PE, changed-provider reuse, and full diagnostics passed")


if __name__ == "__main__":
    main()
