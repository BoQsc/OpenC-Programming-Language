#!/usr/bin/env python3
"""Verify a 1.0.1 candidate, then publish exactly its owner-approved payloads.

The immutable 1.0.0 workflow/intent remain separate. Python is an external
release orchestrator; OpenC performs bootstrap, full workflow and packaging.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import urllib.request
import zipfile

from sh26_release import (
    DIRECT_ASSETS, REPOSITORY, api_json, artifact_record, directory_snapshot,
    load_json, require_pair, sha256, write_json,
)
from sh27_release_evidence import check, collect, evidence_archive, stream_download

VERSION = "1.0.1"
TAG = "v1.0.1"
RECORD = "OpenC-Core-1.0-release-record.json"
SUMS = "OpenC-Core-1.0-SHA256SUMS.txt"
LEGACY_COMMIT = "d0f77f6268154ac06f4206c01cd349b226b53c1b"
LEGACY_RECORD = "0b7cdd6620bb9155651da8ab0e07f2eeae510295f7e7a40eed8f4a4f835a6467"
BOOTSTRAP_SHA = "eadbef1f065261385c2c36d524624347f7e5cd3c021a4a1db9ccfcaf7c191087"
MIB = 1024 * 1024


def git(repo: Path, *arguments: str) -> str:
    return subprocess.check_output(["git", *arguments], cwd=repo, text=True).strip()


def validate_intent(root: Path, path: Path, *, publish: bool = False) -> tuple[dict, dict]:
    intent = load_json(path)
    check(intent.get("schema") == "openc.github_release_intent.v2", "wrong 1.0.1 intent schema")
    check(intent.get("version") == VERSION and intent.get("tag") == TAG, "only the new 1.0.1 tag is allowed")
    check(intent.get("release_scope") == "windows_x86_64_hosted", "release scope differs")
    check((root / "VERSION").read_text().strip() == VERSION, "canonical version differs")
    check(intent.get("status") in {"CANDIDATE_RELEASE_READY", "AUTHORIZED"}, "invalid release intent state")
    check(intent.get("qualification") == ".github/release-evidence/v1.0.1/qualification.json",
          "qualification path differs")
    check(re.fullmatch(r"[0-9a-f]{64}", intent.get("expected_compiler_sha256", "")) is not None,
          "compiler SHA-256 is invalid")
    qualification = load_json(root.parent / intent["qualification"])
    check(qualification.get("compiler_sha256") == intent["expected_compiler_sha256"],
          "qualified and release compiler differ")
    check(qualification.get("corpus_sha256") == sha256(root / "benchmarks/sh27/CORPUS.json") and
          qualification.get("function_scale_sha256") == sha256(root / "benchmarks/sh27/FUNCTION_SCALE.json") and
          qualification.get("file_scale_sha256") == sha256(root / "benchmarks/sh27/FILE_SCALE.json"),
          "qualified corpora differ from the checkout")
    check(intent.get("bootstrap", {}).get("path") == ".github/bootstrap/openc-stage0.exe" and
          intent["bootstrap"].get("sha256") == BOOTSTRAP_SHA, "bootstrap continuity pin differs")
    check(re.fullmatch(r"[0-9a-f]{40}", qualification.get("compiler_source_commit", "")) is not None,
          "qualification source commit is invalid")
    paths = ["OpenC-1.0/compiler", "OpenC-1.0/runtime", "OpenC-1.0/standard_library",
             "OpenC-1.0/conformance", "OpenC-1.0/benchmarks/sh27", "OpenC-1.0/tests",
             "OpenC-1.0/standard/core", "OpenC-1.0/schemas",
             "OpenC-1.0/VERSION", "OpenC-1.0/SOURCE_COMPLETENESS_CONTRACT.json",
             "OpenC-1.0/release/SH21_NATIVE_RELEASE_PLAN.tsv"]
    changed = git(root.parent, "diff", "--name-only", qualification["compiler_source_commit"], "--", *paths)
    allowed_pin = "OpenC-1.0/tests/SH21_NATIVE_REPOSITORY_AUDIT_PLAN.tsv"
    unexpected = [name for name in changed.splitlines() if name != allowed_pin and not
                  (name.startswith("OpenC-1.0/compiler/selfhost/") and name.endswith(".md"))]
    check(not unexpected, "functional inputs changed after certification: " + ", ".join(unexpected))
    if publish:
        check(intent.get("status") == "AUTHORIZED", "owner authorization is required for publication")
        check(intent.get("authorized_by") == "OpenC project owner", "wrong publication authority")
        check(re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z",
                           str(intent.get("authorized_utc", ""))) is not None,
              "owner authorization has no exact UTC time")
        approved = intent.get("candidate_artifact", {})
        check(all(type(approved.get(key)) is int and approved[key] > 0 for key in ("id", "run_id", "attempt")) and
              re.fullmatch(r"[0-9a-f]{40}", approved.get("release_commit", "")) is not None and
              all(re.fullmatch(r"[0-9a-f]{64}", approved.get(key, "")) is not None
                  for key in ("sha256", "payload_manifest_sha256")), "approved candidate identity is invalid")
    return intent, qualification


def native(root: Path, command: list[str], record: Path, *, transition: bool = False) -> None:
    sys.path.insert(0, str(root / "compiler/selfhost"))
    from windows_process_measure import run_measured
    print(f"Native release verification: {record.name}", flush=True)
    result = run_measured(command, cwd=root, sample_interval=.01,
        max_private_bytes=(512 if transition else 256)*MIB,
        max_working_set_bytes=(256 if transition else 64)*MIB,
        max_captured_output_bytes=4*MIB, timeout_seconds=900)
    write_json(record, result)
    check(result["exit_code"] == 0 and not result["timed_out"] and
          not result["memory_limit_exceeded"] and not result["stdout_truncated"] and
          not result["stderr_truncated"], f"native release command failed; see {record}")


def payload_snapshot(assets: Path) -> dict:
    return {name: value for name, value in directory_snapshot(assets).items() if name != RECORD}


def snapshot_digest(snapshot: dict) -> str:
    return hashlib.sha256(json.dumps(snapshot, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def verify_assets(assets: Path, intent: dict, commit: str, *, published: bool = False) -> dict:
    record = load_json(assets / RECORD)
    check(record.get("schema") == "openc.release_record.v2" and record.get("version") == VERSION,
          "release record version/schema differs")
    check(record.get("release_commit") == commit, "asset record commit differs")
    check(record.get("release_scope") == intent["release_scope"], "asset scope differs")
    check(record.get("released") is published, "asset publication state differs")
    check(record.get("authorization", {}).get("status") ==
          ("AUTHORIZED" if published else "CANDIDATE_RELEASE_READY"), "asset authorization state differs")
    check(record.get("gates") == [{"id": f"G{i}", "status": "PASS"} for i in range(1, 30)],
          "release gates are incomplete")
    snapshot = payload_snapshot(assets)
    check(len(snapshot) == 15, "expected fifteen payloads plus their release record")
    records = record.get("artifacts", [])
    check(len(records) == 15 and len({item["path"] for item in records}) == 15, "duplicate/missing asset records")
    check({item["path"] for item in records} == set(snapshot), "asset coverage differs")
    for item in records:
        check(snapshot[item["path"]] == {"bytes": item["bytes"], "sha256": item["sha256"]},
              f"asset bytes differ: {item['path']}")
    expected_sums = "".join(f"{snapshot[name]['sha256']}  {name}\n" for name in sorted(snapshot) if name != SUMS)
    check((assets / SUMS).read_text() == expected_sums, "checksum file coverage/digests differ")
    check(record.get("checksums") == [{"path": item["path"], "sha256": item["sha256"]} for item in records],
          "release-record checksum coverage differs")
    return directory_snapshot(assets)


def assemble(root: Path, native_release: Path, evidence: Path, output: Path,
             intent: dict, commit: str) -> None:
    output.mkdir(parents=True, exist_ok=False)
    records = []
    for name, relative, role, media in DIRECT_ASSETS:
        target = output / name
        shutil.copyfile(root / relative, target)
        records.append(artifact_record(target, role, media))
    copies = (
        ("OpenC-Core-1.0-reference-source.zip", "source-a.zip", "canonical source snapshot", "application/zip"),
        (f"OpenC-Hosted-{VERSION}-windows-x86_64-standalone.zip", "standalone-a.zip", "native Windows Hosted distribution", "application/zip"),
        (f"OpenC-vscode-{VERSION}.vsix", f"relocated-OpenC-vscode-{VERSION}-a.vsix", "first-party editor with exact compiler", "application/vsix"),
        (f"OpenC-{VERSION}-native-release-result.json", "native-release-result.json", "native release proof", "application/json"),
        (f"OpenC-{VERSION}-finalization-audit.json", "relocated-finalization-audit.json", "44-check finalization proof", "application/json"),
        (f"OpenC-{VERSION}-conformance-report.json", "relocated-conformance.json", "278-fixture conformance proof", "application/json"),
        (f"OpenC-{VERSION}-contract-audit.json", "relocated-contract-audit.json", "38-check contract proof", "application/json"),
    )
    for name, source, role, media in copies:
        target = output / name
        shutil.copyfile(native_release / source, target)
        records.append(artifact_record(target, role, media))
    evidence_path = output / f"OpenC-{VERSION}-SH27-evidence.zip"
    evidence_archive(evidence, evidence_path)
    records.append(artifact_record(evidence_path, "two raw hosted SH-27 certificates and receipts", "application/zip"))
    records.sort(key=lambda item: item["path"])
    (output / SUMS).write_text("".join(f"{item['sha256']}  {item['path']}\n" for item in records), newline="\n")
    records.append(artifact_record(output / SUMS, "mandatory SHA-256 checksums", "text/plain"))
    records.sort(key=lambda item: item["path"])
    record = {
        "schema": "openc.release_record.v2", "version": VERSION,
        "component": "Core_and_Hosted_reference_distribution", "release_scope": intent["release_scope"],
        "release_commit": commit, "authority": ["OpenC project owner"],
        "authorization": {"authorized_by": "OpenC project owner", "authorized_utc": None,
                          "status": "CANDIDATE_RELEASE_READY"},
        "gates": [{"id": f"G{i}", "status": "PASS"} for i in range(1, 30)],
        "artifacts": records,
        "checksums": [{"path": item["path"], "sha256": item["sha256"]} for item in records],
        "signatures": [], "signatures_required": False, "published_utc": None, "released": False,
    }
    write_json(output / RECORD, record)


def candidate(args: argparse.Namespace) -> None:
    root = args.root.resolve()
    intent, qualification = validate_intent(root, args.intent.resolve())
    commit = git(root.parent, "rev-parse", "HEAD")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    evidence = output / "evidence"
    collect(qualification, evidence, args.artifacts_dir.resolve() if args.artifacts_dir else None)
    seed = root.parent / intent["bootstrap"]["path"]
    check(sha256(seed) == intent["bootstrap"]["sha256"], "bootstrap seed differs")
    compiler = seed
    generations = []
    for generation in range(1, 4):
        built = output / f"stage{generation}.exe"
        native(root, [str(compiler), "build", f"--project={root / 'compiler/selfhost/openc.project.json'}",
                      f"--output={built}", "--no-cache"], output / f"stage{generation}.json", transition=generation == 1)
        generations.append(sha256(built))
        compiler = built
    check(generations[1] == generations[2] == intent["expected_compiler_sha256"],
          "final stages differ from the certified fixed point")
    native(root, [str(compiler), "workflow", f"--root={root}",
                  f"--output={output / 'full-workflow.json'}", "--mode=full"],
           output / "full-workflow-guard.json", transition=True)
    workflow = load_json(output / "full-workflow.json")
    check(workflow.get("status") == "PASS" and workflow.get("summary", {}).get("passed") == 19,
          "full native workflow is not 19/19")
    subprocess.run([sys.executable, str(root / "compiler/selfhost/run_with_memory_guard.py"),
        "--max-private-mib", "512", "--max-working-set-mib", "256", "--record",
        str(output / "integer-boundaries-guard.json"), "--", sys.executable,
        str(root / "compiler/selfhost/verify_sh27_integer_boundaries.py"), "--compiler", str(compiler),
        "--output", str(evidence / "release-integer-boundaries.json")], check=True)
    native_release = output / "native-release"
    native(root, [str(compiler), "release", f"--root={root}", f"--output={native_release}"],
           output / "native-release-guard.json", transition=True)
    release = load_json(native_release / "native-release-result.json")
    check(release.get("status") == "PASS" and len(release.get("checks", {})) == 9 and all(release["checks"].values()) and
          release.get("hashes", {}).get("compiler") == intent["expected_compiler_sha256"],
          "native release proof differs")
    for kind in ("source", "standalone"):
        require_pair(native_release / f"{kind}-a.zip", native_release / f"{kind}-b.zip", kind)
    require_pair(native_release / f"relocated-OpenC-vscode-{VERSION}-a.vsix",
                 native_release / f"relocated-OpenC-vscode-{VERSION}-b.vsix", "VSIX")
    subprocess.run([sys.executable, str(root / "scripts/verify_native_release_plan.py"),
                    "--root", str(root), "--archives", str(native_release),
                    "--output", str(output / "archive-manifests.json")], check=True)
    first, second = output / "a", output / "b"
    assemble(root, native_release, evidence, first, intent, commit)
    assemble(root, native_release, evidence, second, intent, commit)
    left, right = verify_assets(first, intent, commit), verify_assets(second, intent, commit)
    check(left == right, "independent candidate publication sets differ")
    shutil.copytree(first, output / "release-assets")
    write_json(output / "publication-set-verification.json", {
        "schema": "openc.sh27.publication_set.v1", "status": "PASS", "release_commit": commit,
        "compiler_sha256": intent["expected_compiler_sha256"], "generations_sha256": generations,
        "independent_asset_sets_byte_equal": True, "assets": left,
        "payload_manifest_sha256": snapshot_digest(payload_snapshot(first)),
    })
    print("OpenC 1.0.1 candidate: PASS (16 assets; publication requires owner authorization)")


def approve_assets(args: argparse.Namespace) -> Path:
    root = args.root.resolve()
    intent, _ = validate_intent(root, args.intent.resolve(), publish=True)
    repo = root.parent
    commit = git(repo, "rev-parse", "HEAD")
    check(commit == git(repo, "rev-parse", "origin/master"), "publication must use canonical master")
    approved = intent["candidate_artifact"]
    changed = git(repo, "diff", "--name-only", approved["release_commit"], commit)
    check(set(changed.splitlines()) <= {".github/release-intent-1.0.1.json"},
          "candidate bytes or publication code changed after owner review")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    metadata = api_json(f"https://api.github.com/repos/{REPOSITORY}/actions/artifacts/{approved['id']}", os.environ.get("GH_TOKEN"))
    check(metadata.get("digest") == "sha256:" + approved["sha256"] and
          metadata.get("workflow_run", {}).get("head_sha") == approved["release_commit"],
          "approved candidate artifact identity differs")
    attempt = api_json(f"https://api.github.com/repos/{REPOSITORY}/actions/runs/{approved['run_id']}/attempts/{approved['attempt']}", os.environ.get("GH_TOKEN"))
    check(attempt.get("status") == "completed" and attempt.get("conclusion") == "success" and
          attempt.get("head_sha") == approved["release_commit"] and
          metadata.get("name") == f"OpenC-1.0.1-release-candidate-{approved['run_id']}-{approved['attempt']}",
          "approved candidate workflow did not succeed")
    archive = output / "candidate.zip"
    stream_download(["gh", "api", f"/repos/{REPOSITORY}/actions/artifacts/{approved['id']}/zip"],
                    archive, metadata["size_in_bytes"])
    check(sha256(archive) == approved["sha256"], "approved candidate download differs")
    extracted = output / "approved"
    total = 0
    with zipfile.ZipFile(archive) as bundle:
        check(len(bundle.infolist()) <= 64, "candidate artifact contains too many entries")
        for entry in bundle.infolist():
            name = PurePosixPath(entry.filename.replace("\\", "/"))
            check(not name.is_absolute() and ".." not in name.parts and
                  not any(":" in p for p in name.parts) and
                  ((entry.external_attr >> 16) & 0o170000) != 0o120000, "unsafe candidate path")
            if entry.is_dir():
                continue
            total += entry.file_size
            check(total <= 512*MIB, "candidate extraction exceeds its budget")
            target = extracted.joinpath(*name.parts)
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("xb") as destination, bundle.open(entry) as source:
                shutil.copyfileobj(source, destination, length=MIB)
    receipt = load_json(extracted / "publication-set-verification.json")
    check(receipt.get("status") == "PASS" and receipt.get("compiler_sha256") == intent["expected_compiler_sha256"] and
          receipt.get("release_commit") == approved["release_commit"] and
          receipt.get("independent_asset_sets_byte_equal") is True, "candidate receipt differs")
    assets = extracted / "release-assets"
    verify_assets(assets, intent, approved["release_commit"])
    check(snapshot_digest(payload_snapshot(assets)) == approved["payload_manifest_sha256"],
          "owner-approved payload digests differ")
    record = load_json(assets / RECORD)
    record["release_commit"] = commit
    record["authorization"] = {"status": "AUTHORIZED", "authorized_by": intent["authorized_by"],
                               "authorized_utc": intent["authorized_utc"]}
    record["published_utc"] = intent["authorized_utc"]
    record["released"] = True
    write_json(assets / RECORD, record)
    verify_assets(assets, intent, commit, published=True)
    return assets


def legacy_audit(output: Path) -> dict:
    release = api_json(f"https://api.github.com/repos/{REPOSITORY}/releases/tags/v1.0.0", None)
    check(release.get("tag_name") == "v1.0.0" and not release.get("draft") and len(release["assets"]) == 15,
          "immutable 1.0.0 asset set differs")
    tag = api_json(f"https://api.github.com/repos/{REPOSITORY}/git/ref/tags/v1.0.0", None)["object"]
    for _ in range(4):
        if tag["type"] != "tag":
            break
        tag = api_json(f"https://api.github.com/repos/{REPOSITORY}/git/tags/{tag['sha']}", None)["object"]
    check(tag.get("type") == "commit" and tag.get("sha") == LEGACY_COMMIT, "immutable 1.0.0 tag moved")
    assets = {asset["name"]: asset for asset in release["assets"]}
    with urllib.request.urlopen(assets[RECORD]["browser_download_url"], timeout=120) as response:
        body = response.read(4*MIB + 1)
    check(len(body) <= 4*MIB and hashlib.sha256(body).hexdigest() == LEGACY_RECORD,
          "immutable 1.0.0 release record differs")
    record = json.loads(body)
    expected = {item["path"]: {"bytes": item["bytes"], "sha256": item["sha256"]} for item in record["artifacts"]}
    expected[RECORD] = {"bytes": len(body), "sha256": LEGACY_RECORD}
    check(set(expected) == set(assets), "immutable 1.0.0 asset coverage differs")
    for name, value in expected.items():
        check(assets[name].get("size") == value["bytes"], f"immutable asset size differs: {name}")
        size = 0
        digest = hashlib.sha256()
        with urllib.request.urlopen(assets[name]["browser_download_url"], timeout=120) as response:
            while block := response.read(min(MIB, value["bytes"] - size + 1)):
                size += len(block)
                check(size <= value["bytes"], f"immutable asset exceeded its size: {name}")
                digest.update(block)
        check({"bytes": size, "sha256": digest.hexdigest()} == value, f"immutable 1.0.0 asset differs: {name}")
    result = {"status": "PASS", "tag": "v1.0.0", "commit": LEGACY_COMMIT, "assets": expected}
    write_json(output, result)
    return result


def publish(args: argparse.Namespace) -> None:
    assets = approve_assets(args)
    intent = load_json(args.intent.resolve())
    repo = args.root.resolve().parent
    commit = git(repo, "rev-parse", "HEAD")
    check(bool(os.environ.get("GH_TOKEN")), "GH_TOKEN is required for publication")
    legacy_audit(args.output.resolve() / "legacy-before.json")
    subprocess.run(["git", "fetch", "--tags", "origin"], cwd=repo, check=True)
    existing = subprocess.run(["git", "rev-list", "-n", "1", TAG], cwd=repo, text=True, capture_output=True)
    if existing.returncode == 0 and existing.stdout.strip():
        check(existing.stdout.strip() == commit, "existing 1.0.1 tag points to another commit")
    else:
        subprocess.run(["git", "-c", "user.name=OpenC release automation", "-c",
            "user.email=actions@users.noreply.github.com", "tag", "-a", TAG, commit,
            "-m", f"OpenC {VERSION}"], cwd=repo, check=True)
        subprocess.run(["git", "push", "origin", f"refs/tags/{TAG}"], cwd=repo, check=True)
    token = os.environ["GH_TOKEN"]
    url = f"https://api.github.com/repos/{REPOSITORY}/releases/tags/{TAG}"
    release = api_json(url, token, missing_ok=True)
    expected = verify_assets(assets, intent, commit, published=True)
    if release is None:
        subprocess.run(["gh", "release", "create", TAG, "--repo", REPOSITORY, "--verify-tag", "--draft",
            "--title", f"OpenC {VERSION}", "--notes-file", str(args.notes.resolve())], cwd=repo, check=True)
        release = api_json(url, token)
    remote = {asset["name"]: asset for asset in release["assets"]}
    check(set(remote) <= set(expected), "release has unexpected immutable assets")
    before = args.output.resolve() / "remote-before"
    before.mkdir(exist_ok=False)
    for name in sorted(remote):
        value = expected[name]
        target = before / name
        stream_download(["gh", "api", f"/repos/{REPOSITORY}/releases/assets/{remote[name]['id']}",
            "-H", "Accept: application/octet-stream"], target, value["bytes"])
        check(sha256(target) == value["sha256"], f"existing immutable asset differs: {name}")
    for name in sorted(set(expected) - set(remote)):
        subprocess.run(["gh", "release", "upload", TAG, str(assets / name), "--repo", REPOSITORY], cwd=repo, check=True)
    release = api_json(url, token)
    remote = {asset["name"]: asset for asset in release["assets"]}
    check(set(remote) == set(expected), "published asset coverage differs")
    downloads = args.output.resolve() / "remote-bytes"
    downloads.mkdir(exist_ok=False)
    for name, value in sorted(expected.items()):
        target = downloads / name
        stream_download(["gh", "api", f"/repos/{REPOSITORY}/releases/assets/{remote[name]['id']}",
            "-H", "Accept: application/octet-stream"], target, value["bytes"])
        check(sha256(target) == value["sha256"], f"immutable asset differs; will not replace: {name}")
    if release.get("draft"):
        subprocess.run(["gh", "release", "edit", TAG, "--draft=false", "--latest", "--repo", REPOSITORY], cwd=repo, check=True)
    release = api_json(url, token)
    check(not release.get("draft") and bool(release.get("published_at")), "release was not published")
    legacy_audit(args.output.resolve() / "legacy-after.json")
    write_json(args.output.resolve() / "publication-result.json", {
        "schema": "openc.sh27.github_publication.v1", "status": "PASS", "tag": TAG,
        "release_commit": commit, "release_url": release["html_url"], "assets_verified": len(expected),
        "assets": expected, "immutable_mismatch_overwrites": 0,
    })
    print("OpenC 1.0.1 publication: PASS (16 verified assets; immutable 1.0.0 verified before/after)")


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("candidate", "publish", "validate-intent"):
        selected = sub.add_parser(name)
        selected.add_argument("--root", type=Path, required=True)
        selected.add_argument("--intent", type=Path, required=True)
        if name != "validate-intent":
            selected.add_argument("--output", type=Path, required=True)
        if name == "candidate":
            selected.add_argument("--artifacts-dir", type=Path)
        if name == "publish":
            selected.add_argument("--notes", type=Path, required=True)
        if name == "validate-intent":
            selected.add_argument("--action", choices=("auto", "verify", "publish"), default="auto")
    legacy = sub.add_parser("verify-legacy")
    legacy.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "candidate":
        candidate(args)
    elif args.command == "publish":
        publish(args)
    elif args.command == "verify-legacy":
        legacy_audit(args.output.resolve())
    else:
        intent, _ = validate_intent(args.root.resolve(), args.intent.resolve())
        mode = "publish" if intent["status"] == "AUTHORIZED" and intent.get("publish_on_push") else "verify"
        if args.action != "auto":
            mode = args.action
        if mode == "publish":
            validate_intent(args.root.resolve(), args.intent.resolve(), publish=True)
        if os.environ.get("GITHUB_OUTPUT"):
            with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
                output.write(f"mode={mode}\n")
        print(f"OpenC 1.0.1 intent: {intent['status']} ({mode})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
