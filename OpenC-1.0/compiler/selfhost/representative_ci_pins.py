#!/usr/bin/env python3
"""Discover, verify, and consume separately recorded representative CI pins.

Discovery never edits the checked-in pin file or supplies discovered digests to
the proof as expectations. The proof consumes only literal reviewed pin values.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
REPOSITORY = ROOT.parent
PINS = REPOSITORY / ".github/representative-toolchain-pins.json"
PIN_SCHEMA = "openc.sh27.representative_toolchain_pins.v2"
DISCOVERY_SCHEMA = "openc.sh27.representative_toolchain_discovery.v1"
HEX = set("0123456789abcdef")


def valid_digest(value: object) -> bool:
    return isinstance(value, str) and len(value) == 64 and not (
        set(value.lower()) - HEX
    )


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_pins(path: Path) -> dict[str, object]:
    pins = json.loads(path.read_text(encoding="utf-8"))
    if pins.get("schema") != PIN_SCHEMA or pins.get("runner") != "windows-2025":
        raise ValueError("unsupported representative CI pin schema or runner")
    if pins.get("msvc_toolset") != "14.44":
        raise ValueError("workflow and pin file must agree on MSVC toolset 14.44")
    if pins.get("status") not in {"PENDING_DISCOVERY", "PINNED"}:
        raise ValueError("pin status must be PENDING_DISCOVERY or PINNED")
    for key in ("msvc_version_contains", "dmd_version_contains"):
        if not isinstance(pins.get(key), str) or not pins[key]:
            raise ValueError(f"missing version selector: {key}")
    dmd_digest = pins.get("dmd_sha256")
    if dmd_digest is not None and not valid_digest(dmd_digest):
        raise ValueError("invalid SHA-256 pin: dmd_sha256")
    if pins["status"] == "PINNED" and dmd_digest is None:
        raise ValueError("PINNED state requires dmd_sha256")
    variants = pins.get("msvc_variants")
    if not isinstance(variants, list) or len(variants) > 8:
        raise ValueError("msvc_variants must be a bounded list")
    if pins["status"] == "PINNED" and not variants:
        raise ValueError("PINNED state requires reviewed MSVC variants")
    seen_images: set[str] = set()
    for variant in variants:
        if not isinstance(variant, dict):
            raise ValueError("invalid MSVC variant")
        image = variant.get("runner_image_version")
        if not isinstance(image, str) or not image or image in seen_images:
            raise ValueError("missing or duplicate runner image version")
        seen_images.add(image)
        for key in ("cl_sha256", "link_sha256"):
            if not valid_digest(variant.get(key)):
                raise ValueError(f"invalid reviewed MSVC variant {key}")
    return pins


def tool_record(name: str, arguments: list[str]) -> dict[str, object]:
    found = shutil.which(name)
    if found is None:
        raise ValueError(f"required pinned setup tool not found: {name}")
    executable = Path(found).resolve()
    version = subprocess.run(
        [str(executable), *arguments], capture_output=True, text=True,
        encoding="utf-8", errors="replace", timeout=15,
    )
    return {
        "path": str(executable), "sha256": sha256(executable),
        "version_command": [str(executable), *arguments],
        "version_exit_code": version.returncode,
        "version_output": (version.stdout + version.stderr)[:16384],
    }


def discover(pins_path: Path) -> dict[str, object]:
    pins = load_pins(pins_path)
    image_version = os.environ.get("ImageVersion")
    tools = {
        "cl": tool_record("cl.exe", []),
        "link": tool_record("link.exe", []),
        "dmd": tool_record("dmd.exe", ["--version"]),
    }
    matched = next(
        (variant for variant in pins["msvc_variants"]
         if variant["runner_image_version"] == image_version),
        None,
    )
    checks = {
        "pin_status_reviewed": pins["status"] == "PINNED",
        "runner_image_reviewed": matched is not None,
        "cl_sha256_matches": matched is not None and
            str(matched["cl_sha256"]).lower() == tools["cl"]["sha256"],
        "link_sha256_matches": matched is not None and
            str(matched["link_sha256"]).lower() == tools["link"]["sha256"],
        "dmd_sha256_matches": pins["dmd_sha256"] is not None and
            str(pins["dmd_sha256"]).lower() == tools["dmd"]["sha256"],
        "msvc_version_matches": str(pins["msvc_version_contains"]) in
            str(tools["cl"]["version_output"]),
        "dmd_version_matches": str(pins["dmd_version_contains"]) in
            str(tools["dmd"]["version_output"]),
    }
    ready = all(checks.values())
    status = "PASS" if ready else (
        "PENDING" if pins["status"] == "PENDING_DISCOVERY" else "FAIL"
    )
    return {
        "schema": DISCOVERY_SCHEMA,
        "status": status,
        "pins_ready": ready,
        "discovered_at_utc": datetime.now(timezone.utc).isoformat(),
        "host": {
            "system": platform.system(), "release": platform.release(),
            "machine": platform.machine(),
            "runner_image_version": image_version,
        },
        "selected_msvc_variant": matched,
        "pins_file": {"path": str(pins_path), "sha256": sha256(pins_path)},
        "checks": checks,
        "tools": tools,
        "next_action": (
            "Record the runner image and reviewed literal cl/link/dmd "
            "digests in the checked-in pin file, then rerun the proof. "
            "Discovery output is not a proof pin."
            if not ready else "Run the separately gated proof job."
        ),
    }


def require_ready(pins_path: Path) -> tuple[dict[str, object], dict[str, object]]:
    pins = load_pins(pins_path)
    record = discover(pins_path)
    if not record["pins_ready"]:
        failed = [key for key, passed in record["checks"].items() if not passed]
        raise ValueError("representative toolchain pins not ready: " + ", ".join(failed))
    return pins, record


def write_report(path: Path, record: dict[str, object]) -> None:
    if path.exists():
        raise ValueError(f"refusing to overwrite discovery report: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    discovery = sub.add_parser("discover")
    discovery.add_argument("--pins", type=Path, default=PINS)
    discovery.add_argument("--output", type=Path, required=True)
    discovery.add_argument("--github-output", type=Path)
    verification = sub.add_parser("verify")
    verification.add_argument("--pins", type=Path, default=PINS)
    proof = sub.add_parser("run-proof")
    proof.add_argument("--pins", type=Path, default=PINS)
    proof.add_argument("--compiler", type=Path, required=True)
    proof.add_argument("--output", type=Path, required=True)
    proof.add_argument("--runs", type=int, default=3)
    args = parser.parse_args()
    try:
        if args.command == "discover":
            record = discover(args.pins.resolve())
            write_report(args.output.resolve(), record)
            if args.github_output is not None:
                with args.github_output.open("a", encoding="utf-8") as stream:
                    stream.write(
                        "pins_ready=" + ("true" if record["pins_ready"] else "false")
                        + "\n"
                    )
            print(f"representative pins: {record['status']}; {args.output}")
            return 0 if record["status"] != "FAIL" else 1
        pins, record = require_ready(args.pins.resolve())
        print(f"representative pins: {record['status']}")
        if args.command == "verify":
            return 0
        if not 1 <= args.runs <= 20:
            raise ValueError("--runs must be 1..20")
        compiler = args.compiler.resolve(strict=True)
        command = [
            sys.executable,
            str(ROOT / "compiler/selfhost/benchmark_sh27_representative.py"),
            "--compiler", str(compiler),
            "--workload", "medium_audit",
            "--with-comparators",
            "--c-compiler", str(record["tools"]["cl"]["path"]),
            "--c-sha256", str(record["selected_msvc_variant"]["cl_sha256"]),
            "--c-linker-sha256", str(record["selected_msvc_variant"]["link_sha256"]),
            "--d-compiler", str(record["tools"]["dmd"]["path"]),
            "--d-sha256", str(pins["dmd_sha256"]),
            "--runs", str(args.runs),
            "--output", str(args.output.resolve()),
        ]
        return subprocess.run(command, cwd=REPOSITORY, check=False).returncode
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"representative pin/proof error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
