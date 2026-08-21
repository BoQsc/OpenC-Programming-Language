import hashlib
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BRIDGE_SPEC = importlib.util.spec_from_file_location(
    "bootstrap_sh17_binary_read_intrinsic",
    ROOT / "compiler/selfhost/bootstrap_sh17_binary_read_intrinsic.py",
)
BRIDGE = importlib.util.module_from_spec(BRIDGE_SPEC)
assert BRIDGE_SPEC.loader is not None
sys.modules[BRIDGE_SPEC.name] = BRIDGE
BRIDGE_SPEC.loader.exec_module(BRIDGE)


class Sh17WinmdProjectionTests(unittest.TestCase):
    def test_binary_read_bridge_repairs_exactly_one_call(self) -> None:
        source = (
            "    void v8;\n"
            "    v8 = oc_file_read_bytes_raw(v1, v2, v3);\n"
        )
        patched, temporary = BRIDGE.patch_binary_read_call(source)
        self.assertEqual(temporary, "v8")
        self.assertEqual(
            patched,
            "    oc_status v8;\n"
            "    v8 = oc_file_read_bytes_raw(v1, &v2, &v3);\n",
        )

    def test_contract_hash_matches_checked_in_manifest(self) -> None:
        contract = ROOT / "compiler/targets/windows-winmd-projection-contract.json"
        manifest = json.loads(
            (ROOT / "standard_library/windows.raw/generated/manifest.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(
            manifest["generator"]["contract_sha256"],
            hashlib.sha256(contract.read_bytes()).hexdigest(),
        )

    def test_generated_projection_audit_passes_without_winmd_input(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "report.json"
            completed = subprocess.run(
                [
                    sys.executable,
                    str(ROOT / "scripts/verify_sh17_winmd_projection.py"),
                    "--output",
                    str(report),
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertEqual(json.loads(report.read_text())["status"], "PASS")

    def test_metadata_pin_is_not_a_normal_dependency(self) -> None:
        pin = json.loads(
            (ROOT / "compiler/targets/windows-win32-metadata.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(pin["member_bytes"], 24355840)
        self.assertEqual(len(pin["member_sha256"]), 64)
        self.assertFalse(pin["normal_compilation_dependency"])
        self.assertFalse(pin["runtime_dependency"])


if __name__ == "__main__":
    unittest.main()
