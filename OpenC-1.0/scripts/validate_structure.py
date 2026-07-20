
from __future__ import annotations
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
required = [
    "README.md", "VERSION", "STATUS.md", "AUTHORITY.md", "DEVELOPMENT_MODEL.md",
    "LICENSE", "LICENSES/CC0-1.0.txt", "LICENSE_POLICY.md", "GOVERNANCE.md",
    "CONTRIBUTING.md", "SECURITY.md", "TRADEMARKS.md",
    "release/RELEASE_AUTHORITY.md", "release/RELEASE_SCOPE_1.0.md",
    "release/ERRATA_POLICY.md", "release/SUPPORT_POLICY.md",
    "standard/core/OpenC_Core_Current.md",
    "standard/core/grammar/OpenC_Core_Grammar.ebnf",
    "standard/core/metadata/OpenC_Core_Rule_Index.json",
    "standard/core/metadata/OpenC_Core_Diagnostic_Catalog.json",
]
errors = []
for item in required:
    if not (ROOT / item).is_file():
        errors.append(f"missing: {item}")
for path in ROOT.rglob("*.json"):
    try:
        json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        errors.append(f"invalid JSON {path.relative_to(ROOT)}: {exc}")
rule_data = json.loads((ROOT / "standard/core/metadata/OpenC_Core_Rule_Index.json").read_text(encoding="utf-8"))
rules = rule_data.get("rules", rule_data if isinstance(rule_data, list) else [])
if len(rules) != 466:
    errors.append(f"expected 466 active Core rules, found {len(rules)}")
grammar = (ROOT / "standard/core/grammar/OpenC_Core_Grammar.ebnf").read_text(encoding="utf-8")
productions = re.findall(r"(?m)^\s*[A-Za-z_][A-Za-z0-9_]*\s*=", grammar)
if len(productions) != 174:
    errors.append(f"expected 174 grammar entries, found {len(productions)}")

for package in ["compiler", "runtime", "standard_library", "tools", "tests"]:
    manifest = json.loads((ROOT / package / "dub.json").read_text(encoding="utf-8"))
    if manifest.get("license") != "0BSD":
        errors.append(f"{package}/dub.json must declare 0BSD")

owner_record = json.loads((ROOT / "standard/core/control/OWNER_RATIFICATION_RECORD.json").read_text(encoding="utf-8"))
hd_012 = next((item for item in owner_record["decisions"] if item["id"] == "HD-012"), None)
if not hd_012 or hd_012.get("status") != "RATIFIED_FOR_1_0":
    errors.append("HD-012 must be ratified for 1.0")

development = json.loads((ROOT / "DEVELOPMENT_STATE.json").read_text(encoding="utf-8"))
if not development.get("release_ready") or development.get("release_blockers"):
    errors.append("development state must record a blocker-free release candidate")

fixture_manifest = json.loads((ROOT / "conformance/fixtures/MANIFEST.json").read_text(encoding="utf-8"))
active_ids = {item["id"] for item in rules}
fixture_ids = {item["id"] for item in fixture_manifest["fixtures"]}
fixture_rules = {rule for item in fixture_manifest["fixtures"] for rule in item["rules"]}
if len(fixture_ids) != fixture_manifest.get("fixture_count"):
    errors.append("fixture manifest count does not match unique fixture IDs")
if fixture_rules - active_ids:
    errors.append("fixture manifest names non-normative active rules")
if fixture_manifest.get("rules_with_imported_fixtures") != len(fixture_rules):
    errors.append("fixture manifest covered-rule count is stale")
if set(fixture_manifest.get("rules_without_imported_fixtures", [])) != active_ids - fixture_rules:
    errors.append("fixture manifest uncovered-rule list is stale")
for entry in fixture_manifest["fixtures"]:
    fixture_path = ROOT / entry["path"] / "fixture.json"
    if not fixture_path.is_file():
        errors.append(f"missing fixture record: {entry['path']}/fixture.json")
        continue
    fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
    if fixture.get("id") != entry["id"]:
        errors.append(f"fixture ID mismatch: {entry['id']}")
    if set(fixture.get("active_rules", [])) != set(entry["rules"]):
        errors.append(f"fixture rule mismatch: {entry['id']}")
    if fixture.get("evidence_state") != "EXECUTED_PASS_WINDOWS_X86_64_RC1":
        errors.append(f"fixture evidence state is stale: {entry['id']}")
    for source in fixture.get("source_files", []):
        if not (ROOT / source).is_file():
            errors.append(f"missing fixture source: {source}")

repository_text = "\n".join(
    path.read_text(encoding="utf-8", errors="replace")
    for path in [ROOT / "compiler/dub.json", ROOT / "runtime/dub.json",
                 ROOT / "standard_library/dub.json", ROOT / "tools/dub.json",
                 ROOT / "tests/dub.json", ROOT / "LICENSE_STATUS.md"]
)
if "proprietary-pending-governance" in repository_text:
    errors.append("pending proprietary-license placeholder remains")
if errors:
    raise SystemExit("\n".join(errors))
print("OpenC canonical-tree structure is internally consistent.")
