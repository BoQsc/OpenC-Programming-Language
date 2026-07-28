
from __future__ import annotations
import hashlib
import json
import re
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
VERSION = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
RC_MATCH = re.fullmatch(r".+-rc\.(\d+)", VERSION)
EXPECTED_CANDIDATE = f"OpenC {VERSION}"
EXPECTED_EXECUTION_STATE = (
    f"EXECUTED_PASS_WINDOWS_X86_64_RC{RC_MATCH.group(1)}"
    if RC_MATCH
    else None
)
required = [
    "README.md", "VERSION", "STATUS.md", "AUTHORITY.md", "DEVELOPMENT_MODEL.md",
    "LICENSE", "LICENSES/CC0-1.0.txt", "LICENSE_POLICY.md", "GOVERNANCE.md",
    "CONTRIBUTING.md", "SECURITY.md", "TRADEMARKS.md",
    "release/RELEASE_AUTHORITY.md", "release/RELEASE_SCOPE_1.0.md",
    "release/ERRATA_POLICY.md", "release/SUPPORT_POLICY.md",
    "release/SH7_NATIVE_CONFORMANCE_EVIDENCE.md",
    "release/SH8_NATIVE_WORKFLOW_EVIDENCE.md",
    "release/windows_native_release.py",
    "compiler/selfhost/SELF_HOSTING.md", "compiler/selfhost/SELF_HOSTING_STATE.json",
    "compiler/selfhost/source/main.p", "compiler/selfhost/bootstrap.py",
    "compiler/selfhost/lexer_parity.py", "compiler/selfhost/bootstrap_d_parity.py",
    "compiler/selfhost/bootstrap_closure.py",
    "scripts/complete_conformance_coverage.py",
    "scripts/generate_native_conformance_plan.py",
    "scripts/native_toolchain.py",
    "scripts/windows_native_workflow.py",
    "compiler/selfhost/WINDOWS_NATIVE_BUDGETS.json",
    "compiler/selfhost/benchmark_windows_validate.py",
    "compiler/selfhost/source/native_conformance.p",
    "conformance/fixtures/NATIVE_PLAN.tsv",
    "standard/core/OpenC_Core_Current.md",
    "standard/core/grammar/OpenC_Core_Grammar.ebnf",
    "standard/core/metadata/OpenC_Core_Rule_Index.json",
    "standard/core/metadata/OpenC_Core_Diagnostic_Catalog.json",
]
errors = []
for item in required:
    if not (ROOT / item).is_file():
        errors.append(f"missing: {item}")
native_plan_check = subprocess.run(
    [
        sys.executable,
        str(ROOT / "scripts/generate_native_conformance_plan.py"),
        "--check",
    ],
    cwd=ROOT,
    text=True,
    capture_output=True,
)
if native_plan_check.returncode != 0:
    errors.append(
        "native conformance plan is stale: "
        + (native_plan_check.stderr or native_plan_check.stdout).strip()
    )
standalone_verifier = (
    ROOT / "release/verify_standalone_windows.py"
).read_text(encoding="utf-8")
if 'str(stage3),\n            "validate"' not in standalone_verifier:
    errors.append("standalone conformance gate must invoke native Stage 3")
if 'str(seed),\n            "validate"' in standalone_verifier:
    errors.append("standalone conformance gate must not invoke the retained D seed")
for path in ROOT.rglob("*.json"):
    if "build-output" in path.relative_to(ROOT).parts:
        continue
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
hd_008 = next((item for item in owner_record["decisions"] if item["id"] == "HD-008"), None)
if not hd_008 or hd_008.get("status") != "RATIFIED_FOR_1_0" or ".p" not in hd_008.get("selection", ""):
    errors.append("HD-008 must ratify .p as the official tooling extension")
hd_012 = next((item for item in owner_record["decisions"] if item["id"] == "HD-012"), None)
if not hd_012 or hd_012.get("status") != "RATIFIED_FOR_1_0":
    errors.append("HD-012 must be ratified for 1.0")

development = json.loads((ROOT / "DEVELOPMENT_STATE.json").read_text(encoding="utf-8"))
if not development.get("release_ready") or development.get("release_blockers"):
    errors.append("development state must record a blocker-free release candidate")

authority_index = json.loads((ROOT / "AUTHORITY_INDEX.json").read_text(encoding="utf-8"))
if authority_index.get("version") != VERSION:
    errors.append("authority index version is stale")
if EXPECTED_EXECUTION_STATE is None:
    errors.append("VERSION must identify a numbered release candidate")
for section in ("authoritative", "project_authority"):
    for record in authority_index.get(section, []):
        path = ROOT / record["path"]
        if not path.is_file():
            errors.append(f"missing authority input: {record['path']}")
            continue
        if record.get("bytes") != path.stat().st_size:
            errors.append(f"authority byte count is stale: {record['path']}")
        if record.get("sha256") != hashlib.sha256(path.read_bytes()).hexdigest():
            errors.append(f"authority hash is stale: {record['path']}")

fixture_manifest = json.loads((ROOT / "conformance/fixtures/MANIFEST.json").read_text(encoding="utf-8"))
if fixture_manifest.get("candidate") != EXPECTED_CANDIDATE:
    errors.append("fixture manifest candidate is stale")
active_ids = {item["id"] for item in rules}
fixture_ids = {item["id"] for item in fixture_manifest["fixtures"]}
fixture_rules = {rule for item in fixture_manifest["fixtures"] for rule in item["rules"]}
fixtures_by_id = {item["id"]: item for item in fixture_manifest["fixtures"]}
rule_fixture_index = fixture_manifest.get("rule_fixture_index", {})
if len(fixture_ids) != fixture_manifest.get("fixture_count"):
    errors.append("fixture manifest count does not match unique fixture IDs")
if fixture_rules - active_ids:
    errors.append("fixture manifest names non-normative active rules")
if fixture_manifest.get("rules_with_imported_fixtures") != len(fixture_rules):
    errors.append("fixture manifest covered-rule count is stale")
if set(fixture_manifest.get("rules_without_imported_fixtures", [])) != active_ids - fixture_rules:
    errors.append("fixture manifest uncovered-rule list is stale")
if fixture_rules != active_ids:
    errors.append("every active Core rule must name a dedicated fixture")
if set(rule_fixture_index) != active_ids:
    errors.append("fixture manifest rule index must cover every active Core rule")
for rule in active_ids:
    expected_ids = sorted(
        entry["id"] for entry in fixture_manifest["fixtures"]
        if rule in entry["rules"]
    )
    if rule_fixture_index.get(rule) != expected_ids:
        errors.append(f"fixture manifest rule index is stale: {rule}")
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
    if fixture.get("evidence_state") != EXPECTED_EXECUTION_STATE:
        errors.append(f"fixture evidence state is stale: {entry['id']}")
    for source in fixture.get("source_files", []):
        if not (ROOT / source).is_file():
            errors.append(f"missing fixture source: {source}")
        if Path(source).suffix.lower() != ".json" and Path(source).suffix.lower() != ".p":
            errors.append(f"canonical OpenC fixture source must use .p: {source}")

rule_coverage = json.loads((
    ROOT / "standard/core/conformance/OpenC_Core_Rule_Coverage.json"
).read_text(encoding="utf-8"))
if rule_coverage.get("candidate") != EXPECTED_CANDIDATE:
    errors.append("Core rule coverage candidate is stale")
if rule_coverage.get("rules_with_dedicated_fixtures") != len(active_ids) or \
        rule_coverage.get("rules_without_dedicated_fixtures") != 0:
    errors.append("Core rule coverage totals are incomplete")
for entry in rule_coverage.get("rules", []):
    if entry.get("fixtures") != rule_fixture_index.get(entry["rule"]):
        errors.append(f"Core rule coverage fixture map is stale: {entry['rule']}")

grammar_coverage = json.loads((
    ROOT / "standard/core/conformance/OpenC_Core_Grammar_Coverage.json"
).read_text(encoding="utf-8"))
if grammar_coverage.get("candidate") != EXPECTED_CANDIDATE:
    errors.append("Core grammar coverage candidate is stale")
grammar_entries = grammar_coverage.get("productions", [])
if len(grammar_entries) != 174:
    errors.append("grammar coverage must contain 174 production entries")
for entry in grammar_entries:
    positive = entry.get("positive_fixture")
    rejection = entry.get("rejection_fixture")
    if positive not in fixtures_by_id or \
            fixtures_by_id.get(positive, {}).get("kind") not in {
                "valid", "runtime", "command", "records"
            }:
        errors.append(
            f"grammar positive fixture is missing or non-accepting: "
            f"{entry.get('production')}"
        )
    if rejection not in fixtures_by_id or \
            fixtures_by_id.get(rejection, {}).get("kind") not in {
                "invalid", "diagnostic"
            }:
        errors.append(
            f"grammar rejection fixture is missing or non-rejecting: "
            f"{entry.get('production')}"
        )

fixture_queue = json.loads((
    ROOT / "conformance/matrices/FIXTURE_AUTHORING_QUEUE.json"
).read_text(encoding="utf-8"))
if fixture_queue.get("candidate") != EXPECTED_CANDIDATE:
    errors.append("fixture authoring queue candidate is stale")
if fixture_queue.get("required_rule_count") != 0 or \
        fixture_queue.get("authored_rule_count") != len(active_ids):
    errors.append("fixture authoring queue is not complete")

for project_path in [
    ROOT / "programs/A_COMPUTATION/openc.project.json",
    ROOT / "programs/B_FLOW_OWNERSHIP/openc.project.json",
    ROOT / "programs/C_UNSAFE_BOUNDARY/openc.project.json",
    ROOT / "programs/D_HOSTED_CLI/openc.project.json",
    ROOT / "standard_library/openc.project.json",
    ROOT / "compiler/selfhost/openc.project.json",
    ROOT / "demos/hello/openc.project.json",
    ROOT / "demos/calculator/openc.project.json",
    ROOT / "demos/types/openc.project.json",
    ROOT / "demos/strings/openc.project.json",
    ROOT / "demos/ownership/openc.project.json",
    ROOT / "demos/unsafe/openc.project.json",
]:
    project = json.loads(project_path.read_text(encoding="utf-8"))
    for sources in project.get("modules", {}).values():
        for source in sources:
            if Path(source).suffix.lower() != ".p":
                errors.append(f"canonical project source must use .p: {project_path.relative_to(ROOT)}:{source}")

self_hosting = json.loads((ROOT / "compiler/selfhost/SELF_HOSTING_STATE.json").read_text(encoding="utf-8"))
self_host_gates = {gate["id"]: gate["status"] for gate in self_hosting.get("gates", [])}
if self_hosting.get("official_source_extension") != ".p":
    errors.append("self-hosting state must record .p as the official source extension")
if any(self_host_gates.get(gate) != "PASS" for gate in
       ("SH-0", "SH-1", "SH-2A", "SH-2B", "SH-2C", "SH-2D", "SH-2")):
    errors.append("self-hosting source-convention and SH-1 through SH-2 frontend gates must pass")
if self_hosting.get("claims", {}).get("full_frontend_parity") != (self_host_gates.get("SH-2") == "PASS"):
    errors.append("full_frontend_parity claim must match the SH-2 gate")
if self_host_gates.get("SH-3A") != "PASS":
    errors.append("self-hosting declaration/symbol/type-table SH-3A gate must pass")
if not self_hosting.get("claims", {}).get("stage1_exact_declaration_symbol_type_table_parity"):
    errors.append("self-hosting state must record exact SH-3A parity")
if self_host_gates.get("SH-3B") != "PASS":
    errors.append("self-hosting name/constant/overload SH-3B gate must pass")
if not self_hosting.get("claims", {}).get("stage1_exact_name_constant_overload_resolution_parity"):
    errors.append("self-hosting state must record exact SH-3B parity")
if self_host_gates.get("SH-3C") != "PASS":
    errors.append("self-hosting flow/safety SH-3C gate must pass")
if not self_hosting.get("claims", {}).get("stage1_exact_flow_safety_parity"):
    errors.append("self-hosting state must record exact SH-3C parity")
if self_host_gates.get("SH-3D") != "PASS":
    errors.append("self-hosting semantic-outcome/canonical-IR SH-3D gate must pass")
if not self_hosting.get("claims", {}).get("stage1_exact_semantic_outcome_parity") or \
        not self_hosting.get("claims", {}).get("stage1_exact_canonical_ir_parity"):
    errors.append("self-hosting state must record exact SH-3D parity")
if self_host_gates.get("SH-3") != "PASS" or \
        not self_hosting.get("claims", {}).get("semantic_ir_parity"):
    errors.append("self-hosting semantic and IR SH-3 gate must pass")
if any(self_host_gates.get(gate) != "PASS" for gate in
       ("SH-4A", "SH-4B", "SH-4C", "SH-4")):
    errors.append("self-hosting bootstrap SH-4A through SH-4C and full SH-4 gates must pass")
if not self_hosting.get("claims", {}).get("stage1_exact_bootstrap_d_source_parity") or \
        not self_hosting.get("claims", {}).get("stage1_builds_stage2") or \
        not self_hosting.get("claims", {}).get("stage2_builds_stage3") or \
        not self_hosting.get("claims", {}).get("bootstrap_closure"):
    errors.append("self-hosting state must record complete SH-4 bootstrap evidence")
if self_hosting.get("claims", {}).get("self_hosted") != (self_host_gates.get("SH-4") == "PASS"):
    errors.append("self_hosted claim must match the SH-4 gate")
if self_hosting.get("claims", {}).get("dmd_independent") != \
        (self_host_gates.get("SH-5") == "PASS"):
    errors.append("dmd_independent claim must match the SH-5 gate")
if self_hosting.get("claims", {}).get("standalone") != \
        (self_host_gates.get("SH-6") == "PASS"):
    errors.append("standalone claim must match the SH-6 gate")
if self_host_gates.get("SH-6") == "PASS" and (
        not self_hosting.get("claims", {}).get("self_hosted")
        or not self_hosting.get("claims", {}).get("dmd_independent")
        or not self_hosting.get("claims", {}).get("standalone")):
    errors.append("SH-6 PASS requires self-hosted, DMD-independent, standalone claims")
if self_host_gates.get("SH-5") == "PASS" and (
        not self_hosting.get("claims", {}).get("windows_c_backend")
        or not self_hosting.get("claims", {}).get("vendored_windows_backend")
        or not self_hosting.get("claims", {}).get("public_openc_build")):
    errors.append("SH-5 PASS requires C backend, vendored backend, and public build claims")
if self_host_gates.get("SH-7") != "PASS":
    errors.append("native conformance and tooling-independence SH-7 gate must pass")
if self_host_gates.get("SH-7") == "PASS" and (
        not self_hosting.get("claims", {}).get("native_openc_validate")
        or not self_hosting.get("claims", {}).get("native_conformance_278")
        or self_hosting.get("claims", {}).get("required_conformance_uses_d_seed")):
    errors.append(
        "SH-7 PASS requires native openc validate, 278 fixtures, and no "
        "required D-seed conformance dependency"
    )
if self_host_gates.get("SH-8") != "PASS":
    errors.append("native developer/release workflow SH-8 gate must pass")
if self_host_gates.get("SH-8") == "PASS" and (
        not self_hosting.get("claims", {}).get(
            "native_default_windows_compiler_under_test"
        )
        or not self_hosting.get("claims", {}).get(
            "native_validation_regression_budget"
        )
        or not self_hosting.get("claims", {}).get(
            "native_self_rebuild_regression_budget"
        )
        or not self_hosting.get("claims", {}).get(
            "native_daily_exact_input_cache"
        )
        or self_hosting.get("claims", {}).get(
            "required_workflows_use_d_seed"
        )):
    errors.append(
        "SH-8 PASS requires native-default testing, validation/rebuild "
        "budgets, exact-input caching, and no required D-seed execution"
    )

budgets = json.loads((
    ROOT / "compiler/selfhost/WINDOWS_NATIVE_BUDGETS.json"
).read_text(encoding="utf-8"))
if budgets.get("schema") != "openc.windows_native_performance_budgets.v1":
    errors.append("Windows native performance budget schema is invalid")
for section in ("validation", "self_rebuild"):
    baseline = budgets.get("baselines", {}).get(section, {})
    budget = budgets.get("budgets", {}).get(section, {})
    if baseline.get("elapsed_seconds", float("inf")) > \
            budget.get("max_elapsed_seconds", 0):
        errors.append(f"{section} elapsed baseline exceeds SH-8 budget")
    if baseline.get("peak_private_bytes", 2**63) > \
            budget.get("max_peak_private_bytes", 0):
        errors.append(f"{section} private-memory baseline exceeds SH-8 budget")
if budgets.get("budgets", {}).get("daily_cache_hit", {}).get(
        "max_fixtures_executed") != 0:
    errors.append("SH-8 unchanged daily cache budget must execute zero fixtures")

native_workflow = (
    ROOT / "scripts/windows_native_workflow.py"
).read_text(encoding="utf-8")
native_release = (
    ROOT / "release/windows_native_release.py"
).read_text(encoding="utf-8")
if '"audit-seed"' not in native_workflow or \
        '"retained_d_seed_executed": False' not in native_workflow:
    errors.append("D-seed audit must be explicit and outside native workflows")
if "--audit-seed" in native_release:
    errors.append("required SH-8 native release workflow must not audit the D seed")

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
