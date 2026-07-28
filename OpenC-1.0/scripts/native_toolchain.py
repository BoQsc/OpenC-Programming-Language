#!/usr/bin/env python3
"""Install, resolve, and verify the Windows OpenC-native toolchain."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
INSTALL_ROOT = ROOT / "build-output" / "native-toolchain"
DEFAULT_DISTRIBUTION = INSTALL_ROOT / "distribution"
PROVENANCE_NAME = "NATIVE-TOOLCHAIN.json"
NATIVE_BUILD_SCHEMA = "openc-sh5-windows-build-v1"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def digest_paths(root: Path, paths: list[Path]) -> str:
    """Hash path names and bytes in a stable order."""
    digest = hashlib.sha256()
    files: set[Path] = set()
    for path in paths:
        path = path.resolve()
        if path.is_dir():
            files.update(item.resolve() for item in path.rglob("*") if item.is_file())
        elif path.is_file():
            files.add(path)
        else:
            raise FileNotFoundError(path)
    for path in sorted(files, key=lambda item: item.as_posix().casefold()):
        try:
            relative = path.relative_to(root.resolve()).as_posix()
        except ValueError:
            relative = path.as_posix()
        encoded = relative.encode("utf-8")
        digest.update(len(encoded).to_bytes(8, "little"))
        digest.update(encoded)
        data = path.read_bytes()
        digest.update(len(data).to_bytes(8, "little"))
        digest.update(data)
    return digest.hexdigest()


def compiler_source_inputs(root: Path = ROOT) -> list[Path]:
    project_path = root / "compiler" / "selfhost" / "openc.project.json"
    project = json.loads(project_path.read_text(encoding="utf-8"))
    inputs = [project_path]
    inputs.extend(
        project_path.parent / source
        for sources in project["modules"].values()
        for source in sources
    )
    inputs.append(root / "standard_library" / "openc.project.json")
    inputs.extend(
        sorted(
            (root / "standard_library").glob("system.*/source/*.p"),
            key=lambda path: path.as_posix(),
        )
    )
    inputs.extend(
        [
            root / "runtime" / "common" / "source" / "openc_runtime.c",
            root / "runtime" / "common" / "source" / "openc_runtime.h",
            root
            / "runtime"
            / "windows"
            / "source"
            / "openc_platform_windows.c",
            root
            / "compiler"
            / "selfhost"
            / "native_runtime"
            / "openc_sh5_runtime.c",
            root
            / "compiler"
            / "selfhost"
            / "native_runtime"
            / "openc_sh5_runtime.h",
            root / "third_party" / "tinycc-win64" / "tcc.exe",
        ]
    )
    return inputs


def compiler_source_fingerprint(root: Path = ROOT) -> str:
    return digest_paths(root, compiler_source_inputs(root))


def validate_native_compiler(compiler: Path) -> dict[str, object]:
    compiler = compiler.resolve()
    if not compiler.is_file():
        raise ValueError(f"missing native compiler: {compiler}")
    distribution = compiler.parent
    record_path = Path(str(compiler) + ".build.json")
    if not record_path.is_file():
        raise ValueError(f"missing native build record: {record_path}")
    try:
        record = json.loads(record_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"invalid native build record: {record_path}: {exc}") from exc
    required_record = (
        record.get("schema") == NATIVE_BUILD_SCHEMA
        and record.get("status") == "PASS"
        and record.get("backend") == "c11-tinycc-win64"
        and record.get("dmd_invoked") is False
        and record.get("dub_invoked") is False
        and record.get("python_invoked") is False
    )
    if not required_record:
        raise ValueError(f"compiler is not a verified OpenC-native build: {compiler}")
    required_distribution_files = [
        distribution / "runtime" / "common" / "source" / "openc_runtime.c",
        distribution / "runtime" / "windows" / "source" / "openc_platform_windows.c",
        distribution
        / "compiler"
        / "selfhost"
        / "native_runtime"
        / "openc_sh5_runtime.c",
        distribution / "third_party" / "tinycc-win64" / "tcc.exe",
    ]
    missing = [str(path) for path in required_distribution_files if not path.is_file()]
    if missing:
        raise ValueError(
            "native compiler is not in a complete standalone distribution: "
            + ", ".join(missing)
        )
    return {
        "compiler": str(compiler),
        "compiler_sha256": sha256(compiler),
        "build_record": str(record_path),
        "build_record_sha256": sha256(record_path),
        "distribution": str(distribution),
        "dmd_invoked": False,
        "dub_invoked": False,
        "python_invoked": False,
    }


def candidate_compilers() -> list[Path]:
    candidates: list[Path] = []
    environment = os.environ.get("OPENC_NATIVE_COMPILER")
    if environment:
        candidates.append(Path(environment))
    candidates.extend(
        [
            DEFAULT_DISTRIBUTION / "openc.exe",
            ROOT
            / "build-output"
            / "selfhost-sh8"
            / "closure"
            / "stage3-distribution"
            / "openc.exe",
            ROOT
            / "build-output"
            / "selfhost-sh7"
            / "final"
            / "stage3-distribution"
            / "openc.exe",
            ROOT
            / "build-output"
            / "selfhost-rc9"
            / "final-v2"
            / "stage3-distribution"
            / "openc.exe",
        ]
    )
    return candidates


def resolve_native_compiler(explicit: Path | None = None) -> Path:
    candidates = [explicit] if explicit is not None else candidate_compilers()
    failures: list[str] = []
    for candidate in candidates:
        if candidate is None:
            continue
        try:
            validate_native_compiler(candidate)
            return candidate.resolve()
        except ValueError as exc:
            failures.append(str(exc))
    detail = "\n".join(f"  - {failure}" for failure in failures)
    raise SystemExit(
        "no verified OpenC-native Windows toolchain is installed.\n"
        "Install one with:\n"
        "  python scripts/native_toolchain.py install "
        "--distribution PATH/TO/STANDALONE-DISTRIBUTION\n"
        + (f"Candidates checked:\n{detail}" if detail else "")
    )


def _safe_install_destination(destination: Path) -> Path:
    destination = destination.resolve()
    allowed = INSTALL_ROOT.resolve()
    if destination != allowed and allowed not in destination.parents:
        raise SystemExit(
            f"refusing to replace toolchain outside {allowed}: {destination}"
        )
    return destination


def _archive_distribution(archive: Path, temporary: Path) -> Path:
    with zipfile.ZipFile(archive) as bundle:
        bundle.extractall(temporary)
    roots = [path for path in temporary.iterdir() if path.is_dir()]
    if len(roots) == 1 and (roots[0] / "openc.exe").is_file():
        return roots[0]
    if (temporary / "openc.exe").is_file():
        return temporary
    matches = list(temporary.rglob("openc.exe"))
    distributions = [
        path.parent
        for path in matches
        if (path.parent / "runtime" / "common" / "source" / "openc_runtime.c").is_file()
    ]
    if len(distributions) != 1:
        raise SystemExit("archive does not contain exactly one standalone distribution")
    return distributions[0]


def install_distribution(
    source: Path,
    destination: Path = DEFAULT_DISTRIBUTION,
) -> dict[str, object]:
    source = source.resolve()
    destination = _safe_install_destination(destination)
    validate_native_compiler(source / "openc.exe")
    if source == destination:
        raise SystemExit("source distribution is already the install destination")
    if destination.exists():
        shutil.rmtree(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, destination)
    compiler = destination / "openc.exe"
    native = validate_native_compiler(compiler)
    provenance = {
        "schema": "openc.native_toolchain_install.v1",
        "status": "PASS",
        "compiler": native,
        "compiler_source_fingerprint": compiler_source_fingerprint(destination),
        "current_source_fingerprint": compiler_source_fingerprint(ROOT),
        "source_matches_current_tree": (
            compiler_source_fingerprint(destination)
            == compiler_source_fingerprint(ROOT)
        ),
        "retained_d_seed_executed": False,
    }
    (destination / PROVENANCE_NAME).write_text(
        json.dumps(provenance, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    return provenance


def installed_provenance(compiler: Path) -> dict[str, object]:
    path = compiler.resolve().parent / PROVENANCE_NAME
    if path.is_file():
        provenance = json.loads(path.read_text(encoding="utf-8"))
        distribution_fingerprint = compiler_source_fingerprint(
            compiler.resolve().parent
        )
        current_fingerprint = compiler_source_fingerprint(ROOT)
        provenance["compiler_source_fingerprint"] = distribution_fingerprint
        provenance["current_source_fingerprint"] = current_fingerprint
        provenance["source_matches_current_tree"] = (
            distribution_fingerprint == current_fingerprint
        )
        return provenance
    distribution_fingerprint = compiler_source_fingerprint(compiler.resolve().parent)
    current_fingerprint = compiler_source_fingerprint(ROOT)
    return {
        "schema": "openc.native_toolchain_ephemeral_provenance.v1",
        "status": "PASS",
        "compiler_source_fingerprint": distribution_fingerprint,
        "current_source_fingerprint": current_fingerprint,
        "source_matches_current_tree": distribution_fingerprint == current_fingerprint,
        "retained_d_seed_executed": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    install = subparsers.add_parser("install")
    install_source = install.add_mutually_exclusive_group(required=True)
    install_source.add_argument("--distribution", type=Path)
    install_source.add_argument("--archive", type=Path)
    install.add_argument("--destination", type=Path, default=DEFAULT_DISTRIBUTION)
    status = subparsers.add_parser("status")
    status.add_argument("--compiler", type=Path)
    args = parser.parse_args()

    if args.command == "install":
        if args.distribution:
            provenance = install_distribution(args.distribution, args.destination)
        else:
            archive = args.archive.resolve()
            if not archive.is_file():
                raise SystemExit(f"missing standalone archive: {archive}")
            with tempfile.TemporaryDirectory(
                prefix="openc-native-toolchain-",
                dir=INSTALL_ROOT.parent,
            ) as directory:
                source = _archive_distribution(archive, Path(directory))
                provenance = install_distribution(source, args.destination)
        print(json.dumps(provenance, indent=2, sort_keys=True))
        return 0

    compiler = resolve_native_compiler(args.compiler)
    result = {
        "schema": "openc.native_toolchain_status.v1",
        "status": "PASS",
        "native": validate_native_compiler(compiler),
        "provenance": installed_provenance(compiler),
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
