"""Conservative direct-native coverage census, not a conformance PASS claim."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--compiler', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    compiler = args.compiler.resolve()
    records = []
    manifest = json.loads((ROOT / 'conformance/fixtures/MANIFEST.json').read_text())
    with tempfile.TemporaryDirectory(prefix='openc-native-census-', ignore_cleanup_errors=True) as temp:
        work = Path(temp)
        for fixture in manifest['fixtures']:
            if fixture['kind'] != 'valid':
                continue
            record = {'id': fixture['id'], 'status': 'NOT_EXERCISED'}
            sources = [ROOT / p for p in fixture['source_files'] if p.endswith('.p')]
            if len(sources) != 1 or not re.search(r'\bi32\s+main\s*\(', sources[0].read_text(encoding='utf-8')):
                record['reason'] = 'module-only or multi-source fixture needs dedicated projection'
                records.append(record)
                continue
            project = work / 'openc.project.json'
            # OpenC project paths are rooted at the manifest directory. Use
            # forward-slash relative paths because path.join intentionally
            # does not reinterpret a drive-qualified host path.
            source_path = os.path.relpath(sources[0], work).replace('\\', '/')
            standard_library = os.path.relpath(
                ROOT / 'standard_library', work).replace('\\', '/')
            runtime = os.path.relpath(ROOT / 'runtime', work).replace('\\', '/')
            project.write_text(json.dumps({'name': 'native-census', 'edition': 'OpenC 1.0',
                'version': '0.1.0', 'profile': 'standard', 'target': 'windows-x86_64',
                'modules': {'probe': [source_path]},
                'standard_library_directory': standard_library,
                'runtime_directory': runtime}), encoding='utf-8')
            binary = work / (fixture['id'].replace('/', '-') + '.exe')
            try:
                result = subprocess.run([str(compiler), '--native-build', str(project), str(binary)],
                    cwd=ROOT, env={**os.environ, 'PATH': str(Path(os.environ['SystemRoot']) / 'System32')},
                    capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=30)
                diagnostic = result.stderr + result.stdout
                status = 'NATIVE_COMPILED' if result.returncode == 0 and binary.exists() else 'NOT_LOWERED'
                if status == 'NOT_LOWERED' and 'error[OPENC-NATIVE-LINK]' in diagnostic:
                    status = 'NOT_EXERCISED'
                    record['reason'] = 'declaration-only fixture has no linked implementation in its isolated projection'
                record.update(status=status, compile_exit=result.returncode, diagnostic=diagnostic)
            except subprocess.TimeoutExpired:
                record.update(status='TIMEOUT', reason='30-second per-fixture compile limit')
            records.append(record)
    counts = {status: sum(r['status'] == status for r in records)
              for status in sorted({r['status'] for r in records})}
    report = {'schema': 'openc.sh19_native_corpus_audit.v1', 'sh19_complete': False,
              'scope': 'compile-only single-source valid entrypoint fixtures; not runtime or diagnostic conformance',
              'counts': counts, 'fixtures': records}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(counts))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
