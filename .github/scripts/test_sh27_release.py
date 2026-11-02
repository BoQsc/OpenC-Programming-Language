"""Detect publication-policy, digest, and bounded-download regressions."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import re
import sys
import tempfile
import unittest
import zipfile
from unittest.mock import patch

import sh27_release as release
import sh27_release_evidence as evidence


def parity_report() -> dict:
    names = ("small_single_file", "many_files", "large_functions", "control_flow", "startup_file_allocation")
    tools = ("openc", "msvc", "clang", "dmd", "ldc")
    return {
        "schema": "openc.sh27.production_comparators.v1", "status": "PASS_PARITY",
        "tools": {"openc": {"sha256": "b"*64}}, "corpus": {"sha256": "c"*64},
        "missing_tools": [], "checks": {"all_passed": True,
            "version_pin_checks": {tool: True for tool in tools[1:]}},
        "ratios": {name: {"openc_to_" + tool: .8 for tool in tools[1:]} for name in names},
        "lanes": {name: {"compilers": {tool: {"samples": [{"passed": True} for _ in range(20)]}
                                      for tool in tools}} for name in names},
    }


class ReleaseProofTests(unittest.TestCase):
    def test_metadata_only_source_bridge_rejects_changed_functional_inputs(self):
        with patch.object(evidence.subprocess, "check_output", return_value=""):
            evidence.verify_functional_source("a"*40, "b"*40)
        with patch.object(evidence.subprocess, "check_output", return_value="OpenC-1.0/compiler/selfhost/source/backend.p\n"):
            with self.assertRaisesRegex(ValueError, "functional inputs differ"):
                evidence.verify_functional_source("a"*40, "b"*40)
        with self.assertRaisesRegex(ValueError, "source commit is invalid"):
            evidence.verify_functional_source("bad", "b"*40)

    def test_all_twenty_cells_and_sample_counts(self):
        report = parity_report()
        evidence.validate_production(report, "b"*64, "c"*64)
        variants = []
        bad = copy.deepcopy(report)
        bad["ratios"]["large_functions"]["openc_to_dmd"] = 1.251
        variants.append(bad)
        bad = copy.deepcopy(report)
        bad["lanes"]["many_files"]["compilers"]["openc"]["samples"].pop()
        variants.append(bad)
        bad = copy.deepcopy(report)
        bad["checks"]["version_pin_checks"]["dmd"] = False
        variants.append(bad)
        bad = copy.deepcopy(report)
        bad["ratios"]["large_functions"]["openc_to_dmd"] = True
        variants.append(bad)
        bad = copy.deepcopy(report)
        bad["missing_tools"] = ["ldc"]
        variants.append(bad)
        for bad in variants:
            with self.subTest(report=bad), self.assertRaises(ValueError):
                evidence.validate_production(bad, "b"*64, "c"*64)

    def test_wrong_compiler_or_corpus_rejected(self):
        for compiler, corpus in (("d"*64, "c"*64), ("b"*64, "d"*64)):
            with self.assertRaises(ValueError):
                evidence.validate_production(parity_report(), compiler, corpus)

    def test_scaling_requires_complete_cells_and_five_samples(self):
        report = parity_report()
        names = set(report["ratios"])
        for lane in report["lanes"].values():
            for cell in lane["compilers"].values():
                cell["samples"] = cell["samples"][:5]
        evidence.validate_scaling(report, "b"*64, "c"*64, names)
        report["lanes"]["large_functions"]["compilers"]["dmd"]["samples"].pop()
        with self.assertRaisesRegex(ValueError, "five passing"):
            evidence.validate_scaling(report, "b"*64, "c"*64, names)

    def test_stream_preserves_binary_bytes(self):
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / "stream.bin"
            evidence.stream_download([sys.executable, "-c",
                "import sys;sys.stdout.buffer.write(bytes(range(256))*8)"], target, 2048, 5)
            self.assertEqual(target.read_bytes(), bytes(range(256))*8)

    def test_stream_stops_at_byte_limit(self):
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / "stream.bin"
            with self.assertRaisesRegex(ValueError, "byte budget"):
                evidence.stream_download([sys.executable, "-c",
                    "import sys;sys.stdout.buffer.write(b'x'*1000000)"], target, 4, 5)
            self.assertLessEqual(target.stat().st_size, 4)

    def test_stream_detects_truncation_and_timeout(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(ValueError):
                evidence.stream_download([sys.executable, "-c", "print('x')"],
                    Path(folder) / "short.bin", 16, 5)
            with self.assertRaises(ValueError):
                evidence.stream_download([sys.executable, "-c", "import time;time.sleep(10)"],
                    Path(folder) / "timeout.bin", 1, .1)


class PublicationSetTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / "OpenC-1.0"
        self.root.mkdir()
        (self.root / "VERSION").write_text("1.0.1\n")
        for name in ("CORPUS.json", "FUNCTION_SCALE.json", "FILE_SCALE.json"):
            path = self.root / "benchmarks/sh27" / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("{}\n")
        self.intent = {
            "schema": "openc.github_release_intent.v2", "version": "1.0.1", "tag": "v1.0.1",
            "status": "CANDIDATE_RELEASE_READY", "release_scope": "windows_x86_64_hosted",
            "expected_compiler_sha256": "b"*64,
            "qualification": ".github/release-evidence/v1.0.1/qualification.json",
            "bootstrap": {"path": ".github/bootstrap/openc-stage0.exe", "sha256": release.BOOTSTRAP_SHA},
        }
        qualification = {"compiler_sha256": "b"*64, "compiler_source_commit": "a"*40}
        for key, name in (("corpus_sha256", "CORPUS.json"),
                          ("function_scale_sha256", "FUNCTION_SCALE.json"),
                          ("file_scale_sha256", "FILE_SCALE.json")):
            qualification[key] = release.sha256(self.root / "benchmarks/sh27" / name)
        release.write_json(self.base / self.intent["qualification"], qualification)
        self.intent_path = self.base / "intent.json"
        release.write_json(self.intent_path, self.intent)

    def assets(self) -> Path:
        for _, relative, _, _ in release.DIRECT_ASSETS:
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(relative + "\n")
        native = self.base / "native"
        native.mkdir()
        names = ("source-a.zip", "standalone-a.zip", "relocated-OpenC-vscode-1.0.1-a.vsix",
                 "native-release-result.json", "relocated-finalization-audit.json",
                 "relocated-conformance.json", "relocated-contract-audit.json")
        for name in names:
            (native / name).write_bytes((name + "\n").encode())
        raw = self.base / "evidence"
        raw.mkdir()
        (raw / "qualification.json").write_text('{"test_fixture":true}\n')
        first, second = self.base / "a", self.base / "b"
        for target in (first, second):
            release.assemble(self.root, native, raw, target, self.intent, "a"*40)
        self.assertEqual(release.verify_assets(first, self.intent, "a"*40),
                         release.verify_assets(second, self.intent, "a"*40))
        return first

    def test_local_raw_report_digest_cannot_be_relabelled(self):
        import hashlib
        path = self.base / ".github/release-evidence/v1.0.1/local-verification.zip"
        path.parent.mkdir(parents=True, exist_ok=True)
        payload = b'{"raw":"verified"}\n'
        summary = {"schema": "openc.sh27.local_verification.v1", "status": "PASS_LOCAL_GATES",
            "compiler_sha256": "b"*64, "checks": {key: True for key in release.LOCAL_CHECKS},
            "files": {"raw.json": {"bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()}}}
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("SUMMARY.json", json.dumps(summary))
            archive.writestr("raw.json", payload)
        qualification = {"compiler_sha256": "b"*64, "local_verification": {
            "path": path.relative_to(self.base).as_posix(), "bytes": path.stat().st_size,
            "sha256": release.sha256(path)}}
        evidence = self.base / "verified"
        evidence.mkdir()
        release.retain_local_verification(self.root, qualification, evidence)
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("SUMMARY.json", json.dumps(summary))
            archive.writestr("raw.json", b'x'*len(payload))
        qualification["local_verification"].update(bytes=path.stat().st_size, sha256=release.sha256(path))
        with self.assertRaisesRegex(ValueError, "report digest differs"):
            release.retain_local_verification(self.root, qualification, evidence)

    def test_sixteen_deterministic_assets_and_nonrecursive_checksums(self):
        assets = self.assets()
        self.assertEqual(len(release.directory_snapshot(assets)), 16)
        record = release.load_json(assets / release.RECORD)
        self.assertNotIn(release.RECORD, {entry["path"] for entry in record["artifacts"]})
        self.assertIn(release.SUMS, {entry["path"] for entry in record["artifacts"]})
        self.assertFalse(record["released"])

    def test_publication_gates_fit_the_canonical_release_schema(self):
        record = release.load_json(self.assets() / release.RECORD)
        schema = release.load_json(Path(__file__).resolve().parents[2] /
                                   "OpenC-1.0/schemas/RELEASE_RECORD.schema.json")
        pattern = schema["properties"]["gates"]["items"]["properties"]["id"]["pattern"]
        self.assertTrue(all(re.fullmatch(pattern, gate["id"]) for gate in record["gates"]))
        self.assertIsNone(re.fullmatch(pattern, "G0"))
        self.assertIsNone(re.fullmatch(pattern, "G30"))

    def test_only_the_declared_release_schema_gate_extension_is_allowed(self):
        schema = {"properties": {"gates": {"items": {"properties": {
            "id": {"pattern": "^G([1-9]|1[0-9])$"}}}}}, "unrelated": "preserved"}
        upgraded = copy.deepcopy(schema)
        upgraded["properties"]["gates"]["items"]["properties"]["id"]["pattern"] = "^G([1-9]|1[0-9]|2[0-9])$"
        path = self.root / "schemas/RELEASE_RECORD.schema.json"
        release.write_json(path, upgraded)
        with patch.object(release, "git", return_value=json.dumps(schema)):
            release.verify_release_schema_upgrade(self.root, "a"*40)
            upgraded["unrelated"] = "tampered"
            release.write_json(path, upgraded)
            with self.assertRaisesRegex(ValueError, "beyond the declared gate range"):
                release.verify_release_schema_upgrade(self.root, "a"*40)

    def test_tampering_or_extra_asset_fails(self):
        assets = self.assets()
        target = assets / "OpenC-vscode-1.0.1.vsix"
        target.write_bytes(b"tampered")
        with self.assertRaises(ValueError):
            release.verify_assets(assets, self.intent, "a"*40)

    def test_bad_checksum_coverage_fails(self):
        assets = self.assets()
        (assets / release.SUMS).write_text("")
        with self.assertRaises(ValueError):
            release.verify_assets(assets, self.intent, "a"*40)

    def test_missing_gate_or_premature_authorization_fails(self):
        assets = self.assets()
        record = release.load_json(assets / release.RECORD)
        record["gates"].pop()
        release.write_json(assets / release.RECORD, record)
        with self.assertRaises(ValueError):
            release.verify_assets(assets, self.intent, "a"*40)
        record["gates"].append({"id": "G29", "status": "PASS"})
        record["authorization"]["status"] = "AUTHORIZED"
        release.write_json(assets / release.RECORD, record)
        with self.assertRaises(ValueError):
            release.verify_assets(assets, self.intent, "a"*40)

    def test_candidate_does_not_authorize_publication(self):
        with patch.object(release, "git", return_value=""):
            release.validate_intent(self.root, self.intent_path)
            with self.assertRaisesRegex(ValueError, "owner authorization"):
                release.validate_intent(self.root, self.intent_path, publish=True)

    def test_old_tag_and_post_certificate_code_changes_rejected(self):
        bad = {**self.intent, "version": "1.0.0", "tag": "v1.0.0"}
        release.write_json(self.intent_path, bad)
        with self.assertRaisesRegex(ValueError, "only the new"):
            release.validate_intent(self.root, self.intent_path)
        release.write_json(self.intent_path, self.intent)
        with patch.object(release, "git", return_value="OpenC-1.0/compiler/selfhost/source/ir.p"):
            with self.assertRaisesRegex(ValueError, "functional inputs"):
                release.validate_intent(self.root, self.intent_path)


if __name__ == "__main__":
    unittest.main()
