#!/usr/bin/env python3
"""Fast request and source-identity tests; no compiler is launched."""

from __future__ import annotations

from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import benchmark_sh27_batch_ci as batch


BASELINE = "1" * 40
FIRST = "2" * 40
SECOND = "3" * 40


class ResolveRequestTests(unittest.TestCase):
    def test_requires_frozen_full_sha_and_one_to_three_refs(self) -> None:
        with self.assertRaisesRegex(ValueError, "full lowercase"):
            batch.resolve_requests("1234567", ["codex/sh27-one"])
        with self.assertRaisesRegex(ValueError, "one to three"):
            batch.resolve_requests(BASELINE, [])
        with self.assertRaisesRegex(ValueError, "one to three"):
            batch.resolve_requests(BASELINE, ["a", "b", "c", "d"])

    def test_rejects_untrusted_or_duplicate_refs_before_checkout(self) -> None:
        with patch.object(batch, "git", return_value=BASELINE) as git:
            with self.assertRaisesRegex(ValueError, "untrusted"):
                batch.resolve_requests(BASELINE, ["refs/pull/1/head"])
            self.assertEqual(git.call_count, 1)
        with self.assertRaisesRegex(ValueError, "duplicate candidate"):
            batch.resolve_requests(BASELINE, ["codex/sh27-one", "codex/sh27-one"])

    def test_resolves_remote_branches_to_unique_descendant_commits(self) -> None:
        answers = iter([BASELINE, "", FIRST, "", SECOND])
        with patch.object(batch, "git", side_effect=lambda *args: next(answers)) as git:
            with patch.object(batch.subprocess, "run") as run:
                run.return_value.returncode = 0
                baseline, candidates = batch.resolve_requests(
                    BASELINE, ["codex/sh27-one", "codex/sh27-two"]
                )
        self.assertEqual(baseline, BASELINE)
        self.assertEqual([record["commit"] for record in candidates], [FIRST, SECOND])
        self.assertEqual(candidates[0]["remote_ref"],
                         "refs/remotes/origin/codex/sh27-one")
        self.assertEqual(run.call_count, 2)
        self.assertEqual(git.call_count, 5)

    def test_rejects_non_descendant(self) -> None:
        answers = iter([BASELINE, "", FIRST])
        with patch.object(batch, "git", side_effect=lambda *args: next(answers)):
            with patch.object(batch.subprocess, "run") as run:
                run.return_value.returncode = 1
                with self.assertRaisesRegex(ValueError, "not descended"):
                    batch.resolve_requests(BASELINE, ["codex/sh27-one"])

    def test_rejects_missing_remote_ref(self) -> None:
        def lookup(*arguments: str) -> str:
            if arguments[0] == "rev-parse" and "refs/remotes" in arguments[-1]:
                raise subprocess.CalledProcessError(1, ["git", *arguments])
            return BASELINE if arguments[0] == "rev-parse" else ""

        with patch.object(batch, "git", side_effect=lookup):
            with self.assertRaises(subprocess.CalledProcessError):
                batch.resolve_requests(BASELINE, ["codex/sh27-missing"])


class SourceIdentityTests(unittest.TestCase):
    def test_manifest_rejects_empty_source_tree(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            project = root / "compiler/selfhost/openc.project.json"
            project.parent.mkdir(parents=True)
            project.write_text("{}", encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "missing compiler source"):
                batch.source_manifest(root)

    def test_manifest_changes_when_source_bytes_change(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "compiler/selfhost/source/main.p"
            source.parent.mkdir(parents=True)
            source.write_text("i32 main() { return 0; }", encoding="utf-8")
            project = root / "compiler/selfhost/openc.project.json"
            project.write_text("{}", encoding="utf-8")
            before = batch.source_manifest(root)
            source.write_text("i32 main() { return 1; }", encoding="utf-8")
            after = batch.source_manifest(root)
        self.assertEqual(before["files"], 2)
        self.assertNotEqual(before["sha256"], after["sha256"])


class StrictBootstrapTests(unittest.TestCase):
    def test_fourth_generation_is_byte_exact_under_256_64_mib(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            compiler = root / "stage3.exe"
            compiler.write_bytes(b"fixed-compiler")
            project_root = root / "project"
            project = project_root / "compiler/selfhost/openc.project.json"
            project.parent.mkdir(parents=True)
            project.write_text("{}", encoding="utf-8")

            def measured(command: list[str], **kwargs: object) -> dict[str, object]:
                output = Path(next(item.split("=", 1)[1] for item in command
                                   if item.startswith("--output=")))
                output.write_bytes(b"fixed-compiler")
                self.assertEqual(kwargs["max_private_bytes"], 256 * batch.MIB)
                self.assertEqual(kwargs["max_working_set_bytes"], 64 * batch.MIB)
                return {"exit_code": 0, "timed_out": False,
                        "memory_limit_exceeded": False,
                        "stdout_truncated": False, "stderr_truncated": False}

            with patch.object(batch, "require_disk_headroom"):
                with patch.object(batch, "run_measured", side_effect=measured):
                    result = batch.strict_fixed_point(
                        "candidate1", project_root, compiler, root / "runs"
                    )
        self.assertTrue(result["passed"])
        self.assertTrue(result["stage3_stage4_byte_exact"])


if __name__ == "__main__":
    unittest.main()
