#!/usr/bin/env python3
"""Verify SH-13 native throughput and implementation-independence evidence."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import zipfile


ROOT = Path(__file__).resolve().parents[1]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--timings", type=Path, required=True)
    parser.add_argument(
        "--rebuild-measurement", type=Path, required=True
    )
    parser.add_argument(
        "--validation-measurement", type=Path, required=True
    )
    parser.add_argument("--conformance", type=Path, required=True)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--comparison-archive", type=Path, required=True)
    parser.add_argument("--standalone-report", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    compiler = args.compiler.resolve()
    timings = load_json(args.timings.resolve())
    rebuild = load_json(args.rebuild_measurement.resolve())
    validation = load_json(args.validation_measurement.resolve())
    conformance = load_json(args.conformance.resolve())
    standalone = load_json(args.standalone_report.resolve())
    budgets = load_json(
        ROOT / "compiler" / "selfhost" / "WINDOWS_NATIVE_BUDGETS.json"
    )
    build_record = load_json(Path(str(compiler) + ".build.json"))

    archive = args.archive.resolve()
    comparison_archive = args.comparison_archive.resolve()
    with zipfile.ZipFile(archive) as bundle:
        entries = bundle.namelist()
    forbidden = [
        entry
        for entry in entries
        if Path(entry).suffix.lower() in {".d", ".py", ".pyc"}
        or Path(entry).name.lower() in {"dub.json", "dub.selections.json"}
    ]

    phases = timings.get("phases_ms", {})
    total_ms = int(timings.get("total_ms", 0))
    lowering_ms = int(phases.get("lowering_and_c_emission", 0))
    tinycc_ms = int(phases.get("tinycc", 0))
    rebuild_budget_ms = int(
        float(
            budgets["budgets"]["self_rebuild"]["max_elapsed_seconds"]
        )
        * 1000
    )
    rebuild_measurement = rebuild.get("measurement", {})
    rebuild_checks = rebuild.get("checks", {})
    rebuild_artifacts = rebuild.get("artifacts", {})
    self_rebuild_budget = budgets["budgets"]["self_rebuild"]
    validation_measurement = validation.get("measurement", {})
    validation_checks = validation.get("checks", {})
    validation_budget = budgets["budgets"]["validation"]
    standalone_checks = standalone.get("checks", {})
    authority = (ROOT / "AUTHORITY.md").read_text(encoding="utf-8")
    implementation_authority = (
        ROOT / "compiler" / "IMPLEMENTATION_AUTHORITY.md"
    ).read_text(encoding="utf-8")
    roadmap = (ROOT / "ROADMAP.md").read_text(encoding="utf-8")

    checks = {
        "timing_schema": (
            timings.get("schema") == "openc.native_build_timings.v1"
        ),
        "timing_status": timings.get("status") == "PASS",
        "timing_within_rebuild_budget": 0 < total_ms <= rebuild_budget_ms,
        "lowering_is_measured_separately": lowering_ms > 0,
        "tinycc_is_measured_separately": tinycc_ms > 0,
        "tinycc_below_five_percent": (
            total_ms > 0 and tinycc_ms * 20 < total_ms
        ),
        "monitored_rebuild_pass": (
            rebuild.get("schema")
            == "openc.native_self_rebuild_measurement.v2"
            and rebuild.get("status") == "PASS"
            and all(rebuild_checks.values())
        ),
        "monitored_rebuild_within_budgets": (
            0 < float(rebuild_measurement.get("elapsed_seconds", 0))
            <= float(self_rebuild_budget["max_elapsed_seconds"])
            and int(rebuild_measurement.get("peak_private_bytes", 0))
            <= int(self_rebuild_budget["max_peak_private_bytes"])
            and int(rebuild_measurement.get("peak_working_set_bytes", 0))
            <= int(self_rebuild_budget["max_peak_working_set_bytes"])
        ),
        "monitored_rebuild_is_byte_identical": (
            rebuild_artifacts.get("compiler_input", {}).get("sha256")
            == sha256(compiler)
            and rebuild_artifacts.get("output_executable", {}).get(
                "sha256"
            )
            == sha256(compiler)
        ),
        "monitored_validation_pass": (
            validation.get("schema")
            == "openc.native_validation_measurement.v1"
            and validation.get("status") == "PASS"
            and all(validation_checks.values())
            and validation.get("conformance", {}).get("passed") == 278
        ),
        "monitored_validation_within_budgets": (
            0 < float(validation_measurement.get("elapsed_seconds", 0))
            <= float(validation_budget["max_elapsed_seconds"])
            and int(validation_measurement.get("peak_private_bytes", 0))
            <= int(validation_budget["max_peak_private_bytes"])
            and int(validation_measurement.get("peak_working_set_bytes", 0))
            <= int(validation_budget["max_peak_working_set_bytes"])
        ),
        "native_build_record_pass": (
            build_record.get("status") == "PASS"
            and build_record.get("backend") == "c11-tinycc-win64"
        ),
        "native_build_invokes_no_dmd": (
            build_record.get("dmd_invoked") is False
        ),
        "native_build_invokes_no_dub": (
            build_record.get("dub_invoked") is False
        ),
        "native_build_invokes_no_python": (
            build_record.get("python_invoked") is False
        ),
        "native_conformance_278": (
            conformance.get("total") == 278
            and conformance.get("passed") == 278
            and conformance.get("failed") == 0
            and conformance.get("infrastructure_failures") == 0
        ),
        "independent_archives_byte_equal": (
            archive.read_bytes() == comparison_archive.read_bytes()
        ),
        "archive_excludes_d_python_and_dub": not forbidden,
        "relocated_standalone_pass": standalone.get("status") == "PASS",
        "relocated_package_exclusion_check": (
            standalone_checks.get(
                "package_excludes_d_and_python_source"
            )
            is True
        ),
        "canonical_authority_is_openc": (
            "canonical authored compiler implementation is the OpenC source"
            in authority
            and "canonical authored OpenC 1.0 compiler is written in OpenC"
            in implementation_authority
        ),
        "sh14_is_next": (
            "SH-14 native editor integration" in roadmap
        ),
    }
    failed = [name for name, passed in checks.items() if not passed]
    result = {
        "schema": "openc.sh13_throughput_independence.v1",
        "status": "PASS" if not failed else "FAIL",
        "checks": checks,
        "failed_checks": failed,
        "compiler": {
            "path": str(compiler),
            "sha256": sha256(compiler),
            "implementation_language": "OpenC",
        },
        "timings": {
            "path": str(args.timings.resolve()),
            "total_ms": total_ms,
            "lowering_and_c_emission_ms": lowering_ms,
            "tinycc_ms": tinycc_ms,
            "rebuild_budget_ms": rebuild_budget_ms,
        },
        "monitored_rebuild": {
            "path": str(args.rebuild_measurement.resolve()),
            "elapsed_seconds": rebuild_measurement.get("elapsed_seconds"),
            "peak_private_bytes": rebuild_measurement.get(
                "peak_private_bytes"
            ),
            "peak_working_set_bytes": rebuild_measurement.get(
                "peak_working_set_bytes"
            ),
        },
        "monitored_validation": {
            "path": str(args.validation_measurement.resolve()),
            "elapsed_seconds": validation_measurement.get(
                "elapsed_seconds"
            ),
            "peak_private_bytes": validation_measurement.get(
                "peak_private_bytes"
            ),
            "peak_working_set_bytes": validation_measurement.get(
                "peak_working_set_bytes"
            ),
        },
        "conformance": {
            "path": str(args.conformance.resolve()),
            "passed": conformance.get("passed"),
            "total": conformance.get("total"),
        },
        "standalone": {
            "archive_sha256": sha256(archive),
            "archive_bytes": archive.stat().st_size,
            "archive_entries": len(entries),
            "forbidden_entries": forbidden,
            "report": str(args.standalone_report.resolve()),
        },
        "dependency_boundary": {
            "d_source_packaged": False,
            "python_source_packaged": False,
            "python_is_external_evidence_only": True,
            "tinycc_backend_required": True,
            "first_party_native_code_backend_complete": False,
        },
    }
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(
        "SH-13 throughput/independence: "
        + ("PASS" if not failed else "FAIL")
    )
    if failed:
        raise SystemExit("failed checks: " + ", ".join(failed))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
