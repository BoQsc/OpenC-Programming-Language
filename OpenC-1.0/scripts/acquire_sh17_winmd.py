#!/usr/bin/env python3
"""Acquire and verify the exact SH-17 Win32 Metadata projection input."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import urllib.request
import zipfile


ROOT = Path(__file__).resolve().parents[1]
PIN = ROOT / "compiler/targets/windows-win32-metadata.json"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "build-output/selfhost-sh17/input",
    )
    args = parser.parse_args()
    pin = json.loads(PIN.read_text(encoding="utf-8"))
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    package = output / f"{pin['package']}.{pin['version']}.nupkg"
    if not package.is_file() or digest(package.read_bytes()) != pin["package_sha256"]:
        with urllib.request.urlopen(pin["package_url"], timeout=120) as response:
            package_data = response.read()
        if digest(package_data) != pin["package_sha256"]:
            raise SystemExit("downloaded Win32 Metadata package hash mismatch")
        package.write_bytes(package_data)
    with zipfile.ZipFile(package) as archive:
        metadata = archive.read(pin["member"])
        license_data = archive.read(pin["license_member"])
    checks = {
        "metadata_bytes": len(metadata) == pin["member_bytes"],
        "metadata_sha256": digest(metadata) == pin["member_sha256"],
        "license_sha256": digest(license_data) == pin["license_sha256"],
    }
    if not all(checks.values()):
        raise SystemExit(f"Win32 Metadata package member mismatch: {checks}")
    (output / pin["member"]).write_bytes(metadata)
    (output / pin["license_member"]).write_bytes(license_data)
    record = {
        "schema": "openc.sh17_winmd_acquisition.v1",
        "status": "PASS",
        "pin": str(PIN.relative_to(ROOT)).replace("\\", "/"),
        "checks": checks,
        "normal_build_or_runtime_dependency": False,
    }
    record_path = output / "acquisition.json"
    record_path.write_text(
        json.dumps(record, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(f"SH-17 WinMD acquisition: PASS; metadata={output / pin['member']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
