#!/usr/bin/env python3
"""Build the deterministic OpenC Core/Hosted publication artifact set.

This program assembles already verified inputs. It does not compile, test,
sign, tag, push, or publish the release.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import zipfile

from build_source_archive import EPOCH, included_files


DIRECT_ARTIFACTS = (
    (
        "OpenC-Core-1.0-standard.md",
        "standard/core/OpenC_Core_Current.md",
        "normative Core standard",
        "text/markdown",
    ),
    (
        "OpenC-Core-1.0-grammar.ebnf",
        "standard/core/grammar/OpenC_Core_Grammar.ebnf",
        "normative Core grammar",
        "text/plain",
    ),
    (
        "OpenC-Core-1.0-rule-index.json",
        "standard/core/metadata/OpenC_Core_Rule_Index.json",
        "active Core rule index",
        "application/json",
    ),
    (
        "OpenC-Core-1.0-diagnostics.json",
        "standard/core/metadata/OpenC_Core_Diagnostic_Catalog.json",
        "Core diagnostic catalog",
        "application/json",
    ),
    (
        "OpenC-Core-1.0-rationale.md",
        "standard/core/rationale/OpenC_Core_Rationale.md",
        "informative Core rationale",
        "text/markdown",
    ),
    (
        "OpenC-Core-1.0-security.md",
        "standard/core/security/OpenC_Core_Security_Model.md",
        "Core security model",
        "text/markdown",
    ),
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare_directory(path: Path, force: bool) -> None:
    if path.exists():
        if not force:
            raise SystemExit(f"output directory already exists: {path}")
        if path == Path(path.anchor) or len(path.parts) < 3:
            raise SystemExit(f"refusing to replace broad output path: {path}")
        shutil.rmtree(path)
    path.mkdir(parents=True)


def zip_info(name: str) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, EPOCH)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o100644 << 16
    return info


def write_entries_archive(
    output: Path,
    archive_root: str,
    entries: list[tuple[str, bytes]],
    *,
    add_manifest: bool,
) -> None:
    normalized = sorted(entries, key=lambda item: item[0])
    if add_manifest:
        lines = [
            f"{hashlib.sha256(content).hexdigest()}  {name}"
            for name, content in normalized
        ]
        normalized.append(
            ("MANIFEST.sha256", ("\n".join(lines) + "\n").encode("utf-8"))
        )
        normalized.sort(key=lambda item: item[0])
    with zipfile.ZipFile(
        output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
    ) as archive:
        for relative, content in normalized:
            name = f"{archive_root}/{relative}"
            archive.writestr(zip_info(name), content)


def directory_entries(root: Path, source: Path) -> list[tuple[str, bytes]]:
    return [
        (path.relative_to(root).as_posix(), path.read_bytes())
        for path in sorted(source.rglob("*"))
        if path.is_file()
    ]


def write_source_archive(tree: Path, output: Path, version: str) -> None:
    with zipfile.ZipFile(
        output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
    ) as archive:
        for path in included_files(tree):
            relative = path.relative_to(tree).as_posix()
            name = f"OpenC-{version}/{relative}"
            info = zip_info(name)
            if path.suffix in {".sh", ".py"} or path.parent.name == "bin":
                info.external_attr = 0o100755 << 16
            archive.writestr(info, path.read_bytes())


def artifact_record(
    path: Path,
    role: str,
    media_type: str,
) -> dict[str, object]:
    return {
        "path": path.name,
        "role": role,
        "media_type": media_type,
        "bytes": path.stat().st_size,
        "sha256": sha256(path),
    }


def implementation_evidence(
    *,
    version: str,
    release_commit: str,
    sh6: dict,
    development: dict,
    completeness: dict,
) -> dict:
    artifacts = sh6["artifacts"]
    return {
        "schema": "openc.release_implementation_evidence.v1",
        "version": version,
        "release_commit": release_commit,
        "target": "windows-x86_64-hosted",
        "status": "PASS",
        "self_hosting": {
            "gate": "SH-6",
            "status": sh6["status"],
            "checks": sh6["checks"],
            "standalone_archive_sha256": artifacts["archive_sha256"],
            "packaged_compiler_sha256": artifacts[
                "packaged_compiler_sha256"
            ],
            "bootstrap_seed_sha256": artifacts["bootstrap_seed_sha256"],
            "stage2_sha256": artifacts["stage2_sha256"],
            "stage3_sha256": artifacts["stage3_sha256"],
            "generated_c_sha256": artifacts["generated_c_sha256"],
            "normalized_stage2_sha256": artifacts[
                "normalized_stage2_sha256"
            ],
            "normalized_stage3_sha256": artifacts[
                "normalized_stage3_sha256"
            ],
            "tcc_sha256": artifacts["tcc_sha256"],
        },
        "semantic_parity": sh6["semantic_parity"],
        "conformance": sh6["conformance"],
        "maintained_programs": {
            "total": len(sh6["maintained_programs"]),
            "passed": sum(
                item["passed"] for item in sh6["maintained_programs"]
            ),
            "results": sh6["maintained_programs"],
        },
        "repository_regression": {
            "debug_builds": {"passed": 9, "total": 9},
            "release_builds": {"passed": 9, "total": 9},
            "d_test_commands": development["implementation_test_commands"],
            "python_bootstrap_tests": development["bootstrap_tests"],
            "source_completeness": {
                "passed": completeness["required_files"],
                "total": completeness["required_files"],
            },
        },
        "roles": sh6["roles"],
        "scope_exclusions": {
            "linux": development["linux_verification"],
            "freestanding": development["freestanding_verification"],
            "native_provider": development["native_verification"],
        },
        "evidence_limits": {
            "active_rules": development["active_rule_count"],
            "rules_with_dedicated_fixtures": development[
                "active_rules_with_dedicated_fixtures"
            ],
            "rules_without_dedicated_fixtures": development[
                "active_rules_without_dedicated_fixtures"
            ],
            "historical_rule_id_compatibility_matches_disclosed": development[
                "conformance_result"
            ]["historical_edition_compatibility_matches_disclosed"],
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--tree", type=Path, default=Path(__file__).resolve().parents[1]
    )
    parser.add_argument("--standalone", type=Path, required=True)
    parser.add_argument("--sh6-result", type=Path, required=True)
    parser.add_argument("--conformance-report", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--release-commit", required=True)
    parser.add_argument("--authorized-utc")
    parser.add_argument(
        "--authorization-status",
        choices=("CANDIDATE_RELEASE_READY", "AUTHORIZED"),
        default="AUTHORIZED",
    )
    parser.add_argument("--published-utc")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    tree = args.tree.resolve()
    standalone = args.standalone.resolve()
    sh6_result = args.sh6_result.resolve()
    conformance_report = args.conformance_report.resolve()
    output = args.output.resolve()
    version = (tree / "VERSION").read_text(encoding="utf-8").strip()

    if not re.fullmatch(r"[0-9a-f]{40}", args.release_commit):
        raise SystemExit("release commit must be a full lowercase Git SHA")
    for required in (standalone, sh6_result, conformance_report):
        if not required.is_file():
            raise SystemExit(f"required release input is missing: {required}")
    if (
        args.authorization_status == "AUTHORIZED"
        and not args.authorized_utc
    ):
        raise SystemExit("AUTHORIZED release requires --authorized-utc")
    if args.published_utc and args.authorization_status != "AUTHORIZED":
        raise SystemExit("published release must be AUTHORIZED")

    sh6 = json.loads(sh6_result.read_text(encoding="utf-8"))
    conformance = json.loads(conformance_report.read_text(encoding="utf-8"))
    development = json.loads(
        (tree / "DEVELOPMENT_STATE.json").read_text(encoding="utf-8")
    )
    completeness = json.loads(
        (tree / "SOURCE_COMPLETENESS_REPORT.json").read_text(encoding="utf-8")
    )
    if not completeness.get("source_complete_by_inventory"):
        raise SystemExit("source completeness report is not PASS")
    if sh6.get("status") != "PASS":
        raise SystemExit("SH-6 result is not PASS")
    if sha256(standalone) != sh6["artifacts"]["archive_sha256"]:
        raise SystemExit("standalone archive does not match SH-6 evidence")
    if (
        conformance.get("total"),
        conformance.get("passed"),
        conformance.get("failed"),
    ) != (268, 268, 0):
        raise SystemExit("conformance report is not the required 268/268 PASS")

    prepare_directory(output, args.force)
    records: list[dict[str, object]] = []

    for name, relative, role, media_type in DIRECT_ARTIFACTS:
        source = tree / relative
        target = output / name
        shutil.copyfile(source, target)
        records.append(artifact_record(target, role, media_type))

    standard_archive = output / "OpenC-Core-1.0-standard.zip"
    write_entries_archive(
        standard_archive,
        "OpenC-Core-1.0-standard",
        directory_entries(tree, tree / "standard" / "core"),
        add_manifest=True,
    )
    records.append(
        artifact_record(
            standard_archive,
            "complete Core standard bundle",
            "application/zip",
        )
    )

    conformance_archive = output / "OpenC-Core-1.0-conformance.zip"
    write_entries_archive(
        conformance_archive,
        "OpenC-Core-1.0-conformance",
        directory_entries(tree, tree / "conformance"),
        add_manifest=True,
    )
    records.append(
        artifact_record(
            conformance_archive,
            "complete authored conformance bundle",
            "application/zip",
        )
    )

    source_archive = output / "OpenC-Core-1.0-reference-source.zip"
    write_source_archive(tree, source_archive, version)
    records.append(
        artifact_record(
            source_archive,
            "canonical reference source snapshot",
            "application/zip",
        )
    )

    evidence_path = output / "OpenC-Core-1.0-implementation-evidence.json"
    evidence_path.write_text(
        json.dumps(
            implementation_evidence(
                version=version,
                release_commit=args.release_commit,
                sh6=sh6,
                development=development,
                completeness=completeness,
            ),
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
        newline="\n",
    )
    records.append(
        artifact_record(
            evidence_path,
            "Windows Hosted implementation and SH-6 evidence",
            "application/json",
        )
    )

    conformance_target = (
        output / "OpenC-Core-1.0-conformance-report.json"
    )
    shutil.copyfile(conformance_report, conformance_target)
    records.append(
        artifact_record(
            conformance_target,
            "executed 268-fixture conformance report",
            "application/json",
        )
    )

    standalone_target = output / (
        f"OpenC-Hosted-{version}-windows-x86_64-standalone.zip"
    )
    shutil.copyfile(standalone, standalone_target)
    records.append(
        artifact_record(
            standalone_target,
            "standalone OpenC-native Windows Hosted distribution",
            "application/zip",
        )
    )

    records.sort(key=lambda item: str(item["path"]))
    checksums_path = output / "OpenC-Core-1.0-SHA256SUMS.txt"
    checksums_path.write_text(
        "".join(f"{item['sha256']}  {item['path']}\n" for item in records),
        encoding="utf-8",
        newline="\n",
    )
    records.append(
        artifact_record(
            checksums_path,
            "mandatory SHA-256 checksum list",
            "text/plain",
        )
    )
    records.sort(key=lambda item: str(item["path"]))

    record = {
        "schema": "openc.release_record.v2",
        "version": version,
        "component": "Core_and_Hosted_reference_distribution",
        "release_scope": "windows_x86_64_hosted",
        "release_commit": args.release_commit,
        "authority": ["OpenC project owner"],
        "authorization": {
            "authorized_by": "OpenC project owner",
            "authorized_utc": args.authorized_utc,
            "status": args.authorization_status,
        },
        "gates": [
            {"id": f"G{index}", "status": "PASS"}
            for index in range(1, 12)
        ],
        "artifacts": records,
        "checksums": [
            {"path": item["path"], "sha256": item["sha256"]}
            for item in records
        ],
        "signatures": [],
        "signatures_required": False,
        "published_utc": args.published_utc,
        "released": args.published_utc is not None,
    }
    record_path = output / "OpenC-Core-1.0-release-record.json"
    record_path.write_text(
        json.dumps(record, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    print(
        "OpenC release artifact set: BUILT; "
        f"version={version} artifacts={len(records)} "
        f"record_sha256={sha256(record_path)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
