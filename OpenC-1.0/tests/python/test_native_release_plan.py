import importlib.util
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/verify_native_release_plan.py"
SPEC = importlib.util.spec_from_file_location("verify_native_release_plan", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class NativeReleaseSources(unittest.TestCase):
    def test_archive_hashes_membership_and_nested_d_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "test.zip"
            (root / "main.p").write_bytes(b"new source")

            def package(name, content, expected, extra=False, standalone=False):
                manifest = "STANDALONE-MANIFEST.sha256" if standalone else "MANIFEST.sha256"
                with zipfile.ZipFile(archive, "w") as output:
                    output.writestr("OpenC-test/" + name, content)
                    output.writestr("OpenC-test/" + manifest,
                        hashlib.sha256(expected).hexdigest() + "  " + name + "\n")
                    if extra:
                        output.writestr("OpenC-test/unlisted.p", b"unlisted")

            package("main.p", b"new source", b"new source")
            result = MODULE.verify_archive(archive, "OpenC-test/", standalone=False,
                source_root=root, source_entries={"main.p", "MANIFEST.sha256"})
            self.assertEqual(result["manifest_entries"], 1)
            (root / "main.p").write_bytes(b"different authored source")
            with self.assertRaisesRegex(ValueError, "authored input"):
                MODULE.verify_archive(archive, "OpenC-test/", standalone=False, source_root=root)
            package("main.p", b"new source", b"old source")
            with self.assertRaisesRegex(ValueError, "checksum differs"):
                MODULE.verify_archive(archive, "OpenC-test/", standalone=False)
            package("main.p", b"new source", b"new source", extra=True)
            with self.assertRaisesRegex(ValueError, "every member"):
                MODULE.verify_archive(archive, "OpenC-test/", standalone=False)
            package("nested/compiler/dub.json", b"{}", b"{}", standalone=True)
            with self.assertRaisesRegex(ValueError, "historical toolchain"):
                MODULE.verify_archive(archive, "OpenC-test/", standalone=True)

    def test_added_compiler_source_requires_release_registration(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            compiler = root / "compiler/selfhost"
            (compiler / "source").mkdir(parents=True)
            (compiler / "source/main.p").write_text("i32 main() { return 0; }\n")
            project = compiler / "openc.project.json"
            project.write_text(json.dumps({"modules": {"main": ["source/main.p"]}}))
            contract = root / "SOURCE_COMPLETENESS_CONTRACT.json"
            contract.write_text(json.dumps({"groups": {"compiler": ["compiler/selfhost/source/main.p"]}}))
            plan = root / "plan.tsv"
            plan.write_text("openc.native_release_plan.v1\t1\t1\ncompiler/selfhost/source/main.p\n")
            self.assertEqual(MODULE.verify(root, plan)["compiler_sources"], 1)
            (compiler / "source/cache.p").write_text("bool cache_enabled() { return true; }\n")
            project.write_text(json.dumps({"modules": {"main": ["source/main.p", "source/cache.p"]}}))
            with self.assertRaisesRegex(ValueError, "cache.p"):
                MODULE.verify(root, plan)
            plan.write_text("openc.native_release_plan.v1\t1\t2\ncompiler/selfhost/source/main.p\ncompiler/selfhost/source/cache.p\n")
            with self.assertRaisesRegex(ValueError, "source completeness contract"):
                MODULE.verify(root, plan)
            contract.write_text(json.dumps({"groups": {"compiler": ["compiler/selfhost/source/main.p", "compiler/selfhost/source/cache.p"]}}))
            self.assertEqual(MODULE.verify(root, plan)["compiler_sources"], 2)


if __name__ == "__main__":
    unittest.main()
