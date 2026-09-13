#!/usr/bin/env python3
"""Reproducible OpenC v1.0.0 GitHub release orchestration.

Python owns only clean-runner orchestration, deterministic publication assembly,
and remote release verification. A repository-pinned previous OpenC compiler
rebuilds the current compiler. All required build, workflow, conformance,
fixed-point, packaging, and relocated-release work is performed by OpenC.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request


REPOSITORY = "BoQsc/OpenC-Programming-Language"
DIRECT_ASSETS = (
    ("OpenC-Core-1.0-standard.md", "standard/core/OpenC_Core_Current.md", "normative Core standard", "text/markdown"),
    ("OpenC-Core-1.0-grammar.ebnf", "standard/core/grammar/OpenC_Core_Grammar.ebnf", "normative Core grammar", "text/plain"),
    ("OpenC-Core-1.0-rule-index.json", "standard/core/metadata/OpenC_Core_Rule_Index.json", "active Core rule index", "application/json"),
    ("OpenC-Core-1.0-diagnostics.json", "standard/core/metadata/OpenC_Core_Diagnostic_Catalog.json", "Core diagnostic catalog", "application/json"),
    ("OpenC-Core-1.0-rationale.md", "standard/core/rationale/OpenC_Core_Rationale.md", "informative Core rationale", "text/markdown"),
    ("OpenC-Core-1.0-security.md", "standard/core/security/OpenC_Core_Security_Model.md", "Core security model", "text/markdown"),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def reset_directory(path: Path) -> None:
    resolved = path.resolve()
    if resolved == Path(resolved.anchor) or len(resolved.parts) < 3:
        raise SystemExit(f"refusing broad output directory: {resolved}")
    if resolved.exists():
        shutil.rmtree(resolved)
    resolved.mkdir(parents=True)


def run(command: list[str], *, cwd: Path) -> None:
    print("+ " + subprocess.list2cmdline(command), flush=True)
    completed = subprocess.run(command, cwd=cwd)
    if completed.returncode != 0:
        raise SystemExit(
            f"command failed with exit code {completed.returncode}: "
            + subprocess.list2cmdline(command)
        )


def validated_intent(
    root: Path,
    intent_path: Path,
    release_commit: str | None = None,
) -> dict:
    intent = load_json(intent_path)
    required = {
        "schema": "openc.github_release_intent.v1",
        "version": "1.0.0",
        "tag": "v1.0.0",
        "status": "AUTHORIZED",
        "authorized_by": "OpenC project owner",
        "release_scope": "windows_x86_64_hosted",
    }
    for key, expected in required.items():
        if intent.get(key) != expected:
            raise SystemExit(f"release intent {key!r} must be {expected!r}")
    if not intent.get("publish_on_push"):
        raise SystemExit("release intent does not authorize push publication")
    if not re.fullmatch(
        r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z",
        str(intent.get("authorized_utc", "")),
    ):
        raise SystemExit("release intent has no exact UTC authorization time")
    expected_hash = intent.get("expected_compiler_sha256", "")
    if not re.fullmatch(r"[0-9a-f]{64}", expected_hash):
        raise SystemExit("release intent compiler hash is invalid")
    if (root / "VERSION").read_text(encoding="utf-8").strip() != "1.0.0":
        raise SystemExit("canonical VERSION is not 1.0.0")
    state = load_json(root / "DEVELOPMENT_STATE.json")
    recorded = state["self_hosting"]["sh25_acceptance"]
    if recorded.get("status") != "PASS_COMPLETE":
        raise SystemExit("SH-25 acceptance is not complete")
    if recorded.get("native_compiler_sha256") != expected_hash:
        raise SystemExit("release intent compiler hash differs from SH-25")
    if recorded.get("open_p0") != 0 or recorded.get("open_p1") != 0:
        raise SystemExit("release intent is blocked by an open P0/P1")
    bootstrap = intent.get("bootstrap", {})
    if bootstrap.get("role") != "pinned_previous_openc_compiler_for_bootstrap_continuity":
        raise SystemExit("release intent bootstrap role is invalid")
    if bootstrap.get("sha256") != expected_hash:
        raise SystemExit("release intent bootstrap hash differs from SH-25")
    if release_commit is not None:
        if not re.fullmatch(r"[0-9a-f]{40}", release_commit):
            raise SystemExit("release commit must be a full lowercase Git SHA")
        master = subprocess.run(
            ["git", "rev-parse", "origin/master"],
            cwd=root.parent,
            check=True,
            text=True,
            capture_output=True,
        ).stdout.strip()
        if release_commit != master:
            raise SystemExit("release commit is not the fetched origin/master head")
    return intent


def build(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    intent_path = args.intent.resolve()
    intent = validated_intent(root, intent_path)
    output = args.output.resolve()
    reset_directory(output)
    bootstrap = intent["bootstrap"]
    seed = root.parent / bootstrap["path"]
    if not seed.is_file() or sha256(seed) != bootstrap["sha256"]:
        raise SystemExit("pinned OpenC bootstrap seed hash mismatch")

    project = root / "compiler" / "selfhost" / "openc.project.json"
    stage2 = output / "native-stage2.exe"
    run(
        [
            str(seed), "build", f"--project={project}",
            f"--output={stage2}", f"--timings={output / 'stage2-timings.json'}",
        ],
        cwd=root,
    )

    stage3 = output / "native-stage3.exe"
    stage4 = output / "native-stage4.exe"
    run(
        [
            str(stage2), "build", f"--project={project}",
            f"--output={stage3}", f"--timings={output / 'stage3-timings.json'}",
        ],
        cwd=root,
    )
    run(
        [
            str(stage3), "build", f"--project={project}",
            f"--output={stage4}", f"--timings={output / 'stage4-timings.json'}",
        ],
        cwd=root,
    )
    expected = intent["expected_compiler_sha256"]
    stage2_hash = sha256(stage2)
    stage3_hash = sha256(stage3)
    stage4_hash = sha256(stage4)
    if stage2_hash != expected or stage3_hash != expected or stage4_hash != expected:
        raise SystemExit(
            "native fixed point differs from authorized compiler hash: "
            f"stage2={stage2_hash} stage3={stage3_hash} "
            f"stage4={stage4_hash} expected={expected}"
        )

    workflow_report = output / "full-workflow.json"
    run(
        [
            str(stage4), "workflow", f"--root={root}",
            f"--output={workflow_report}", "--mode=full",
        ],
        cwd=root,
    )
    workflow = load_json(workflow_report)
    if workflow.get("status") != "PASS" or workflow.get("summary", {}).get("passed") != 19:
        raise SystemExit("current-compiler full workflow is not 19/19 PASS")

    native_release = output / "native-release"
    run(
        [str(stage4), "release", f"--root={root}", f"--output={native_release}"],
        cwd=root,
    )
    release = load_json(native_release / "native-release-result.json")
    if release.get("status") != "PASS":
        raise SystemExit("current-compiler native release proof is not PASS")
    report = {
        "schema": "openc.sh26_clean_runner_bootstrap.v1",
        "status": "PASS",
        "bootstrap_seed_sha256": sha256(seed),
        "native_stage2_sha256": stage2_hash,
        "native_stage3_sha256": stage3_hash,
        "native_stage4_sha256": stage4_hash,
        "native_fixed_point": stage2_hash == stage3_hash == stage4_hash == expected,
        "full_workflow_tasks_passed": workflow["summary"]["passed"],
        "native_release_status": release["status"],
        "toolchain_boundary": {
            "python_role": "external_clean_runner_orchestrator_only",
            "bootstrap_role": "pinned_previous_openc_compiler_only",
            "d_invoked": False,
            "tinycc_invoked": False,
            "generated_c_used": False,
            "python_invoked_by_current_native_workflow": False,
        },
    }
    write_json(output / "bootstrap-result.json", report)
    print("OpenC SH-26 clean-runner bootstrap and native proof: PASS")
    return 0


def artifact_record(path: Path, role: str, media_type: str) -> dict:
    return {
        "path": path.name,
        "role": role,
        "media_type": media_type,
        "bytes": path.stat().st_size,
        "sha256": sha256(path),
    }


def require_pair(left: Path, right: Path, label: str) -> None:
    if not left.is_file() or not right.is_file():
        raise SystemExit(f"missing {label} deterministic pair")
    if left.stat().st_size != right.stat().st_size or sha256(left) != sha256(right):
        raise SystemExit(f"{label} deterministic pair differs")


def build_asset_directory(
    root: Path,
    native_release: Path,
    output: Path,
    intent: dict,
    release_commit: str,
    published_utc: str,
) -> None:
    reset_directory(output)
    records: list[dict] = []
    for name, relative, role, media_type in DIRECT_ASSETS:
        target = output / name
        shutil.copyfile(root / relative, target)
        records.append(artifact_record(target, role, media_type))

    copies = (
        ("OpenC-Core-1.0-reference-source.zip", "source-a.zip", "canonical reference source snapshot", "application/zip"),
        ("OpenC-Hosted-1.0.0-windows-x86_64-standalone.zip", "standalone-a.zip", "standalone OpenC-native Windows Hosted distribution", "application/zip"),
        ("OpenC-vscode-1.0.0.vsix", "relocated-OpenC-vscode-1.0.0-a.vsix", "dependency-free VS Code extension with exact native compiler", "application/vsix"),
        ("OpenC-1.0.0-native-release-result.json", "native-release-result.json", "OpenC-native deterministic and relocated release proof", "application/json"),
        ("OpenC-1.0.0-finalization-audit.json", "relocated-finalization-audit.json", "44-check Windows finalization audit", "application/json"),
        ("OpenC-1.0.0-conformance-report.json", "relocated-conformance.json", "executed 278-fixture native conformance report", "application/json"),
        ("OpenC-1.0.0-contract-audit.json", "relocated-contract-audit.json", "38-check residual contract audit", "application/json"),
    )
    for name, source_name, role, media_type in copies:
        target = output / name
        shutil.copyfile(native_release / source_name, target)
        records.append(artifact_record(target, role, media_type))

    records.sort(key=lambda item: item["path"])
    sums = output / "OpenC-Core-1.0-SHA256SUMS.txt"
    sums.write_text(
        "".join(f"{item['sha256']}  {item['path']}\n" for item in records),
        encoding="utf-8",
        newline="\n",
    )
    records.append(artifact_record(sums, "mandatory SHA-256 checksum list", "text/plain"))
    records.sort(key=lambda item: item["path"])
    record = {
        "schema": "openc.release_record.v2",
        "version": intent["version"],
        "component": "Core_and_Hosted_reference_distribution",
        "release_scope": intent["release_scope"],
        "release_commit": release_commit,
        "authority": ["OpenC project owner"],
        "authorization": {
            "authorized_by": intent["authorized_by"],
            "authorized_utc": intent["authorized_utc"],
            "status": "AUTHORIZED",
        },
        "gates": [{"id": f"G{index}", "status": "PASS"} for index in range(1, 20)],
        "artifacts": records,
        "checksums": [
            {"path": item["path"], "sha256": item["sha256"]}
            for item in records
        ],
        "signatures": [],
        "signatures_required": False,
        "published_utc": published_utc,
        "released": True,
    }
    write_json(output / "OpenC-Core-1.0-release-record.json", record)


def directory_snapshot(path: Path) -> dict[str, dict[str, object]]:
    return {
        item.relative_to(path).as_posix(): {
            "bytes": item.stat().st_size,
            "sha256": sha256(item),
        }
        for item in sorted(path.rglob("*"))
        if item.is_file()
    }


def verify_asset_directory(path: Path, intent: dict, release_commit: str) -> dict:
    snapshot = directory_snapshot(path)
    record_path = path / "OpenC-Core-1.0-release-record.json"
    record = load_json(record_path)
    if record.get("schema") != "openc.release_record.v2":
        raise SystemExit("publication release-record schema mismatch")
    if record.get("release_commit") != release_commit:
        raise SystemExit("publication release-record commit mismatch")
    if record.get("authorization", {}).get("status") != "AUTHORIZED":
        raise SystemExit("publication release record is not AUTHORIZED")
    if record.get("authorization", {}).get("authorized_utc") != intent["authorized_utc"]:
        raise SystemExit("publication authorization timestamp mismatch")
    if not record.get("released") or not record.get("published_utc"):
        raise SystemExit("publication release record is not RELEASED")
    if len(record.get("gates", [])) != 19:
        raise SystemExit("publication release record does not contain 19 PASS gates")
    for item in record.get("artifacts", []):
        candidate = path / item["path"]
        if not candidate.is_file():
            raise SystemExit(f"release-record artifact missing: {item['path']}")
        if candidate.stat().st_size != item["bytes"] or sha256(candidate) != item["sha256"]:
            raise SystemExit(f"release-record artifact mismatch: {item['path']}")
    return snapshot


def package(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    intent = validated_intent(root, args.intent.resolve())
    native_release = args.native_release.resolve()
    output = args.output.resolve()
    if not re.fullmatch(r"[0-9a-f]{40}", args.release_commit):
        raise SystemExit("release commit must be a full lowercase Git SHA")
    release = load_json(native_release / "native-release-result.json")
    expected = intent["expected_compiler_sha256"]
    if release.get("status") != "PASS" or release.get("hashes", {}).get("compiler") != expected:
        raise SystemExit("native release result is not the authorized PASS result")
    require_pair(native_release / "standalone-a.zip", native_release / "standalone-b.zip", "standalone archive")
    require_pair(native_release / "source-a.zip", native_release / "source-b.zip", "source archive")
    require_pair(
        native_release / "relocated-OpenC-vscode-1.0.0-a.vsix",
        native_release / "relocated-OpenC-vscode-1.0.0-b.vsix",
        "VSIX",
    )
    finalization = load_json(native_release / "relocated-finalization-audit.json")
    conformance = load_json(native_release / "relocated-conformance.json")
    contract = load_json(native_release / "relocated-contract-audit.json")
    if finalization.get("status") != "PASS":
        raise SystemExit("relocated finalization audit is not PASS")
    if (conformance.get("passed"), conformance.get("total"), conformance.get("failed")) != (278, 278, 0):
        raise SystemExit("relocated conformance is not 278/278 PASS")
    if contract.get("status") != "PASS":
        raise SystemExit("relocated contract audit is not PASS")

    reset_directory(output)
    published_utc = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    first = output / "a"
    second = output / "b"
    build_asset_directory(root, native_release, first, intent, args.release_commit, published_utc)
    build_asset_directory(root, native_release, second, intent, args.release_commit, published_utc)
    first_snapshot = verify_asset_directory(first, intent, args.release_commit)
    second_snapshot = verify_asset_directory(second, intent, args.release_commit)
    if first_snapshot != second_snapshot:
        raise SystemExit("independent publication asset directories differ")
    assets = output / "release-assets"
    shutil.copytree(first, assets)
    result = {
        "schema": "openc.sh26_publication_set_verification.v1",
        "status": "PASS",
        "release_commit": args.release_commit,
        "authorized_utc": intent["authorized_utc"],
        "publication_started_utc": published_utc,
        "independent_asset_sets_byte_equal": True,
        "assets": first_snapshot,
    }
    write_json(output / "publication-set-verification.json", result)
    print(f"OpenC SH-26 publication set: PASS ({len(first_snapshot)} exact assets)")
    return 0


def api_json(url: str, token: str | None, *, missing_ok: bool = False) -> dict | None:
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "OpenC-SH26-release"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
        headers["X-GitHub-Api-Version"] = "2022-11-28"
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        if missing_ok and error.code == 404:
            return None
        raise


def remote_digest(url: str) -> tuple[int, str]:
    request = urllib.request.Request(url, headers={"User-Agent": "OpenC-SH26-release"})
    digest = hashlib.sha256()
    size = 0
    with urllib.request.urlopen(request, timeout=300) as response:
        while True:
            block = response.read(1024 * 1024)
            if not block:
                break
            size += len(block)
            digest.update(block)
    return size, digest.hexdigest()


def publish(args: argparse.Namespace) -> int:
    intent = load_json(args.intent.resolve())
    if intent.get("status") != "AUTHORIZED" or intent.get("tag") != "v1.0.0":
        raise SystemExit("publication requires the authorized v1.0.0 intent")
    if not re.fullmatch(r"[0-9a-f]{40}", args.release_commit):
        raise SystemExit("release commit must be a full lowercase Git SHA")
    assets = args.assets.resolve()
    expected = directory_snapshot(assets)
    if not expected:
        raise SystemExit("publication asset directory is empty")
    token = os.environ.get("GH_TOKEN")
    if not token:
        raise SystemExit("GH_TOKEN is required for publication")
    tag = intent["tag"]

    subprocess.run(["git", "fetch", "--tags", "origin"], check=True)
    local = subprocess.run(
        ["git", "rev-list", "-n", "1", tag], text=True, capture_output=True
    )
    if local.returncode == 0 and local.stdout.strip():
        if local.stdout.strip() != args.release_commit:
            raise SystemExit(f"existing {tag} does not point to the authorized commit")
    else:
        subprocess.run(["git", "config", "user.name", "OpenC release automation"], check=True)
        subprocess.run(["git", "config", "user.email", "actions@users.noreply.github.com"], check=True)
        subprocess.run(
            ["git", "tag", "-a", tag, args.release_commit, "-m", "OpenC 1.0.0"],
            check=True,
        )
        subprocess.run(["git", "push", "origin", f"refs/tags/{tag}"], check=True)

    api_url = f"https://api.github.com/repos/{REPOSITORY}/releases/tags/{tag}"
    release = api_json(api_url, token, missing_ok=True)
    if release is None:
        command = [
            "gh", "release", "create", tag,
            *[str(assets / name) for name in sorted(expected)],
            "--repo", REPOSITORY,
            "--verify-tag",
            "--title", "OpenC 1.0.0",
            "--notes-file", str(args.notes.resolve()),
        ]
        subprocess.run(command, check=True)
        for _ in range(12):
            release = api_json(api_url, token, missing_ok=True)
            if release is not None:
                break
            time.sleep(5)
        if release is None:
            raise SystemExit("GitHub release was not observable after creation")

    remote_by_name = {item["name"]: item for item in release.get("assets", [])}
    extras = sorted(set(remote_by_name) - set(expected))
    if extras:
        raise SystemExit("release contains unexpected immutable assets: " + ", ".join(extras))
    missing = sorted(set(expected) - set(remote_by_name))
    if missing:
        subprocess.run(
            ["gh", "release", "upload", tag, *[str(assets / name) for name in missing], "--repo", REPOSITORY],
            check=True,
        )
        release = api_json(api_url, token)
        remote_by_name = {item["name"]: item for item in release.get("assets", [])}

    verified: dict[str, dict[str, object]] = {}
    for name, local_record in sorted(expected.items()):
        remote = remote_by_name.get(name)
        if remote is None:
            raise SystemExit(f"release asset is still missing: {name}")
        size, digest = remote_digest(remote["browser_download_url"])
        if size != local_record["bytes"] or digest != local_record["sha256"]:
            raise SystemExit(f"published asset differs and will not be replaced: {name}")
        verified[name] = {"bytes": size, "sha256": digest}
    result = {
        "schema": "openc.sh26_github_publication_result.v1",
        "status": "PASS",
        "tag": tag,
        "release_commit": args.release_commit,
        "release_url": release["html_url"],
        "github_created_at": release.get("created_at"),
        "github_published_at": release.get("published_at"),
        "assets_verified": len(verified),
        "assets": verified,
        "immutable_mismatch_overwrites": 0,
    }
    write_json(args.output.resolve(), result)
    print(f"OpenC SH-26 GitHub publication: PASS ({len(verified)} assets)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    validate = subparsers.add_parser("validate-intent")
    validate.add_argument("--root", type=Path, required=True)
    validate.add_argument("--intent", type=Path, required=True)
    validate.add_argument("--release-commit")
    build_parser = subparsers.add_parser("build")
    build_parser.add_argument("--root", type=Path, required=True)
    build_parser.add_argument("--intent", type=Path, required=True)
    build_parser.add_argument("--output", type=Path, required=True)
    package_parser = subparsers.add_parser("package")
    package_parser.add_argument("--root", type=Path, required=True)
    package_parser.add_argument("--intent", type=Path, required=True)
    package_parser.add_argument("--native-release", type=Path, required=True)
    package_parser.add_argument("--release-commit", required=True)
    package_parser.add_argument("--output", type=Path, required=True)
    publish_parser = subparsers.add_parser("publish")
    publish_parser.add_argument("--intent", type=Path, required=True)
    publish_parser.add_argument("--assets", type=Path, required=True)
    publish_parser.add_argument("--notes", type=Path, required=True)
    publish_parser.add_argument("--release-commit", required=True)
    publish_parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "validate-intent":
        validated_intent(
            args.root.resolve(),
            args.intent.resolve(),
            args.release_commit,
        )
        print("OpenC SH-26 release intent: AUTHORIZED")
        return 0
    if args.command == "build":
        return build(args)
    if args.command == "package":
        return package(args)
    return publish(args)


if __name__ == "__main__":
    raise SystemExit(main())
