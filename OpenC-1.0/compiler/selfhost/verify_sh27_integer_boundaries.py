#!/usr/bin/env python3
"""Exercise integer-immediate encoding boundaries under the SH-27 RAM cap."""
from __future__ import annotations

import argparse
import json
import os
import shutil
from pathlib import Path

from benchmark_sh27_native_parallel import build
from benchmark_sh27_production import MIB, ROOT, require_disk_headroom, run_measured, sha256


CASES = (
    ("integer_literals", ROOT / "tests/sh27_integer_literals/openc.project.json", 0),
    ("signed_overflow", ROOT / "tests/sh27_integer_immediate_signed_overflow/openc.project.json", 70),
    ("unsigned_underflow", ROOT / "tests/sh27_integer_immediate_unsigned_underflow/openc.project.json", 70),
    ("narrow_overflow", ROOT / "tests/sh27_integer_immediate_narrow_overflow/openc.project.json", 70),
)


def execute(binary: Path) -> dict[str, object]:
    return run_measured(
        [str(binary)], cwd=ROOT, environment=dict(os.environ),
        sample_interval=0.01, max_private_bytes=512 * MIB,
        max_working_set_bytes=512 * MIB,
        max_captured_output_bytes=64 * 1024, timeout_seconds=15,
    )


def compact_oracle_compiler(compiler: Path, root: Path) -> tuple[Path, dict[str, object]]:
    """Build the same source with compact emission disabled as a detecting oracle."""
    canonical = ROOT / "compiler/selfhost"
    source_root = root / "oracle-source"
    source_root.mkdir(exist_ok=False)
    manifest = json.loads((canonical / "openc.project.json").read_text(encoding="utf-8"))
    original_hashes = {}
    for name in manifest["modules"]["openc.selfhost.main"]:
        original = canonical / name
        destination = source_root / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(original, destination)
        original_hashes[name] = sha256(original)
    changed = source_root / "source/backend_c_project.p"
    text = changed.read_text(encoding="utf-8")
    marker = "context.native_compact_updates = timings.emission_mode == 2;"
    if text.count(marker) != 1:
        raise RuntimeError("compact-update oracle policy marker changed")
    changed.write_text(text.replace(marker, "context.native_compact_updates = false;"), encoding="utf-8", newline="\n")
    for name in ("standard_library_directory", "runtime_directory"):
        manifest[name] = str((canonical / manifest[name]).resolve())
    manifest["output_directory"] = "build"
    project = source_root / "openc.project.json"
    project.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    binary = root / "oracle-compiler.exe"
    measurement = run_measured([str(compiler), "build", f"--project={project}",
        f"--output={binary}", "--no-cache"], cwd=ROOT, sample_interval=.01,
        max_private_bytes=256*MIB, max_working_set_bytes=64*MIB,
        max_captured_output_bytes=2*MIB, timeout_seconds=180)
    passed = measurement["exit_code"] == 0 and not measurement["memory_limit_exceeded"] and not measurement["timed_out"] and not measurement["stdout_truncated"] and not measurement["stderr_truncated"] and binary.is_file()
    record = {"status": "PASS" if passed else "FAIL", "measurement": measurement,
        "compiler_sha256": sha256(compiler), "source_sha256": original_hashes,
        "oracle_source_sha256": sha256(changed),
        "oracle_compiler_sha256": sha256(binary) if binary.is_file() else None}
    (root / "oracle-build.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    if not passed:
        raise RuntimeError(f"compact-update fallback compiler failed: {measurement}")
    return binary, record


def verify_compact_updates(compiler: Path, baseline: Path | None, runs: Path) -> dict[str, object]:
    repo = ROOT.parent
    b = ROOT / "compiler/selfhost"
    root = runs / "compact-updates"
    root.mkdir(exist_ok=False)
    candidate = compiler
    oracle_record = None
    if baseline is None:
        baseline, oracle_record = compact_oracle_compiler(compiler, root)
    else:
        baseline = baseline.resolve(strict=True)
    types={'i8':(-128,127),'u8':(0,255),'i16':(-32768,32767),'u16':(0,65535),'i32':(-2147483648,2147483647),'u32':(0,4294967295),'i64':(-9223372036854775808,9223372036854775807),'u64':(0,18446744073709551615),'isize':(-9223372036854775808,9223372036854775807),'usize':(0,18446744073709551615)}
    cases={}
    parts=[];checks=[]
    for n in types:
     parts.append(f'''{n} update_{n}({n} value) {{
        value = value + 0;
        value = value + 1;
        value = value - 1;
        value = value + 127;
        value = value - 127;
        value = value * 1 + 1;
        value = value * 1 - 1;
        return value;
    }}''')
     checks.append(f'    if update_{n}(0) != 0 {{ return 1; }}')
    cases['all_integer_widths']=('\n'.join(parts)+'\ni32 main() {\n'+'\n'.join(checks)+'\n    return 0;\n}\n',0,True)
    cases['assignment_results']=('''i64 nested(i64 value) { return value = value + 1; }
    i64 chained(i64 value) { value = value = value + 1; return value; }
    i32 main() {
        if nested(3) != 4 { return 1; }
        if chained(4) != 5 { return 2; }
        return 0;
    }
    ''',0,True)
    cases['reference_fallback']=('''void bump(ref i64 value) { value = 1; }
    i32 main() { i64 value = 0; bump(value); if value != 1 { return 1; } return 0; }
    ''',0,False)
    cases['wide_immediate_fallback']=('''i64 bump(i64 value) { value = value + 128; value = value - 128; return value; }
    i32 main() { if bump(0) != 0 { return 1; } return 0; }
    ''',0,False)
    cases['different_local_fallback']=('''i64 bump(i64 input) { i64 value = 0; value = input + 1; return value; }
    i32 main() { if bump(2) != 3 { return 1; } return 0; }
    ''',0,False)
    cases['escaped_local']=('''void bump(ref i64 value) { value = 1; }
    i32 main() { i64 value = 0; bump(value); value = value + 1; if value != 2 { return 1; } return 0; }
    ''',0,True)
    cases['loop_updates']=('''i32 main() { i64 value = 0; usize index = 0;
        while index < 20 { value = value + 1; index = index + 1; }
        if value != 20 { return 1; } return 0;
    }
    ''',0,True)
    cases['compatibility_fallback']=('''import system.memory;
    unsafe i32 main() { ptr byte allocation = memory.alloc(1); scope memory.free(allocation);
        usize value = 0; value = value + 2; return 0;
    }
    ''',70,False)
    for n,(low,high) in types.items():
     for suffix,initial,op in (('overflow',high,'+'),('underflow',low,'-')):
      cases[n+'_'+suffix]=(f'i32 main() {{ {n} value = {initial}; value = value {op} 1; return 0; }}\n',70,True)
    report={'schema':'openc.sh27.compact_update_boundaries.v1','status':'INCOMPLETE','baseline_sha256':sha256(baseline),'candidate_sha256':sha256(candidate),'cases':{}}
    compiler_manifest = json.loads((b / 'openc.project.json').read_text())
    for name, (source, expected, compact) in cases.items():
        folder = root / name
        folder.mkdir(exist_ok=False)
        (folder / 'main.p').write_text(source)
        manifest = json.loads((ROOT / 'tests/sh27_integer_literals/openc.project.json').read_text())
        manifest['modules'] = {'boundary': ['main.p']}
        for key in ('standard_library_directory', 'runtime_directory'):
            manifest[key] = str((b / compiler_manifest[key]).resolve())
        project = folder / 'openc.project.json'
        project.write_text(json.dumps(manifest, indent=2) + '\n')
        result = {'expected_exit': expected, 'compact_expected': compact, 'samples': {}}
        for side, compiler_path in (('baseline', baseline), ('candidate', candidate)):
            for mode, parallel in (('serial', False), ('adaptive', True)):
                directory = folder / side / mode
                compilation = build(compiler_path, project, directory, parallel, True, 'auto')
                execution = None
                if compilation['passed']:
                    execution = run_measured([str(directory / 'program.exe')],
                        cwd=folder, sample_interval=.01, max_private_bytes=64*MIB,
                        max_working_set_bytes=32*MIB, max_captured_output_bytes=4096,
                        timeout_seconds=10)
                result['samples'][side + '_' + mode] = {'build': compilation, 'execution': execution}
        hashes = {
            side: {result['samples'][side + '_' + mode]['build']['output_sha256']
                for mode in ('serial', 'adaptive')}
            for side in ('baseline', 'candidate')
        }
        expected_error = 'OpenC checked failure\n' if expected else ''
        if name == 'compatibility_fallback':
            expected_error = 'OpenC target fault\n'
        result['checks'] = {
            'all_builds_and_runtime_oracles_pass': all(
                sample['build']['passed'] and sample['execution'] is not None
                and sample['execution']['exit_code'] == expected
                and sample['execution']['stdout'] == ''
                and sample['execution']['stderr'] == expected_error
                and not sample['execution']['timed_out']
                and not sample['execution']['memory_limit_exceeded']
                for sample in result['samples'].values()),
            'serial_adaptive_exact': all(len(v) == 1 and None not in v for v in hashes.values()),
            'fallback_bytes_exact': compact or hashes['baseline'] == hashes['candidate'],
        }
        before = result['samples']['baseline_serial']['build'].get('compiler_timings')
        after = result['samples']['candidate_serial']['build'].get('compiler_timings')
        if before and after:
            result['instructions'] = {
                'baseline': before['work']['instructions'],
                'candidate': after['work']['instructions'],
            }
            result['checks']['compact_removes_generic_ir'] = (
                not compact or after['work']['instructions'] < before['work']['instructions'])
        result['passed'] = all(result['checks'].values())
        report['cases'][name] = result
        (root / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
        print(name, result['passed'], result.get('instructions'), flush=True)
        if not result['passed']:
            print(name, [(side, sample['build']['exit_code'], sample['build']['stdout'],
                sample['build']['stderr'], sample['execution'] and
                (sample['execution']['exit_code'], sample['execution']['stderr']))
                for side, sample in result['samples'].items()], flush=True)
    report['status'] = 'PASS' if all(case['passed'] for case in report['cases'].values()) else 'FAIL'
    (root / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('compact boundaries', report['status'], flush=True)
    report["oracle_build"] = oracle_record
    return report


def main() -> int:
    if os.name != "nt":
        raise SystemExit("integer-immediate boundary proof requires Windows")
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--baseline-compiler", type=Path, help="optional pre-cut differential compiler; otherwise build the source with compact emission disabled")
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    output = args.output.resolve()
    require_disk_headroom(output.parent)
    output.parent.mkdir(parents=True, exist_ok=True)
    runs = output.parent / (output.stem + "-runs")
    runs.mkdir(parents=True, exist_ok=False)
    cases: dict[str, dict[str, object]] = {}
    for name, project, expected_exit in CASES:
        expected_stderr = "" if expected_exit == 0 else "OpenC checked failure\n"
        samples: dict[str, dict[str, object]] = {}
        hashes: set[str] = set()
        for mode, parallel in (("serial", False), ("adaptive", True)):
            directory = runs / name / mode
            compilation = build(compiler, project, directory, parallel, True, "auto")
            execution = execute(directory / "program.exe") if compilation["passed"] else None
            samples[mode] = {"build": compilation, "execution": execution}
            if compilation["output_sha256"] is not None:
                hashes.add(str(compilation["output_sha256"]))
        passed_case = bool(
            len(hashes) == 1 and all(
                sample["build"]["passed"]
                and sample["execution"] is not None
                and sample["execution"]["exit_code"] == expected_exit
                and not sample["execution"]["timed_out"]
                and not sample["execution"]["memory_limit_exceeded"]
                and sample["execution"]["stdout"] == ""
                and sample["execution"]["stderr"] == expected_stderr
                for sample in samples.values()
            )
        )
        cases[name] = {
            "project": str(project), "expected_exit_code": expected_exit,
            "expected_stderr": expected_stderr,
            "serial_adaptive_binary_exact": len(hashes) == 1,
            "passed": passed_case, "samples": samples,
        }
    compact = verify_compact_updates(compiler, args.baseline_compiler, runs)
    passed = all(case["passed"] for case in cases.values()) and compact["status"] == "PASS"
    report = {
        "schema": "openc.sh27.integer_boundaries.v1",
        "status": "PASS" if passed else "FAIL",
        "cases": cases,
        "compact_updates": compact,
        "compiler_sha256": sha256(compiler),
    }
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"SH-27 integer boundaries: {report['status']}; report={output}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
