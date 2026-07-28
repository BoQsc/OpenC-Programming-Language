#!/usr/bin/env python3
"""Build the deterministic OpenC standalone Windows distribution."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys
import zipfile

from build_source_archive import included_files


EPOCH = (1980, 1, 1, 0, 0, 0)
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from native_toolchain import resolve_native_compiler, validate_native_compiler


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare_directory(path: Path, force: bool) -> None:
    if path.exists():
        if not force:
            raise SystemExit(f"output tree already exists: {path}")
        if path == Path(path.anchor) or len(path.parts) < 3:
            raise SystemExit(f"refusing to replace broad output path: {path}")
        shutil.rmtree(path)
    path.mkdir(parents=True)


def copy_source_tree(source: Path, destination: Path) -> int:
    count = 0
    for path in included_files(source):
        relative = path.relative_to(source)
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        count += 1
    return count


def write_manifest(root: Path) -> Path:
    manifest = root / "STANDALONE-MANIFEST.sha256"
    lines = []
    for path in sorted(root.rglob("*")):
        if path.is_file() and path != manifest:
            lines.append(f"{sha256(path)}  {path.relative_to(root).as_posix()}")
    manifest.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    return manifest


def write_archive(tree: Path, archive: Path) -> None:
    archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(
        archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
    ) as bundle:
        for path in sorted(tree.rglob("*")):
            if not path.is_file():
                continue
            relative = Path(tree.name) / path.relative_to(tree)
            info = zipfile.ZipInfo(relative.as_posix(), EPOCH)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            bundle.writestr(info, path.read_bytes())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--tree", type=Path, default=Path(__file__).resolve().parents[1]
    )
    parser.add_argument(
        "--compiler",
        type=Path,
        help="verified OpenC-native compiler; defaults to the installed toolchain",
    )
    parser.add_argument("--bootstrap-seed", type=Path)
    parser.add_argument("--version")
    parser.add_argument("--output-tree", type=Path, required=True)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    source = args.tree.resolve()
    compiler = resolve_native_compiler(args.compiler)
    native_compiler = validate_native_compiler(compiler)
    seed = (
        args.bootstrap_seed.resolve()
        if args.bootstrap_seed
        else source / "compiler" / "openc.exe"
    )
    version = args.version or (source / "VERSION").read_text(
        encoding="utf-8"
    ).strip()
    output_tree = args.output_tree.resolve()
    archive = args.archive.resolve()
    if not compiler.is_file():
        raise SystemExit(f"missing OpenC-native compiler: {compiler}")
    if not seed.is_file():
        raise SystemExit(f"missing retained bootstrap seed: {seed}")
    if source == output_tree or source in output_tree.parents:
        if "build-output" not in output_tree.parts:
            raise SystemExit("output tree inside source must be under build-output")

    prepare_directory(output_tree, args.force)
    source_files = copy_source_tree(source, output_tree)

    shutil.copyfile(compiler, output_tree / "openc.exe")
    shutil.copyfile(
        Path(str(compiler) + ".build.json"),
        output_tree / "openc.exe.build.json",
    )
    bootstrap = output_tree / "bootstrap"
    bootstrap.mkdir(exist_ok=True)
    shutil.copyfile(seed, bootstrap / "openc-stage0.exe")
    readme = source / "release" / "STANDALONE_WINDOWS_README.md"
    shutil.copyfile(readme, output_tree / "README-STANDALONE.md")

    required = (
        output_tree / "compiler" / "selfhost" / "openc.project.json",
        output_tree / "runtime" / "common" / "source" / "openc_runtime.c",
        output_tree
        / "runtime"
        / "windows"
        / "source"
        / "openc_platform_windows.c",
        output_tree
        / "compiler"
        / "selfhost"
        / "native_runtime"
        / "openc_sh5_runtime.c",
        output_tree / "standard_library" / "openc.project.json",
        output_tree / "third_party" / "tinycc-win64" / "tcc.exe",
        output_tree
        / "third_party"
        / "tinycc-win64"
        / "source"
        / "tcc-0.9.27.tar.bz2",
        output_tree / "conformance" / "fixtures" / "MANIFEST.json",
        output_tree / "conformance" / "fixtures" / "NATIVE_PLAN.tsv",
        output_tree
        / "compiler"
        / "selfhost"
        / "source"
        / "native_conformance.p",
    )
    missing = [str(path.relative_to(output_tree)) for path in required if not path.is_file()]
    if missing:
        raise SystemExit(f"standalone inputs missing: {', '.join(missing)}")

    release_record = {
        "schema": "openc.standalone_windows_distribution.v1",
        "version": version,
        "target": "windows-x86_64-hosted",
        "compiler": {
            "path": "openc.exe",
            "implementation_language": "OpenC",
            "sha256": sha256(output_tree / "openc.exe"),
            "native_build_record_sha256": native_compiler["build_record_sha256"],
            "public_build_command": (
                "openc.exe build --project=PROJECT --output=OUTPUT-EXE"
            ),
            "public_check_command": (
                "openc.exe check --project=PROJECT "
                "[--output=CHECK-RECORD.json]"
            ),
            "public_run_command": (
                "openc.exe run --project=PROJECT [-- PROGRAM-ARGUMENTS...]"
            ),
            "public_format_commands": [
                "openc.exe fmt --check (--project=PROJECT|SOURCE.p)",
                "openc.exe fmt --write (--project=PROJECT|SOURCE.p)",
            ],
            "public_project_info_command": (
                "openc.exe info --project=PROJECT "
                "[--context|--sources|--modules|--limits|--dependencies|"
                "--target|--types] [--json]"
            ),
            "public_test_command": (
                "openc.exe test (--manifest=TESTS.json|--project=PROJECT) "
                "[--list] [--filter=TEXT] [--jobs=N] [--no-run]"
            ),
            "public_language_service_command": "openc.exe lsp --stdio",
            "public_validate_command": (
                "openc.exe validate --manifest=MANIFEST --output=REPORT"
            ),
            "public_information_commands": [
                "openc.exe version",
                "openc.exe target",
                "openc.exe explain RULE-ID",
            ],
        },
        "bootstrap_seed": {
            "path": "bootstrap/openc-stage0.exe",
            "implementation_language": "D",
            "role": (
                "optional retained D comparison oracle; not a native build "
                "or required conformance dependency"
            ),
            "sha256": sha256(bootstrap / "openc-stage0.exe"),
            "executed_during_packaging": False,
        },
        "backend": {
            "name": "TinyCC 0.9.27 Win64",
            "path": "third_party/tinycc-win64/tcc.exe",
            "sha256": sha256(
                output_tree / "third_party" / "tinycc-win64" / "tcc.exe"
            ),
            "corresponding_source_included": True,
        },
        "source_files_copied": source_files,
        "runtime_inputs": [
            "runtime/common/source/openc_runtime.c",
            "runtime/windows/source/openc_platform_windows.c",
            "compiler/selfhost/native_runtime/openc_sh5_runtime.c",
        ],
        "library_inputs": {
            "native_compiler_mode": (
                "six compiler-provided system modules exercised while "
                "rebuilding the compiler and maintained programs"
            ),
            "bootstrap_seed_mode": "standard_library/source/openc/std/*.d",
            "authored_native_provider_sources": (
                "standard_library/system.*/source/*.p"
            ),
            "authored_native_provider_status": (
                "included for future Native-provider work; outside the "
                "Windows Hosted SH-12 gate"
            ),
        },
        "required_conformance_runner": {
            "command": (
                "openc.exe validate --manifest=conformance/fixtures/MANIFEST.json "
                "--output=conformance-report.json"
            ),
            "implementation_language": "OpenC",
            "fixtures": 278,
            "retained_d_seed_required": False,
        },
        "linux_and_freestanding_gate": False,
    }
    (output_tree / "STANDALONE-RELEASE.json").write_text(
        json.dumps(release_record, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    manifest = write_manifest(output_tree)
    write_archive(output_tree, archive)
    print(
        "standalone Windows distribution: BUILT; "
        f"files={sum(1 for path in output_tree.rglob('*') if path.is_file())} "
        f"manifest={sha256(manifest)} archive={sha256(archive)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
