#!/usr/bin/env python3
"""Exercise the packaged OpenC VSIX in a genuinely empty VS Code profile."""

from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import time


TH32CS_SNAPPROCESS = 0x00000002
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
PROCESS_VM_READ = 0x0010
VSCODE_WORKING_SET_LIMIT = 2 * 1024 * 1024 * 1024
OPENC_WORKING_SET_LIMIT = 64 * 1024 * 1024


class PROCESSENTRY32W(ctypes.Structure):
    _fields_ = [
        ("dwSize", ctypes.c_ulong),
        ("cntUsage", ctypes.c_ulong),
        ("th32ProcessID", ctypes.c_ulong),
        ("th32DefaultHeapID", ctypes.c_size_t),
        ("th32ModuleID", ctypes.c_ulong),
        ("cntThreads", ctypes.c_ulong),
        ("th32ParentProcessID", ctypes.c_ulong),
        ("pcPriClassBase", ctypes.c_long),
        ("dwFlags", ctypes.c_ulong),
        ("szExeFile", ctypes.c_wchar * 260),
    ]


class PROCESS_MEMORY_COUNTERS_EX(ctypes.Structure):
    _fields_ = [
        ("cb", ctypes.c_ulong),
        ("PageFaultCount", ctypes.c_ulong),
        ("PeakWorkingSetSize", ctypes.c_size_t),
        ("WorkingSetSize", ctypes.c_size_t),
        ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
        ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
        ("PagefileUsage", ctypes.c_size_t),
        ("PeakPagefileUsage", ctypes.c_size_t),
        ("PrivateUsage", ctypes.c_size_t),
    ]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def run(command: list[str], *, timeout: int = 120) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        check=False,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        timeout=timeout,
    )


def vscode_cli_prefix(code: Path) -> list[str]:
    """Use VS Code's shipped CLI entry point without a shell or global state."""
    if code.suffix.lower() == ".cmd":
        install_root = code.parent.parent
        executable = install_root / "Code.exe"
        cli_candidates = sorted(
            install_root.glob("*/resources/app/out/cli.js")
        )
        launcher = code.read_text(encoding="utf-8", errors="replace")
        match = re.search(
            r"\\([0-9a-fA-F]+)\\resources\\app\\out\\cli\.js",
            launcher,
        )
        if match:
            cli_candidates = [
                candidate for candidate in cli_candidates
                if candidate.relative_to(install_root).parts[0] == match.group(1)
            ]
        if len(cli_candidates) != 1:
            raise RuntimeError(
                f"expected one bundled VS Code CLI, found {len(cli_candidates)}"
            )
        cli_script = cli_candidates[0]
        executable.resolve(strict=True)
        cli_script.resolve(strict=True)
        return [str(executable), str(cli_script)]
    return [str(code)]


def process_tree(root_pid: int) -> dict[int, str]:
    kernel32 = ctypes.windll.kernel32
    snapshot = kernel32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    if snapshot in (0, ctypes.c_void_p(-1).value):
        return {root_pid: "unknown"}
    parents: dict[int, int] = {}
    names: dict[int, str] = {}
    entry = PROCESSENTRY32W()
    entry.dwSize = ctypes.sizeof(entry)
    if kernel32.Process32FirstW(snapshot, ctypes.byref(entry)):
        while True:
            parents[int(entry.th32ProcessID)] = int(entry.th32ParentProcessID)
            names[int(entry.th32ProcessID)] = entry.szExeFile
            if not kernel32.Process32NextW(snapshot, ctypes.byref(entry)):
                break
    kernel32.CloseHandle(snapshot)
    result = {root_pid}
    changed = True
    while changed:
        changed = False
        for pid, parent in parents.items():
            if parent in result and pid not in result:
                result.add(pid)
                changed = True
    return {pid: names.get(pid, "unknown") for pid in result}


def working_set(pid: int) -> int:
    kernel32 = ctypes.windll.kernel32
    psapi = ctypes.windll.psapi
    handle = kernel32.OpenProcess(
        PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ, False, pid
    )
    if not handle:
        return 0
    counters = PROCESS_MEMORY_COUNTERS_EX()
    counters.cb = ctypes.sizeof(counters)
    ok = psapi.GetProcessMemoryInfo(
        handle, ctypes.byref(counters), ctypes.sizeof(counters)
    )
    kernel32.CloseHandle(handle)
    return int(counters.WorkingSetSize) if ok else 0


def log_text(profile: Path) -> str:
    chunks: list[str] = []
    logs = profile / "logs"
    if not logs.exists():
        return ""
    for candidate in sorted(logs.rglob("*")):
        if candidate.is_file() and candidate.stat().st_size <= 8 * 1024 * 1024:
            try:
                chunks.append(candidate.read_text(encoding="utf-8", errors="replace"))
            except OSError:
                pass
    return "\n".join(chunks)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--code", type=Path, required=True)
    parser.add_argument("--vsix", type=Path, required=True)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument(
        "--ui-controller-status", default="unavailable_kernel_asset_path"
    )
    args = parser.parse_args()

    if sys.platform != "win32":
        raise SystemExit("SH-25 clean-profile evidence requires Windows")
    code = args.code.resolve(strict=True)
    code_prefix = vscode_cli_prefix(code)
    os.environ["ELECTRON_RUN_AS_NODE"] = "1"
    os.environ.pop("VSCODE_DEV", None)
    vsix = args.vsix.resolve(strict=True)
    compiler = args.compiler.resolve(strict=True)
    output_root = args.output_root.resolve()
    if output_root.exists():
        raise SystemExit(f"refusing to reuse non-clean output root: {output_root}")
    profile = output_root / "profile"
    extensions = output_root / "extensions"
    workspace = output_root / "workspace"
    profile.mkdir(parents=True)
    extensions.mkdir()
    workspace.mkdir()
    source = workspace / "main.p"
    source.write_text("i32 main( {\n", encoding="utf-8", newline="\n")

    base = code_prefix + [
        "--user-data-dir", str(profile),
        "--extensions-dir", str(extensions),
    ]
    version_run = run(code_prefix + ["--version"])
    version_lines = [line.strip() for line in version_run.stdout.splitlines() if line.strip()]
    vscode_version = version_lines[0] if version_lines else ""
    major = int(vscode_version.split(".", 1)[0]) if vscode_version[:1].isdigit() else 0
    version_supported = major >= 1 and tuple(
        int(part) for part in vscode_version.split(".")[:2]
    ) >= (1, 85)

    before = run(base + ["--list-extensions", "--show-versions"])
    preexisting = [line.strip() for line in before.stdout.splitlines() if line.strip()]
    install = run(base + ["--install-extension", str(vsix), "--force"])
    after = run(base + ["--list-extensions", "--show-versions"])
    installed = [line.strip() for line in after.stdout.splitlines() if line.strip()]
    expected_extension = "openc-language.openc@1.0.0"

    launch_command = base + [
        "--new-window",
        "--wait",
        "--disable-workspace-trust",
        "--disable-telemetry",
        "--disable-updates",
        "--disable-crash-reporter",
        "--disable-experiments",
        "--skip-welcome",
        "--skip-release-notes",
        "--skip-add-to-recently-opened",
        "--log", "trace",
        str(source),
    ]
    launched = subprocess.Popen(
        launch_command,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        env=os.environ.copy(),
    )
    peak_working_set = 0
    openc_peak_working_set = 0
    combined_logs = ""
    deadline = time.monotonic() + 45
    extension_activated = False
    language_server_ready = False
    diagnostics_roundtrip = False
    packaged_compiler_selected = False
    while time.monotonic() < deadline:
        processes = process_tree(launched.pid)
        peak_working_set = max(
            peak_working_set, sum(working_set(pid) for pid in processes)
        )
        openc_peak_working_set = max(
            openc_peak_working_set,
            sum(
                working_set(pid) for pid, name in processes.items()
                if name.lower() == "openc.exe"
            ),
        )
        combined_logs = log_text(profile)
        extension_activated = (
            "[OpenC] extension activated" in combined_logs
            or "ExtensionService#_doActivateExtension openc-language.openc" in combined_logs
        )
        started_server = (
            "Starting " in combined_logs
            and "openc-language.openc-1.0.0" in combined_logs
            and "openc.exe lsp --stdio" in combined_logs
        )
        diagnostics_roundtrip = (
            "[OpenC] diagnostics:" in combined_logs
            or (
                "[DiagnosticCollection]" in combined_logs
                and "OPENC-SYNTAX-" in combined_logs
            )
        )
        language_server_ready = (
            "[OpenC] language server ready:" in combined_logs
            or (started_server and diagnostics_roundtrip)
        )
        normalized_logs = combined_logs.replace("/", "\\").lower()
        packaged_compiler_selected = (
            ("[openc] language server ready:" in normalized_logs or "starting " in normalized_logs)
            and "openc-language.openc-1.0.0\\bin\\openc.exe" in normalized_logs
            and "lsp --stdio" in normalized_logs
        )
        if language_server_ready and diagnostics_roundtrip and packaged_compiler_selected:
            break
        if launched.poll() is not None:
            break
        time.sleep(0.25)

    shutdown = run(["taskkill", "/PID", str(launched.pid), "/T", "/F"], timeout=30)
    try:
        launched.wait(timeout=10)
    except subprocess.TimeoutExpired:
        launched.kill()
        launched.wait(timeout=10)
    time.sleep(0.5)
    process_tree_terminated = launched.poll() is not None

    unexpected_server_exits = combined_logs.count("Server exited (")
    provider_failures = combined_logs.count("provider FAILED")
    bounded_restart_recovery = (
        unexpected_server_exits <= 3
        and language_server_ready
        and diagnostics_roundtrip
    )

    installed_dirs = sorted(extensions.glob("openc-language.openc-*"))
    installed_compiler = (
        installed_dirs[0] / "bin" / "openc.exe" if installed_dirs else Path()
    )
    compiler_hash = sha256(compiler)
    installed_compiler_hash = (
        sha256(installed_compiler) if installed_compiler.is_file() else ""
    )
    within_memory_limit = (
        peak_working_set <= VSCODE_WORKING_SET_LIMIT
        and openc_peak_working_set <= OPENC_WORKING_SET_LIMIT
    )
    passed = all(
        [
            version_run.returncode == 0,
            version_supported,
            before.returncode == 0,
            not preexisting,
            install.returncode == 0,
            after.returncode == 0,
            expected_extension in installed,
            extension_activated,
            language_server_ready,
            diagnostics_roundtrip,
            packaged_compiler_selected,
            provider_failures == 0,
            bounded_restart_recovery,
            process_tree_terminated,
            installed_compiler_hash == compiler_hash,
            within_memory_limit,
        ]
    )
    report = {
        "schema": "openc.sh25_clean_vscode_profile.v1",
        "platform": "windows-x86_64",
        "vscode_version": vscode_version,
        "version_supported": version_supported,
        "profile_kind": "new-empty-user-data-and-extension-directories",
        "preexisting_extensions": preexisting,
        "installed_extensions": installed,
        "expected_extension": expected_extension,
        "install_exit_code": install.returncode,
        "extension_activated": extension_activated,
        "language_server_ready": language_server_ready,
        "diagnostics_roundtrip": diagnostics_roundtrip,
        "packaged_compiler_selected": packaged_compiler_selected,
        "unexpected_server_exits": unexpected_server_exits,
        "bounded_restart_recovery": bounded_restart_recovery,
        "provider_failures": provider_failures,
        "compiler_sha256": compiler_hash,
        "installed_compiler_sha256": installed_compiler_hash,
        "vsix_sha256": sha256(vsix),
        "working_set_peak_bytes": peak_working_set,
        "working_set_limit_bytes": VSCODE_WORKING_SET_LIMIT,
        "openc_working_set_peak_bytes": openc_peak_working_set,
        "openc_working_set_limit_bytes": OPENC_WORKING_SET_LIMIT,
        "within_memory_limit": within_memory_limit,
        "ui_controller_status": args.ui_controller_status,
        "ui_controller_required_for_gate": False,
        "vscode_window_launched": True,
        "vscode_process_tree_terminated": process_tree_terminated,
        "python_role": "external_evidence_orchestrator_only",
        "status": "PASS" if passed else "FAIL",
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(
        json.dumps(report, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(
        f"OpenC SH-25 clean VS Code profile: {report['status']} "
        f"({vscode_version}, {peak_working_set} bytes peak)"
    )
    if not passed:
        print("install stdout:", install.stdout, file=sys.stderr)
        print("install stderr:", install.stderr, file=sys.stderr)
        print("installed:", installed, file=sys.stderr)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
