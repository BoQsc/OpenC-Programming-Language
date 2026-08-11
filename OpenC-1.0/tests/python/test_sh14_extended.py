from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "compiler" / "selfhost" / "benchmark_sh14_extended.py"
SPEC = importlib.util.spec_from_file_location("benchmark_sh14_extended", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
SUITE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SUITE)


class Sh14ExtendedSuiteTests(unittest.TestCase):
    def test_summary_preserves_samples_and_median(self) -> None:
        result = SUITE.summary([
            {"elapsed_seconds": 0.184},
            {"elapsed_seconds": 0.158},
            {"elapsed_seconds": 0.160},
        ])
        self.assertEqual(result["runs"], 3)
        self.assertEqual(result["minimum_seconds"], 0.158)
        self.assertEqual(result["median_seconds"], 0.160)
        self.assertEqual(result["maximum_seconds"], 0.184)
        self.assertEqual(result["raw_seconds"], [0.184, 0.158, 0.160])

    def test_scaling_project_has_exact_requested_source_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "scale"
            requested = SUITE.SCALING_BYTES[0]
            project_path = SUITE.generate_scaling_project(root, requested)
            project = json.loads(project_path.read_text(encoding="utf-8"))
            sources = project["modules"]["scale.main"]
            self.assertEqual(len(sources), 32)
            self.assertEqual(sum((root / name).stat().st_size for name in sources), requested)
            self.assertEqual(project["target"], "windows-x86_64")


if __name__ == "__main__":
    unittest.main()
