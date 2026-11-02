"""Bounded retrieval and independent checks for the two SH-27 certificates."""
from __future__ import annotations

import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import threading
import re
import zipfile

from sh26_release import REPOSITORY, api_json, sha256, write_json

MIB = 1024 * 1024
PRODUCTION = "sh27-production-comparators.json"
MODULE_REPORTS = (
    "native-cache.json", "native-cache-retry.json", "frontend-publication.json",
    "frontend-edges.json", "large-coff.json", "source-partition-coff.json",
    "source-partition-cache.json", "project-batch.json", "strict20.json",
    "native-cache-compiler-pairs.json", "native-cache-medium-pairs.json",
    "native-release-result.json", "native-release-manifests.json",
)


def verify_functional_source(base: str, commit: str) -> None:
    """Certificates may differ in release prose/editor records, never code/tests."""
    check(all(re.fullmatch(r"[0-9a-f]{40}", value) for value in (base, commit)),
          "proof source commit is invalid")
    if base == commit:
        return
    paths = ("OpenC-1.0/compiler", "OpenC-1.0/runtime", "OpenC-1.0/standard_library",
             "OpenC-1.0/conformance", "OpenC-1.0/benchmarks/sh27", "OpenC-1.0/tests",
             "OpenC-1.0/standard/core", "OpenC-1.0/schemas", "OpenC-1.0/VERSION",
             "OpenC-1.0/SOURCE_COMPLETENESS_CONTRACT.json",
             "OpenC-1.0/release/SH21_NATIVE_RELEASE_PLAN.tsv",
             ".github/production-toolchain-pins.json", ".github/representative-toolchain-pins.json")
    changed = subprocess.check_output(["git", "diff", "--name-only", base, commit, "--", *paths],
        cwd=Path(__file__).resolve().parents[2], text=True).splitlines()
    unexpected = [name for name in changed if
        name != "OpenC-1.0/tests/SH21_NATIVE_REPOSITORY_AUDIT_PLAN.tsv" and not
        (name.startswith("OpenC-1.0/compiler/selfhost/") and name.endswith(".md"))]
    check(not unexpected, "proof functional inputs differ: " + ", ".join(unexpected))


def check(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def validate_production(report: dict, compiler_hash: str, corpus_hash: str) -> None:
    check(report.get("schema") == "openc.sh27.production_comparators.v1", "wrong parity schema")
    check(report.get("status") == "PASS_PARITY", "parity report did not pass")
    check(report.get("tools", {}).get("openc", {}).get("sha256") == compiler_hash,
          "parity compiler differs from release compiler")
    check(report.get("corpus", {}).get("sha256") == corpus_hash, "original corpus changed")
    check(not report.get("missing_tools"), "parity comparator set is incomplete")
    cells = [ratio for lane in report.get("ratios", {}).values() for ratio in lane.values()]
    check(len(cells) == 20 and all(type(r) in (int, float) and 0 < r <= 1.25 for r in cells),
          "all twenty original parity ceilings must pass")
    check(all(value is True for value in report["checks"].values() if isinstance(value, bool)),
          "parity report contains a failed check")
    check(set(report["checks"].get("version_pin_checks", {})) == {"msvc", "clang", "dmd", "ldc"} and
          all(value is True for value in report["checks"]["version_pin_checks"].values()),
          "comparator version pin failed")
    names = {"small_single_file", "many_files", "large_functions", "control_flow", "startup_file_allocation"}
    check(set(report.get("ratios", {})) == names, "original parity lanes changed")
    for name in names:
        lane = report["lanes"][name]
        check(set(report["ratios"][name]) == {"openc_to_msvc", "openc_to_clang", "openc_to_dmd", "openc_to_ldc"},
              "original comparator ratios changed")
        tools = lane.get("compilers", {})
        check(set(tools) == {"openc", "msvc", "clang", "dmd", "ldc"}, "wrong comparator cells")
        for tool, record in tools.items():
            samples = record.get("samples", [])
            check(len(samples) == 20 and all(s.get("passed") is True for s in samples),
                  f"{name}/{tool} is not twenty passing observations")


def validate_scaling(report: dict, compiler_hash: str, corpus_hash: str, names: set[str]) -> None:
    check(report.get("schema") == "openc.sh27.production_comparators.v1" and
          report.get("status") == "PASS_PARITY", "scaling report did not pass")
    check(report.get("tools", {}).get("openc", {}).get("sha256") == compiler_hash and
          report.get("corpus", {}).get("sha256") == corpus_hash and not report.get("missing_tools"),
          "scaling proof identity differs")
    check(set(report.get("ratios", {})) == names, "scaling lanes differ")
    checks = report.get("checks", {})
    pins = checks.get("version_pin_checks", {})
    check(set(pins) == {"msvc", "clang", "dmd", "ldc"} and all(v is True for v in pins.values()) and
          all(v is True for v in checks.values() if isinstance(v, bool)), "scaling checks or version pins failed")
    for name in names:
        ratios = report["ratios"][name]
        check(set(ratios) == {"openc_to_msvc", "openc_to_clang", "openc_to_dmd", "openc_to_ldc"} and
              all(type(r) in (int, float) and 0 < r <= 1.25 for r in ratios.values()),
              "scaling parity ceiling failed")
        cells = report.get("lanes", {}).get(name, {}).get("compilers", {})
        check(set(cells) == {"openc", "msvc", "clang", "dmd", "ldc"}, "scaling tools differ")
        check(all(len(cell.get("samples", [])) == 5 and
                  all(s.get("passed") is True for s in cell["samples"]) for cell in cells.values()),
              "scaling requires five passing observations per cell")


def validate_modules(reports: dict[str, dict], compiler_hash: str) -> None:
    for name in MODULE_REPORTS:
        report = reports[name]
        check(report.get("status") == "PASS", f"{name} did not pass")
        digest = report.get("compiler_sha256")
        if digest is not None:
            check(digest == compiler_hash, f"{name} uses another compiler")
    stability = reports["strict20.json"]
    check(stability.get("inputs", {}).get("compiler_sha256") == compiler_hash,
          "stability compiler differs")
    check(len(stability.get("lanes", {}).get("native_chain", {}).get("samples", [])) == 20,
          "twenty native generations are required")
    check(len(stability.get("checks", {})) == 13 and all(stability["checks"].values()),
          "strict stability checks failed")
    native = reports["native-release-result.json"]
    check(native.get("hashes", {}).get("compiler") == compiler_hash, "package compiler differs")
    check(len(native.get("checks", {})) == 9 and all(native["checks"].values()),
          "native package checks failed")


def stream_download(command: list[str], target: Path, expected: int, timeout: float = 300) -> None:
    """Stream bytes with a hard size/deadline bound; terminate only our client."""
    check(0 < expected <= 512*MIB, "artifact byte budget is invalid")
    expired = []
    with target.open("xb") as output, subprocess.Popen(command,
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL) as process:
        def stop() -> None:
            expired.append(True)
            try:
                process.kill()
            except ProcessLookupError:
                pass
        timer = threading.Timer(timeout, stop)
        timer.daemon = True
        timer.start()
        try:
            size = 0
            while block := process.stdout.read(min(MIB, expected - size + 1)):
                size += len(block)
                check(size <= expected, "artifact exceeded declared byte budget")
                output.write(block)
            check(process.wait() == 0 and not expired and size == expected,
                  "artifact download failed, timed out or was truncated")
        finally:
            timer.cancel()
            if process.poll() is None:
                process.kill()
            process.wait()


def collect(qualification: dict, destination: Path, artifacts: Path | None = None) -> dict:
    """Keep raw JSON/logs, authenticating each containing Actions ZIP first."""
    check(qualification.get("schema") == "openc.sh27.release_qualification.v1", "wrong qualification schema")
    proofs = qualification.get("proofs", [])
    check(len(proofs) == 5 and sum(p.get("kind") == "representative" for p in proofs) == 1,
          "two production/module pairs and one representative proof are required")
    for kind in ("production", "modules"):
        chosen = [p for p in proofs if p.get("kind") == kind]
        check(len(chosen) == 2 and len({(p["run_id"], p["attempt"]) for p in chosen}) == 2,
              f"{kind} proofs are not independent attempts")
    check(len({p["artifact_id"] for p in proofs}) == 5, "artifact IDs must be distinct")
    destination.mkdir(parents=True, exist_ok=False)
    archive_root = artifacts or destination / "downloads"
    archive_root.mkdir(parents=True, exist_ok=True)
    receipts = []
    for proof in proofs:
        check(all(type(proof.get(key)) is int and proof[key] > 0 for key in ("run_id", "attempt", "artifact_id")),
              "proof IDs/attempt must be positive integers")
        check(re.fullmatch(r"[0-9a-f]{64}", proof.get("artifact_sha256", "")) is not None,
              "proof digest is invalid")
        token = os.environ.get("GH_TOKEN")
        proof_commit = proof.get("source_commit", qualification["compiler_source_commit"])
        verify_functional_source(qualification["compiler_source_commit"], proof_commit)
        attempt = api_json(f"https://api.github.com/repos/{REPOSITORY}/actions/runs/{proof['run_id']}/attempts/{proof['attempt']}", token)
        check(attempt.get("head_sha") == proof_commit and
              attempt.get("run_attempt") == proof["attempt"] and attempt.get("status") == "completed" and
              attempt.get("conclusion") == "success", "workflow attempt did not succeed on the frozen source")
        url = f"https://api.github.com/repos/{REPOSITORY}/actions/artifacts/{proof['artifact_id']}"
        metadata = api_json(url, token)
        check(metadata.get("workflow_run", {}).get("head_sha") == proof_commit,
              "artifact source commit differs")
        check(metadata.get("workflow_run", {}).get("id") == proof["run_id"], "artifact run differs")
        check(metadata.get("digest") == "sha256:" + proof["artifact_sha256"], "artifact digest differs")
        check(metadata.get("name", "").endswith(f"-{proof['run_id']}-{proof['attempt']}") or
              (proof["kind"] == "representative" and metadata.get("name", "").endswith(f"-{proof['run_id']}")),
              "artifact attempt differs")
        check(not metadata.get("expired") and metadata.get("size_in_bytes", 0) <= 512*MIB,
              "expired or oversized artifact")
        archive = archive_root / f"{proof['artifact_id']}.zip"
        if not archive.exists():
            stream_download(["gh", "api",
                f"/repos/{REPOSITORY}/actions/artifacts/{proof['artifact_id']}/zip"],
                archive, metadata["size_in_bytes"])
        check(archive.stat().st_size == metadata["size_in_bytes"] and
              sha256(archive) == proof["artifact_sha256"], "downloaded artifact bytes differ")
        documents = {}
        wanted = ({PRODUCTION, "sh27-parity-enforcement.json", "sh27-function-scale.json", "sh27-file-scale.json"}
                  if proof["kind"] == "production" else
                  set(MODULE_REPORTS) if proof["kind"] == "modules" else {"representative-medium.json"})
        expanded = 0
        directory = destination / f"{proof['kind']}-{proof['run_id']}-{proof['attempt']}"
        with zipfile.ZipFile(archive) as bundle:
            check(len(bundle.infolist()) <= 30000, "too many artifact members")
            for entry in bundle.infolist():
                name = PurePosixPath(entry.filename.replace("\\", "/"))
                check(not name.is_absolute() and ".." not in name.parts and
                      not any(":" in part for part in name.parts), "unsafe artifact member")
                check((entry.external_attr >> 16) & 0o170000 != 0o120000,
                      "artifact symlinks are forbidden")
                if entry.is_dir() or name.suffix.lower() not in {".json", ".log", ".txt"}:
                    continue
                expanded += entry.file_size
                check(entry.file_size <= 64*MIB and expanded <= 256*MIB, "artifact evidence budget exceeded")
                content = bundle.read(entry)
                target = directory.joinpath(*name.parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                with target.open("xb") as output:
                    output.write(content)
                if name.name in wanted:
                    try:
                        document = json.loads(content)
                    except (ValueError, UnicodeError):
                        continue  # Deliberately malformed cache fixtures remain raw evidence.
                    if isinstance(document, dict):
                        documents.setdefault(name.name, []).append(document)
        def one(name: str) -> dict:
            matches = documents.get(name, [])
            check(len(matches) == 1, f"expected exactly one {name}")
            return matches[0]
        if proof["kind"] == "production":
            validate_production(one(PRODUCTION), qualification["compiler_sha256"], qualification["corpus_sha256"])
            check(one("sh27-parity-enforcement.json").get("status") == "PASS", "negative parity CLI did not pass")
            for name, key, names in (
                ("sh27-function-scale.json", "function_scale_sha256",
                 {"function_64", "function_256", "function_1024", "startup_file_allocation"}),
                ("sh27-file-scale.json", "file_scale_sha256",
                 {"files_1", "files_8", "files_24", "files_64", "startup_file_allocation"}),
            ):
                validate_scaling(one(name), qualification["compiler_sha256"], qualification[key], names)
        elif proof["kind"] == "modules":
            validate_modules({name: one(name) for name in MODULE_REPORTS}, qualification["compiler_sha256"])
        else:
            report = one("representative-medium.json")
            check(report.get("status") == "PASS" and
                  report.get("compiler", {}).get("sha256") == qualification["compiler_sha256"],
                  "pinned representative application proof differs")
        receipt = {**proof, "status": "PASS", "metadata": metadata, "workflow_attempt": attempt}
        receipts.append(receipt)
        write_json(directory / "verified-receipt.json", receipt)
    result = {**qualification, "status": "PASS", "verified_proofs": receipts}
    write_json(destination / "qualification.json", result)
    return result


def evidence_archive(source: Path, target: Path) -> None:
    """Use stored members and fixed metadata for portable byte determinism."""
    with zipfile.ZipFile(target, "x", compression=zipfile.ZIP_STORED) as archive:
        for path in sorted(source.rglob("*")):
            if not path.is_file() or "downloads" in path.relative_to(source).parts:
                continue
            info = zipfile.ZipInfo(path.relative_to(source).as_posix(), (1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            archive.writestr(info, path.read_bytes())
