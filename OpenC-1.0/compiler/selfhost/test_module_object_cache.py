"""Falsify automatic module reuse, cache publication, and invalidation.

Python is the test harness only; each build/cache/link is one native OpenC
compiler invocation. Usage: python test_module_object_cache.py COMPILER
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import shutil
import re
import struct
import subprocess
import sys
import tempfile

from test_module_coff_set import ALPHA, BETA
from test_module_selected_lowering import artifact, load_set


def cached(compiler: Path, root: Path, name: str, cache: Path | None = None,
           project: Path | None = None):
    prefix = root / name
    command = [str(compiler), "artifact", f"--project={project or (root / 'openc.project.json')}",
               "--kind=module-coff-set", f"--output={prefix}",
               f"--linked-exe={prefix}.exe", f"--timings={prefix}.timings.json",
               f"--cache-prefix={cache or (root / 'cache' / 'objects')}"]
    return subprocess.run(command, capture_output=True, text=True, timeout=60)


def stats(root: Path, name: str):
    timings = json.loads((root / (name + ".timings.json")).read_text())
    assert timings["status"] == "PASS", timings
    return timings


def exact(compiler: Path, root: Path, name: str, exit_code: int):
    clean = artifact(compiler, root, name + "-clean")
    assert clean.returncode == 0, clean.stdout + clean.stderr
    assert (root / (name + ".exe")).read_bytes() == (root / (name + "-clean.exe")).read_bytes()
    assert subprocess.run([str(root / (name + ".exe"))], timeout=10).returncode == exit_code
    cached_set = load_set(root, name)
    clean_set = load_set(root, name + "-clean")
    assert {k: v["sha256"] for k, v in cached_set.items()} == {k: v["sha256"] for k, v in clean_set.items()}


def main():
    compiler = Path(sys.argv[1]).resolve(strict=True)
    with tempfile.TemporaryDirectory(prefix="oc-cache-") as temporary:
        root = Path(temporary)
        (root / "cache").mkdir()
        (root / "alpha.p").write_text(ALPHA)
        (root / "beta.p").write_text(BETA)
        (root / "gamma.p").write_text("i32 unrelated() { return 9; }\n")
        project = {"name": "automatic-cache", "version": "0.1.0", "edition": "OpenC 1.0",
                   "profile": "standard", "target": "windows-x86_64",
                   "modules": {"alpha": ["alpha.p"], "beta": ["beta.p"], "gamma": ["gamma.p"]}}
        (root / "openc.project.json").write_text(json.dumps(project))
        cold = cached(compiler, root, "cold")
        assert cold.returncode == 0, cold.stdout + cold.stderr
        c = stats(root, "cold")
        assert c["object_cache"] == {"hits": 0, "misses": 3, "publish_failures": 0, "validation_skipped": False}, c
        assert c["work"]["functions"] == 3, c
        # Independent SHA-256 oracle proves the accelerated compiler identity
        # and complete input-key construction, not merely self-consistency.
        project_text = (root / "openc.project.json").read_text()
        canonical = "openc-module-cache-v2:windows-x86_64-llp64:stable-coff:serial\n" + project_text
        canonical += hashlib.sha256(compiler.read_bytes()).hexdigest()
        initial_sources = {module: (root / (module + ".p")).read_bytes().decode()
                           for module in ("alpha", "beta", "gamma")}
        interface_hashes = {}
        for module, source in initial_sources.items():
            projection = re.sub(r"\{.*\}", "{}\n", source, flags=re.DOTALL)
            interface_bytes = (str(len(module.encode())) + ":" + module + "\n"
                               + hashlib.sha256(projection.encode()).hexdigest() + "\n").encode()
            interface_hashes[module] = hashlib.sha256(interface_bytes).hexdigest()
        base_hash = hashlib.sha256(canonical.encode()).hexdigest()
        dependencies = {"alpha": {"alpha"}, "beta": {"alpha", "beta"},
                        "gamma": {"gamma"}}
        for module, source in initial_sources.items():
            content_hash = hashlib.sha256((str(len(module.encode())) + ":" + module + "\n" + str(len(source.encode())) + ":" + source).encode()).hexdigest()
            dependent_interfaces = "".join(interface_hashes[name] for name in initial_sources
                                            if name in dependencies[module])
            key = hashlib.sha256((base_hash + content_hash + dependent_interfaces).encode()).hexdigest()
            record = root / "cache" / ("objects.k." + key + ".record")
            assert record.is_file(), (module, key)
            assert record.read_bytes()[:64].decode() == key
        project_bytes = (root / "openc.project.json").read_bytes()
        project_root_bytes = str(root).encode()
        project_input = (b"openc-project-validation-v1:windows-x86_64-llp64:stable-coff:serial\n"
                         + str(len(project_root_bytes)).encode() + b":" + project_root_bytes
                         + str(len(project_bytes)).encode() + b":" + project_bytes
                         + hashlib.sha256(compiler.read_bytes()).hexdigest().encode())
        for module, source in initial_sources.items():
            name_bytes, source_bytes = module.encode(), source.encode()
            project_input += (str(len(name_bytes)).encode() + b":" + name_bytes
                              + str(len(source_bytes)).encode() + b":" + source_bytes)
        project_key = hashlib.sha256(project_input).hexdigest()
        project_record = root / "cache" / ("objects.p." + project_key + ".record")
        assert project_record.is_file(), project_key
        record_bytes = project_record.read_bytes()
        assert record_bytes[:9] == b"OCVC0001\n" and record_bytes[9:73].decode() == project_key
        assert record_bytes[-64:].decode() == hashlib.sha256(record_bytes[:-64]).hexdigest()
        exact(compiler, root, "cold", 7)

        warm = cached(compiler, root, "warm")
        assert warm.returncode == 0, warm.stdout + warm.stderr
        w = stats(root, "warm")
        assert w["object_cache"]["hits"] == 3 and w["object_cache"]["misses"] == 0, w
        assert w["object_cache"]["validation_skipped"], w
        assert w["work"]["functions"] == 0, w
        assert w["work"]["syntax_nodes"] == 0, w
        assert w["module_selection"] == {"sources_lowered": 0, "sources_validation_only": 0}, w
        exact(compiler, root, "warm", 7)

        # A broken or oversized whole-project validation certificate is never
        # authority to skip semantics; ordinary validated object hits remain.
        project_records = list((root / "cache").glob("objects.p.*.record"))
        assert len(project_records) == 1, project_records
        snapshot = project_records[0]
        original = snapshot.read_bytes()
        snapshot.write_bytes(original[:-1] + b"0" if original[-1:] != b"0" else original[:-1] + b"1")
        damaged_snapshot = cached(compiler, root, "damaged-snapshot")
        assert damaged_snapshot.returncode == 0, damaged_snapshot.stdout + damaged_snapshot.stderr
        ds = stats(root, "damaged-snapshot")
        assert ds["object_cache"]["hits"] == 3 and not ds["object_cache"]["validation_skipped"], ds
        exact(compiler, root, "damaged-snapshot", 7)
        with snapshot.open("wb") as stream:
            stream.truncate(128 * 1024 * 1024)
        oversized_snapshot = cached(compiler, root, "oversized-snapshot")
        assert oversized_snapshot.returncode == 0, oversized_snapshot.stdout + oversized_snapshot.stderr
        os = stats(root, "oversized-snapshot")
        assert os["object_cache"]["hits"] == 3 and not os["object_cache"]["validation_skipped"], os
        exact(compiler, root, "oversized-snapshot", 7)

        (root / "alpha.p").write_text(ALPHA.replace("left + right", "left + right + 1"))
        edit = cached(compiler, root, "body-edit")
        assert edit.returncode == 0, edit.stdout + edit.stderr
        e = stats(root, "body-edit")
        assert e["object_cache"]["hits"] == 2 and e["object_cache"]["misses"] == 1, e
        assert not e["object_cache"]["validation_skipped"], e
        assert e["work"]["functions"] == 1, e
        exact(compiler, root, "body-edit", 8)

        # Same-width parameter rename changes the external stable declaration
        # identity. The owner and dependent rebuild; unrelated gamma stays hot.
        (root / "alpha.p").write_text(ALPHA.replace("left", "arg1"))
        api = cached(compiler, root, "api-edit")
        assert api.returncode == 0, api.stdout + api.stderr
        a = stats(root, "api-edit")
        assert a["object_cache"]["hits"] == 1 and a["object_cache"]["misses"] == 2, a
        assert not a["object_cache"]["validation_skipped"], a
        exact(compiler, root, "api-edit", 7)

        # Corrupt the currently published beta object, not an obsolete entry.
        beta_hash = load_set(root, "api-edit")["beta"]["sha256"]
        damaged = root / "cache" / ("objects.o." + beta_hash + ".obj")
        damaged.write_bytes(b"broken")
        corruption = cached(compiler, root, "corrupt-object")
        assert corruption.returncode == 0, corruption.stdout + corruption.stderr
        r = stats(root, "corrupt-object")
        assert r["object_cache"]["hits"] == 2 and r["object_cache"]["misses"] == 1, r
        exact(compiler, root, "corrupt-object", 7)

        # Metadata is bounded BEFORE allocation and never accepted by length
        # alone. A large sparse record and a wrong embedded input key are misses.
        records = list((root / "cache").glob("objects.k.*.record"))
        active = [p for p in records if p.read_bytes()[65:129].decode() == beta_hash]
        for record in active:
            with record.open("wb") as stream:
                stream.truncate(128 * 1024 * 1024)
        for project_record in (root / "cache").glob("objects.p.*.record"):
            project_record.unlink()
        oversized = cached(compiler, root, "oversized-record")
        assert oversized.returncode == 0, oversized.stdout + oversized.stderr
        assert stats(root, "oversized-record")["object_cache"]["misses"] == 1
        exact(compiler, root, "oversized-record", 7)
        for record in active:
            data = record.read_bytes()
            record.write_bytes(b"f" * 64 + data[64:])
        for project_record in (root / "cache").glob("objects.p.*.record"):
            project_record.unlink()
        wrong_key = cached(compiler, root, "wrong-key")
        assert wrong_key.returncode == 0, wrong_key.stdout + wrong_key.stderr
        assert stats(root, "wrong-key")["object_cache"]["misses"] == 1
        exact(compiler, root, "wrong-key", 7)

        # A different executable's identity never shares compiled-object keys,
        # even when it runs the same code (PE loader permits an overlay byte).
        alternate = root / "alternate.exe"
        shutil.copyfile(compiler, alternate)
        with alternate.open("ab") as stream:
            stream.write(b"\0")
        identity = cached(alternate, root, "compiler-identity")
        assert identity.returncode == 0, identity.stdout + identity.stderr
        assert stats(root, "compiler-identity")["object_cache"]["misses"] == 3
        exact(compiler, root, "compiler-identity", 7)

        # Concurrent cold writers use distinct outputs but share the cache.
        # Every resulting object and PE must equal the clean build; the next
        # reader sees complete records, not partially published bytes.
        concurrent_cache = root / "cache" / "concurrent"
        with ThreadPoolExecutor(max_workers=4) as pool:
            runs = list(pool.map(lambda i: cached(compiler, root, f"parallel-{i}", concurrent_cache), range(4)))
        for i, run in enumerate(runs):
            assert run.returncode == 0, run.stdout + run.stderr
            exact(compiler, root, f"parallel-{i}", 7)
        after = cached(compiler, root, "after-parallel", concurrent_cache)
        assert after.returncode == 0, after.stdout + after.stderr
        assert stats(root, "after-parallel")["object_cache"]["hits"] == 3

        # An unavailable cache is a performance failure, not a build failure.
        unavailable = cached(compiler, root, "unavailable", root / "missing" / "cache")
        assert unavailable.returncode == 0, unavailable.stdout + unavailable.stderr
        assert stats(root, "unavailable")["object_cache"]["publish_failures"] == 3
        exact(compiler, root, "unavailable", 7)

        # Cached code can never conceal a new rejection in another module.
        (root / "beta.p").write_text('import alpha;\ni32 main() { return "bad"; }\n')
        invalid = cached(compiler, root, "invalid")
        clean_invalid = artifact(compiler, root, "invalid-clean")
        assert invalid.returncode != 0 and clean_invalid.returncode != 0
        assert invalid.stdout == clean_invalid.stdout and invalid.stderr == clean_invalid.stderr
        assert not (root / "invalid.modules.json").exists()

        # The resolver accepts qualified cross-module references even without
        # an import statement. A -> B -> entry must transitively invalidate,
        # while unrelated gamma remains an authenticated object hit.
        transitive = root / "transitive"
        transitive.mkdir()
        (transitive / "cache").mkdir()
        (transitive / "alpha.p").write_text(ALPHA)
        (transitive / "beta.p").write_text(
            "export i32 mid() { return alpha.add(2, 3); }\n")
        (transitive / "gamma.p").write_text("i32 unrelated() { return 9; }\n")
        (transitive / "zapp.p").write_text("i32 main() { return beta.mid(); }\n")
        transitive_project = dict(project)
        transitive_project["modules"] = {"alpha": ["alpha.p"], "beta": ["beta.p"],
                                         "gamma": ["gamma.p"], "zapp": ["zapp.p"]}
        (transitive / "openc.project.json").write_text(json.dumps(transitive_project))
        first = cached(compiler, transitive, "first")
        assert first.returncode == 0, first.stdout + first.stderr
        assert stats(transitive, "first")["object_cache"]["misses"] == 4
        exact(compiler, transitive, "first", 5)
        same = cached(compiler, transitive, "same")
        assert same.returncode == 0, same.stdout + same.stderr
        assert stats(transitive, "same")["object_cache"]["validation_skipped"]
        (transitive / "alpha.p").write_text(ALPHA.replace("left", "arg1"))
        changed = cached(compiler, transitive, "transitive-api")
        assert changed.returncode == 0, changed.stdout + changed.stderr
        transitive_stats = stats(transitive, "transitive-api")["object_cache"]
        assert transitive_stats["hits"] == 1 and transitive_stats["misses"] == 3, transitive_stats
        assert not transitive_stats["validation_skipped"]
        exact(compiler, transitive, "transitive-api", 5)
        first_set = load_set(transitive, "first")
        changed_set = load_set(transitive, "transitive-api")
        assert first_set["gamma"]["sha256"] == changed_set["gamma"]["sha256"]

        # A retained four-module file/audit application exercises real OpenC
        # file IO, text processing, stdout and the shared 96-byte runtime data
        # area. Work on a copy so the checked-in project remains untouched.
        suite_root = Path(__file__).resolve().parents[2]
        suite = json.loads((suite_root / "benchmarks/sh27/representative/SUITE.json").read_text())
        medium = next(item for item in suite["workloads"] if item["id"] == "medium_audit")
        source_project = suite_root / medium["project"]
        medium_dir = root / "medium-project"
        shutil.copytree(source_project.parent, medium_dir)
        medium_project = medium_dir / "openc.project.json"
        medium_cache = root / "cache" / "medium"
        medium_cold = cached(compiler, root, "medium-cold", medium_cache, medium_project)
        assert medium_cold.returncode == 0, medium_cold.stdout + medium_cold.stderr
        assert stats(root, "medium-cold")["object_cache"]["misses"] == 4
        medium_warm = cached(compiler, root, "medium-warm", medium_cache, medium_project)
        assert medium_warm.returncode == 0, medium_warm.stdout + medium_warm.stderr
        medium_stats = stats(root, "medium-warm")
        assert medium_stats["object_cache"]["hits"] == 4
        assert medium_stats["object_cache"]["validation_skipped"]
        assert medium_stats["work"]["syntax_nodes"] == 0
        medium_clean = artifact(compiler, medium_dir, "medium-clean")
        assert medium_clean.returncode == 0, medium_clean.stdout + medium_clean.stderr
        assert (root / "medium-cold.exe").read_bytes() == (root / "medium-warm.exe").read_bytes()
        assert (root / "medium-warm.exe").read_bytes() == (medium_dir / "medium-clean.exe").read_bytes()
        assert {k: v["sha256"] for k, v in load_set(root, "medium-warm").items()} == {
            k: v["sha256"] for k, v in load_set(medium_dir, "medium-clean").items()}
        medium_run = subprocess.run([str(root / "medium-warm.exe")], cwd=medium_dir,
                                    capture_output=True, text=True, timeout=10)
        assert (medium_run.returncode, medium_run.stdout, medium_run.stderr) == (
            0, medium["expected_stdout_utf8"], medium["expected_stderr_utf8"])
        # The direct linker must reject an authenticated but malformed COFF
        # relocation that addresses beyond the shared 96-byte runtime area.
        entries = load_set(root, "medium-cold")
        main_object = bytearray(Path(entries["audit.main"]["object"]).read_bytes())
        raw = struct.unpack_from("<I", main_object, 40)[0]
        reloc = struct.unpack_from("<I", main_object, 44)[0]
        count = struct.unpack_from("<H", main_object, 52)[0]
        damaged = False
        for index in range(count):
            offset, symbol, _ = struct.unpack_from("<IIH", main_object, reloc + index * 10)
            if symbol == 2:
                struct.pack_into("<I", main_object, raw + offset, 96)
                damaged = True
                break
        assert damaged, "representative main must exercise shared runtime data"
        bad_object = root / "medium-bad-data.obj"
        bad_object.write_bytes(main_object)
        project_snapshots = list((root / "cache").glob("medium.p.*.record"))
        assert len(project_snapshots) == 1
        entry = project_snapshots[0].read_bytes()[73:144].decode()
        bad_output = root / "medium-bad-data.exe"
        command = [str(compiler), "module-coff-link", "--entry=" + entry,
                   "--output=" + str(bad_output)]
        for module, item in entries.items():
            object_path = bad_object if module == "audit.main" else Path(item["object"])
            digest = hashlib.sha256(object_path.read_bytes()).hexdigest()
            command.extend(["--object=" + str(object_path), "--sha256=" + digest])
        bad_link = subprocess.run(command, capture_output=True, text=True, timeout=30)
        assert bad_link.returncode != 0 and "OPENC-COFF-LINK-RELOC" in bad_link.stderr
        assert not bad_output.exists()
        edit = medium["edit"]
        score = medium_dir / edit["path"]
        # Preserve the checked-in LF layout: a Windows text rewrite would
        # turn the whole source into CRLF and correctly change its interface
        # projection, obscuring the body-only invalidation assertion.
        score.write_bytes(score.read_bytes().replace(
            edit["old"].encode(), edit["new"].encode(), 1))
        medium_edit = cached(compiler, root, "medium-edit", medium_cache, medium_project)
        assert medium_edit.returncode == 0, medium_edit.stdout + medium_edit.stderr
        edit_stats = stats(root, "medium-edit")["object_cache"]
        assert edit_stats["hits"] == 3 and edit_stats["misses"] == 1, edit_stats
        assert not edit_stats["validation_skipped"]
        edit_clean = artifact(compiler, medium_dir, "medium-edit-clean")
        assert edit_clean.returncode == 0, edit_clean.stdout + edit_clean.stderr
        assert (root / "medium-edit.exe").read_bytes() == (medium_dir / "medium-edit-clean.exe").read_bytes()
        assert {k: v["sha256"] for k, v in load_set(root, "medium-edit").items()} == {
            k: v["sha256"] for k, v in load_set(medium_dir, "medium-edit-clean").items()}
        medium_edit_run = subprocess.run([str(root / "medium-edit.exe")], cwd=medium_dir,
                                         capture_output=True, text=True, timeout=10)
        assert (medium_edit_run.returncode, medium_edit_run.stdout, medium_edit_run.stderr) == (
            0, edit["expected_stdout_utf8"], medium["expected_stderr_utf8"])
        print("automatic module cache: validated no-op, selective transitive API/body invalidation, real four-module file app, corruption/size/key/identity recovery, concurrent publication, unavailable storage and full diagnostics passed")


if __name__ == "__main__":
    main()
