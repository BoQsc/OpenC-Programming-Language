
from __future__ import annotations
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "MANIFEST.sha256"
EXCLUDED_PARTS = {".git", ".dub", ".cache", "__pycache__", "build-output"}
EXCLUDED_SUFFIXES = {".dll", ".exe", ".exp", ".lib", ".obj", ".pdb", ".pyc"}

def is_generated(path: Path) -> bool:
    relative = path.relative_to(ROOT)
    parts = relative.parts
    return (
        any(part in EXCLUDED_PARTS for part in parts)
        or path.suffix.lower() in EXCLUDED_SUFFIXES
        or relative.as_posix() in {"build/fixture_main.d", "build/test-report.json"}
        or relative.as_posix() == "build/openc-build-record.json"
        or relative.as_posix().startswith("build/generated/")
        or (len(parts) >= 3 and parts[0] == "programs" and parts[2] == "build")
    )

def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

lines = []
for path in sorted(ROOT.rglob("*")):
    if path.is_file() and path != OUT and not is_generated(path):
        lines.append(f"{digest(path)}  {path.relative_to(ROOT).as_posix()}")
OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
