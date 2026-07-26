#!/usr/bin/env python3
"""Verify an OpenC Core/Hosted publication artifact set."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import zipfile

import jsonschema


RECORD_NAME = "OpenC-Core-1.0-release-record.json"
SUMS_NAME = "OpenC-Core-1.0-SHA256SUMS.txt"
REQUIRED_CONFORMANCE_FIXTURES = 278


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def safe_archive(archive_path: Path) -> list[str]:
    with zipfile.ZipFile(archive_path) as archive:
        failed = archive.testzip()
        if failed:
            raise SystemExit(f"CRC failure in {archive_path.name}: {failed}")
        names = archive.namelist()
        if not names or len(names) != len(set(names)):
            raise SystemExit(
                f"empty or duplicate-path archive: {archive_path.name}"
            )
        for name in names:
            path = PurePosixPath(name)
            if path.is_absolute() or ".." in path.parts:
                raise SystemExit(
                    f"unsafe archive path in {archive_path.name}: {name}"
                )
        return names


def verify_internal_manifest(
    archive_path: Path,
    manifest_suffix: str,
) -> int:
    with zipfile.ZipFile(archive_path) as archive:
        names = safe_archive(archive_path)
        manifests = [
            name for name in names if name.endswith("/" + manifest_suffix)
        ]
        if len(manifests) != 1:
            raise SystemExit(
                f"{archive_path.name} must contain one {manifest_suffix}"
            )
        manifest_name = manifests[0]
        prefix = manifest_name[: -len(manifest_suffix)]
        count = 0
        for line in archive.read(manifest_name).decode("utf-8").splitlines():
            if not line:
                continue
            expected, relative = line.split("  ", 1)
            member = prefix + relative
            if member not in names:
                raise SystemExit(
                    f"manifest member missing in {archive_path.name}: {member}"
                )
            actual = hashlib.sha256(archive.read(member)).hexdigest()
            if actual != expected:
                raise SystemExit(
                    f"manifest mismatch in {archive_path.name}: {member}"
                )
            count += 1
        return count


def verify_release(root: Path, schema_path: Path) -> dict:
    record_path = root / RECORD_NAME
    if not record_path.is_file():
        raise SystemExit(f"release record is missing: {record_path}")
    record = json.loads(record_path.read_text(encoding="utf-8"))
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    jsonschema.Draft202012Validator(schema).validate(record)

    artifacts = record["artifacts"]
    paths = [item["path"] for item in artifacts]
    if len(paths) != len(set(paths)):
        raise SystemExit("release record contains duplicate artifact paths")
    checksum_records = {
        item["path"]: item["sha256"] for item in record["checksums"]
    }
    if set(checksum_records) != set(paths):
        raise SystemExit("release record artifact/checksum sets differ")

    for item in artifacts:
        path = root / item["path"]
        if not path.is_file():
            raise SystemExit(f"release artifact is missing: {item['path']}")
        if path.stat().st_size != item["bytes"]:
            raise SystemExit(f"release artifact size differs: {item['path']}")
        actual = sha256(path)
        if actual != item["sha256"] or actual != checksum_records[item["path"]]:
            raise SystemExit(f"release artifact hash differs: {item['path']}")

    sums_path = root / SUMS_NAME
    sums = {}
    for line in sums_path.read_text(encoding="utf-8").splitlines():
        expected, name = line.split("  ", 1)
        if name in sums:
            raise SystemExit(f"duplicate checksum-list path: {name}")
        sums[name] = expected
    expected_sums = {
        item["path"]: item["sha256"]
        for item in artifacts
        if item["path"] != SUMS_NAME
    }
    if sums != expected_sums:
        raise SystemExit("SHA256SUMS content does not match release record")

    archive_manifest_counts = {}
    for item in artifacts:
        if item["media_type"] != "application/zip":
            continue
        path = root / item["path"]
        if item["path"].endswith("-reference-source.zip"):
            suffix = "MANIFEST.sha256"
        elif item["path"].endswith("-standalone.zip"):
            suffix = "STANDALONE-MANIFEST.sha256"
        else:
            suffix = "MANIFEST.sha256"
        archive_manifest_counts[item["path"]] = verify_internal_manifest(
            path, suffix
        )

    conformance = json.loads(
        (root / "OpenC-Core-1.0-conformance-report.json").read_text(
            encoding="utf-8"
        )
    )
    if (
        conformance.get("total"),
        conformance.get("passed"),
        conformance.get("failed"),
    ) != (
        REQUIRED_CONFORMANCE_FIXTURES,
        REQUIRED_CONFORMANCE_FIXTURES,
        0,
    ):
        raise SystemExit(
            "published conformance report is not "
            f"{REQUIRED_CONFORMANCE_FIXTURES}/"
            f"{REQUIRED_CONFORMANCE_FIXTURES} PASS"
        )
    evidence = json.loads(
        (root / "OpenC-Core-1.0-implementation-evidence.json").read_text(
            encoding="utf-8"
        )
    )
    if evidence.get("status") != "PASS":
        raise SystemExit("published implementation evidence is not PASS")

    return {
        "schema": "openc.release_artifact_verification.v1",
        "status": "PASS",
        "version": record["version"],
        "release_commit": record["release_commit"],
        "authorization": record["authorization"],
        "released": record["released"],
        "published_utc": record["published_utc"],
        "artifacts": len(artifacts),
        "release_record_sha256": sha256(record_path),
        "archive_manifest_entries": archive_manifest_counts,
        "conformance": {
            "total": conformance["total"],
            "passed": conformance["passed"],
            "failed": conformance["failed"],
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--release", type=Path, required=True)
    parser.add_argument("--comparison", type=Path)
    parser.add_argument(
        "--schema",
        type=Path,
        default=Path(__file__).resolve().parents[1]
        / "schemas"
        / "RELEASE_RECORD.schema.json",
    )
    parser.add_argument("--report", type=Path)
    parser.add_argument("--expect-authorized", action="store_true")
    parser.add_argument("--expect-released", action="store_true")
    args = parser.parse_args()

    release = args.release.resolve()
    result = verify_release(release, args.schema.resolve())
    record = json.loads(
        (release / RECORD_NAME).read_text(encoding="utf-8")
    )
    if args.expect_authorized and (
        record["authorization"]["status"] != "AUTHORIZED"
        or not record["authorization"]["authorized_utc"]
    ):
        raise SystemExit("release record is not owner-authorized")
    if args.expect_released and (
        not record["released"] or not record["published_utc"]
    ):
        raise SystemExit("release record is not published/released")

    if args.comparison:
        comparison = args.comparison.resolve()
        comparison_result = verify_release(
            comparison, args.schema.resolve()
        )
        release_files = {
            path.relative_to(release).as_posix(): path
            for path in release.rglob("*")
            if path.is_file()
        }
        comparison_files = {
            path.relative_to(comparison).as_posix(): path
            for path in comparison.rglob("*")
            if path.is_file()
        }
        if set(release_files) != set(comparison_files):
            raise SystemExit("independent release artifact file sets differ")
        differing = [
            name
            for name in release_files
            if release_files[name].read_bytes()
            != comparison_files[name].read_bytes()
        ]
        if differing:
            raise SystemExit(
                "independent release artifacts differ: "
                + ", ".join(differing)
            )
        result["independent_build_byte_equal"] = True
        result["comparison_release_record_sha256"] = comparison_result[
            "release_record_sha256"
        ]

    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(
            json.dumps(result, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
            newline="\n",
        )
    print(
        "OpenC release artifact verification: PASS; "
        f"artifacts={result['artifacts']} version={result['version']} "
        f"record={result['release_record_sha256']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
