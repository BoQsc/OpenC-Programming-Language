
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
    "release/SH9_NATIVE_CLI_EVIDENCE.md",
    "release/SH10_NATIVE_PROJECT_WORKFLOW_EVIDENCE.md",
    "release/SH11_NATIVE_LANGUAGE_SERVICE_EVIDENCE.md",
    "release/SH12_NATIVE_SEMANTIC_LANGUAGE_EVIDENCE.md",
    "release/windows_native_release.py",
    "compiler/selfhost/SELF_HOSTING.md", "compiler/selfhost/SELF_HOSTING_STATE.json",
    "compiler/selfhost/source/main.p", "compiler/selfhost/bootstrap.py",
    "compiler/selfhost/lexer_parity.py", "compiler/selfhost/bootstrap_d_parity.py",
    "compiler/selfhost/bootstrap_closure.py",
    "scripts/complete_conformance_coverage.py",
    "scripts/generate_native_conformance_plan.py",
    "scripts/native_toolchain.py",
    "scripts/verify_sh9_cli.py",
    "scripts/verify_sh10_project_workflow.py",
    "scripts/verify_sh11_lsp.py",
    "scripts/verify_sh12_semantic_lsp.py",
    "scripts/windows_native_workflow.py",
    "compiler/selfhost/WINDOWS_NATIVE_BUDGETS.json",
    "compiler/selfhost/benchmark_windows_validate.py",
    "compiler/selfhost/SH19_NATIVE_BACKEND_PLAN.md",
    "compiler/selfhost/SH20_NATIVE_PUBLIC_THROUGHPUT_PLAN.md",
    "compiler/selfhost/SH21_OPENC_NATIVE_WORKFLOWS_PLAN.md",
    "compiler/selfhost/SH21_PYTHON_WORKFLOW_INVENTORY.md",
    "compiler/selfhost/SH21_NATIVE_WORKFLOW_TRANCHE1_EVIDENCE.md",
    "compiler/selfhost/SH21_NATIVE_PROCESS_GUARD_TRANCHE2_EVIDENCE.md",
    "compiler/selfhost/SH21_NATIVE_REPOSITORY_AUDIT_TRANCHE3_EVIDENCE.md",
    "compiler/selfhost/SH21_NATIVE_PE_AUDIT_TRANCHE4_EVIDENCE.md",
    "release/SH19_COMPILER_CAPABLE_NATIVE_BACKEND_EVIDENCE.md",
    "release/SH20_NATIVE_PUBLIC_THROUGHPUT_EVIDENCE.md",
    "compiler/selfhost/benchmark_sh20_stability.py",
    "compiler/selfhost/benchmark_sh20_references.py",
    "compiler/selfhost/run_with_memory_guard.py",
    "compiler/selfhost/windows_process_measure.py",
    "compiler/selfhost/source/backend_native_audit.p",
    "compiler/selfhost/source/backend_native_image.p",
    "compiler/selfhost/source/backend_native_runtime.p",
    "compiler/selfhost/source/backend_native_scalar.p",
    "compiler/selfhost/source/cli_workflow.p",
    "compiler/selfhost/source/cli_audit.p",
    "compiler/selfhost/source/cli_pe_audit.p",
    "scripts/audit_sh19_native_corpus.py",
    "scripts/verify_sh19_memory_guards.py",
    "scripts/verify_sh19_native_scalars.py",
    "tests/sh19_native_scalars/openc.project.json",
    "tests/SH21_NATIVE_WORKFLOW_TESTS.json",
    "tests/SH21_NATIVE_REPOSITORY_AUDIT_PLAN.tsv",
    "programs/E_NATIVE_OUT_POINTER/openc.project.json",
    "programs/E_NATIVE_OUT_POINTER/main.p",
    "compiler/selfhost/source/native_conformance.p",
    "compiler/selfhost/source/cli.p",
    "compiler/selfhost/source/cli_lsp.p",
    "compiler/selfhost/source/cli_lsp_semantic.p",
    "conformance/fixtures/NATIVE_PLAN.tsv",
    "schemas/LSP_TRANSCRIPT.schema.json",
    "schemas/SEMANTIC_LSP_TRANSCRIPT.schema.json",
    "tests/tooling/sh11/session.json",
    "tests/tooling/sh12/session.json",
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
    ROOT / "programs/E_NATIVE_OUT_POINTER/openc.project.json",
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
if self_host_gates.get("SH-9") != "PASS":
    errors.append("native CLI and diagnostic usability SH-9 gate must pass")
if self_host_gates.get("SH-9") == "PASS" and (
        not self_hosting.get("claims", {}).get("public_native_check")
        or not self_hosting.get("claims", {}).get("public_native_run")
        or not self_hosting.get("claims", {}).get(
            "human_and_machine_diagnostics"
        )
        or not self_hosting.get("claims", {}).get(
            "native_version_target_explain"
        )
        or not self_hosting.get("claims", {}).get(
            "demos_use_public_native_cli"
        )
        or self_hosting.get("claims", {}).get(
            "required_workflows_use_d_seed"
        )):
    errors.append(
        "SH-9 PASS requires public native check/run, human and machine "
        "diagnostics, information/rule commands, direct demo CLI use, "
        "and no required D-seed execution"
    )
if self_host_gates.get("SH-10") != "PASS":
    errors.append("native project workflow completeness SH-10 gate must pass")
if self_host_gates.get("SH-10") == "PASS" and (
        not self_hosting.get("claims", {}).get("public_native_format")
        or not self_hosting.get("claims", {}).get("public_native_info")
        or not self_hosting.get("claims", {}).get("public_native_test")
        or not self_hosting.get("claims", {}).get(
            "stable_native_project_workflow_records"
        )
        or self_hosting.get("claims", {}).get(
            "required_workflows_use_d_seed"
        )):
    errors.append(
        "SH-10 PASS requires native fmt/info/test, stable records, and no "
        "required D-seed execution"
    )
if self_host_gates.get("SH-11") != "PASS":
    errors.append("native language-service completeness SH-11 gate must pass")
if self_host_gates.get("SH-11") == "PASS" and (
        not self_hosting.get("claims", {}).get("public_native_lsp_stdio")
        or not self_hosting.get("claims", {}).get(
            "native_lsp_lifecycle_and_capability_negotiation"
        )
        or not self_hosting.get("claims", {}).get(
            "native_lsp_document_diagnostics"
        )
        or not self_hosting.get("claims", {}).get(
            "native_lsp_sh10_document_formatting"
        )
        or not self_hosting.get("claims", {}).get(
            "deterministic_native_lsp_transcripts"
        )
        or self_hosting.get("claims", {}).get(
            "required_workflows_use_d_seed"
        )):
    errors.append(
        "SH-11 PASS requires native stdio LSP lifecycle, diagnostics, "
        "SH-10 formatting, deterministic transcripts, and no required "
        "D-seed execution"
    )
if self_host_gates.get("SH-12") != "PASS":
    errors.append("native semantic language intelligence SH-12 gate must pass")
if self_host_gates.get("SH-12") == "PASS" and (
        not self_hosting.get("claims", {}).get(
            "native_lsp_document_symbols_and_typed_hover"
        )
        or not self_hosting.get("claims", {}).get(
            "native_lsp_project_definition_and_references"
        )
        or not self_hosting.get("claims", {}).get(
            "deterministic_native_lsp_completion"
        )
        or not self_hosting.get("claims", {}).get(
            "validated_native_lsp_safe_rename"
        )
        or not self_hosting.get("claims", {}).get(
            "deterministic_project_semantic_lsp_transcripts"
        )
        or self_hosting.get("claims", {}).get(
            "required_workflows_use_d_seed"
        )):
    errors.append(
        "SH-12 PASS requires project symbols, typed hover, navigation, "
        "references, deterministic completion, safe rename, semantic "
        "transcripts, and no required D-seed execution"
    )
if self_host_gates.get("SH-13") != "PASS":
    errors.append(
        "native throughput and implementation-independence SH-13 gate "
        "must pass"
    )
if self_host_gates.get("SH-13") == "PASS" and (
        not self_hosting.get("claims", {}).get(
            "native_throughput_and_implementation_independence"
        )
        or not self_hosting.get("claims", {}).get(
            "canonical_compiler_implementation_is_openc"
        )
        or not self_hosting.get("claims", {}).get(
            "standalone_excludes_d_and_python_source"
        )
        or not self_hosting.get("claims", {}).get(
            "tinycc_backend_dependency_disclosed"
        )):
    errors.append(
        "SH-13 PASS requires measured native throughput, canonical OpenC "
        "compiler authority, standalone D/Python-source exclusion, and "
        "explicit TinyCC dependency disclosure"
    )
sh14_gate = next(
    (gate for gate in self_hosting.get("gates", [])
     if gate.get("id") == "SH-14"),
    {},
)
if self_host_gates.get("SH-14") != "PASS":
    errors.append("compiler throughput and stability SH-14 gate must pass")
if self_host_gates.get("SH-14") == "PASS" and (
        sh14_gate.get("clean_runs") != 5
        or sh14_gate.get("clean_median_seconds", float("inf")) > 30.0
        or sh14_gate.get("clean_maximum_seconds", float("inf")) > 45.0
        or sh14_gate.get("relative_to_d_median", float("inf")) > 1.25
        or sh14_gate.get("consecutive_closed_rebuilds") != 20
        or sh14_gate.get("native_conformance_fixtures_passed") != 278
        or sh14_gate.get("maintained_programs_passed") != 4
        or not self_hosting.get("claims", {}).get(
            "compiler_throughput_convergence_and_stability"
        )
        or not self_hosting.get("claims", {}).get(
            "d_class_clean_throughput"
        )
        or not self_hosting.get("claims", {}).get(
            "sh14_twenty_build_closure"
        )):
    errors.append(
        "SH-14 PASS requires D-class clean throughput, five bounded clean "
        "runs, 20 closed rebuilds, conformance, and maintained programs"
    )

sh15_gate = next(
    (gate for gate in self_hosting.get("gates", [])
     if gate.get("id") == "SH-15"),
    {},
)
sh15_claims = self_hosting.get("claims", {})
if self_host_gates.get("SH-15") != "PASS":
    errors.append("Windows x64 ABI and machine-code SH-15 gate must pass")
if self_host_gates.get("SH-15") == "PASS" and (
        sh15_gate.get("native_compiler_source_files") != 104
        or sh15_gate.get("verification_checks_passed") != 25
        or sh15_gate.get("verification_checks_total") != 25
        or sh15_gate.get("native_conformance_fixtures_passed") != 278
        or sh15_gate.get("maintained_programs_passed") != 4
        or sh15_gate.get("full_workflow_tasks_passed") != 13
        or not sh15_gate.get("stage2_stage3_executable_byte_equal")
        or not sh15_gate.get("stage2_stage3_generated_c_byte_equal")
        or sh15_gate.get("external_assembler_invoked")
        or sh15_gate.get("external_linker_invoked_for_substrate")
        or not sh15_claims.get("windows_x64_abi_and_machine_code_substrate")
        or not sh15_claims.get("microsoft_x64_abi_model")
        or not sh15_claims.get("typed_x64_instruction_encoder")
        or not sh15_claims.get("first_party_x64_relocations")
        or not sh15_claims.get("x64_unwind_version_one")
        or not sh15_claims.get("sh15_executable_abi_probes")
        or not sh15_claims.get("sh15_deterministic_substrate")):
    errors.append(
        "SH-15 PASS requires the OpenC x64 ABI model, encoder, relocations, "
        "unwind records, deterministic executable probes, closure, and "
        "Windows Hosted correctness gates"
    )

planned = self_hosting.get("planned_milestones", {})
active_plan = planned.get("active", {})
sh16_gate = next(
    (gate for gate in self_hosting.get("gates", [])
     if gate.get("id") == "SH-16"),
    {},
)
sh16_claims = self_hosting.get("claims", {})
if self_host_gates.get("SH-16") != "PASS":
    errors.append("PE32+ and CRT-free runtime SH-16 gate must pass")
if self_host_gates.get("SH-16") == "PASS" and (
        sh16_gate.get("native_compiler_source_files") != 107
        or sh16_gate.get("verification_checks_passed") != 34
        or sh16_gate.get("verification_checks_total") != 34
        or sh16_gate.get("proof_image_bytes") != 6144
        or sh16_gate.get("section_count") != 7
        or sh16_gate.get("kernel32_import_count") != 15
        or sh16_gate.get("microsoft_crt_imported")
        or sh16_gate.get("tinycc_used_to_emit_proof_image")
        or sh16_gate.get("external_assembler_invoked_for_proof_image")
        or sh16_gate.get("external_linker_invoked_for_proof_image")
        or not sh16_gate.get("stage3_stage4_executable_byte_equal")
        or not sh16_gate.get("stage3_stage4_generated_c_byte_equal")
        or sh16_gate.get("native_conformance_fixtures_passed") != 278
        or sh16_gate.get("maintained_programs_passed") != 4
        or sh16_gate.get("full_workflow_tasks_passed") != 14
        or sh16_gate.get("bootstrap_tests_passed") != 38
        or not sh16_claims.get("minimal_pe32_plus_and_crt_free_runtime")
        or not sh16_claims.get("deterministic_first_party_pe32_plus_writer")
        or not sh16_claims.get("crt_free_windows_entry_and_runtime")
        or not sh16_claims.get("sh16_relocations_tls_and_unwind")
        or not sh16_claims.get("sh16_executable_runtime_proof")
        or not sh16_claims.get("sh16_deterministic_closure")):
    errors.append(
        "SH-16 PASS requires the deterministic first-party PE32+ writer, "
        "CRT-free executable runtime proof, closure, and Windows Hosted gates"
    )
sh17_gate = next(
    (gate for gate in self_hosting.get("gates", [])
     if gate.get("id") == "SH-17"),
    {},
)
sh17_claims = self_hosting.get("claims", {})
if self_host_gates.get("SH-17") != "PASS":
    errors.append("OpenC Win32 Metadata projection SH-17 gate must pass")
if self_host_gates.get("SH-17") == "PASS" and (
        sh17_gate.get("native_compiler_source_files") != 112
        or sh17_gate.get("verification_checks_passed") != 30
        or sh17_gate.get("verification_checks_total") != 30
        or sh17_gate.get("metadata_bytes") != 24355840
        or sh17_gate.get("raw_modules") != 7
        or sh17_gate.get("projected_records") != 71425
        or not sh17_gate.get("deterministic_projection_repeat_byte_equal")
        or not sh17_gate.get("checked_in_projection_reproduced")
        or sh17_gate.get("c_headers_parsed")
        or sh17_gate.get("third_party_metadata_library_used")
        or sh17_gate.get("ordinary_build_parses_winmd")
        or not sh17_gate.get("stage2_stage3_executable_byte_equal")
        or not sh17_gate.get("stage2_stage3_generated_c_byte_equal")
        or sh17_gate.get("native_conformance_fixtures_passed") != 278
        or sh17_gate.get("maintained_programs_passed") != 4
        or sh17_gate.get("full_workflow_tasks_passed") != 15
        or sh17_gate.get("bootstrap_tests_passed") != 42
        or not sh17_claims.get(
            "openc_win32_metadata_reader_and_raw_projection"
        )
        or not sh17_claims.get("purpose_built_openc_ecma335_reader")
        or not sh17_claims.get("deterministic_windows_raw_projection")
        or not sh17_claims.get("winmd_contract_metadata_preserved")
        or not sh17_claims.get("sh17_deterministic_closure")):
    errors.append(
        "SH-17 PASS requires the real pinned WinMD reader, deterministic raw "
        "projection, metadata preservation, closure, and Windows Hosted gates"
    )
sh19_gate = next(
    (gate for gate in self_hosting.get("gates", [])
     if gate.get("id") == "SH-19"),
    {},
)
sh19_claims = self_hosting.get("claims", {})
if self_host_gates.get("SH-19") != "PASS":
    errors.append("compiler-capable native backend SH-19 gate must pass")
if self_host_gates.get("SH-19") == "PASS" and (
        sh19_gate.get("compiler_source_files") != 116
        or sh19_gate.get("native_compiler_bytes") != 4712960
        or not sh19_gate.get("stage2_stage3_byte_equal")
        or sh19_gate.get("native_lowering_runtime_checks_passed") != 63
        or sh19_gate.get("native_lowering_runtime_checks_total") != 63
        or sh19_gate.get("native_memory_guard_checks_passed") != 6
        or sh19_gate.get("native_memory_guard_checks_total") != 6
        or sh19_gate.get("native_conformance_fixtures_passed") != 278
        or sh19_gate.get("maintained_programs_passed") != 4
        or sh19_gate.get("full_workflow_tasks_passed") != 16
        or sh19_gate.get("standalone_release_checks_passed") != 20
        or sh19_gate.get("tinycc_backend_required_for_general_builds")
        or sh19_gate.get("generated_c_required_for_general_builds")
        or sh19_gate.get("microsoft_crt_imported")
        or not sh19_claims.get("compiler_capable_first_party_native_backend")
        or not sh19_claims.get("direct_native_compiler_closure")
        or not sh19_claims.get("normal_build_excludes_generated_c_and_tinycc")
        or not sh19_claims.get("standalone_excludes_c_d_python_and_tinycc")
        or not sh19_claims.get("sh19_deterministic_closure")):
    errors.append(
        "SH-19 PASS requires native closure, complete runtime/tool gates, "
        "bounded memory, and normal-toolchain TinyCC/C/CRT exit"
    )
sh20_gate = next(
    (gate for gate in self_hosting.get("gates", [])
     if gate.get("id") == "SH-20"),
    {},
)
if self_host_gates.get("SH-20") != "PASS":
    errors.append("native public throughput SH-20 gate must pass")
if self_host_gates.get("SH-20") == "PASS" and (
        sh20_gate.get("compiler_source_files") != 116
        or sh20_gate.get("native_compiler_bytes") != 4941312
        or not sh20_gate.get("stage2_stage3_byte_equal")
        or sh20_gate.get("public_build_median_seconds", float("inf")) > 25.0
        or sh20_gate.get("public_build_maximum_seconds", float("inf")) > 35.0
        or sh20_gate.get("public_validation_median_seconds", float("inf")) >= 15.0
        or sh20_gate.get("relative_to_c_median", float("inf")) > 2.0
        or sh20_gate.get("relative_to_d_median", float("inf")) > 2.0
        or sh20_gate.get("consecutive_closed_rebuilds_observed") != 20
        or sh20_gate.get("peak_private_bytes", 2**63) > 268435456
        or sh20_gate.get("peak_working_set_bytes", 2**63) > 67108864
        or sh20_gate.get("semantic_validation_skipped")
        or sh20_gate.get("native_conformance_fixtures_passed") != 278
        or sh20_gate.get("maintained_programs_passed") != 4
        or sh20_gate.get("full_workflow_tasks_passed") != 16
        or sh20_gate.get("standalone_release_checks_passed") != 20
        or not sh19_claims.get("native_public_throughput_convergence")
        or not sh19_claims.get("public_build_performs_full_semantic_validation")
        or not sh19_claims.get("sh20_twenty_build_closure")
        or not sh19_claims.get("sh20_memory_gate")
        or not sh19_claims.get("sh20_deterministic_standalone_release")):
    errors.append(
        "SH-20 PASS requires C/D-class public throughput, full validation, "
        "20-build closure, bounded memory, and standalone release evidence"
    )
if (
    active_plan.get("id") != "SH-21"
    or active_plan.get("name")
    != "openc_native_workflows_and_bootstrap_boundary"
    or active_plan.get("status") != "ACTIVE"
    or active_plan.get("plan")
    != "compiler/selfhost/SH21_OPENC_NATIVE_WORKFLOWS_PLAN.md"
    or active_plan.get("blocked_by_sh20")
    or not active_plan.get("previous_openc_compiler_only_normal_environment")
    or active_plan.get("required_python_orchestration")
    or active_plan.get("required_d_orchestration")
    or active_plan.get("required_c_or_tinycc_orchestration")
    or not active_plan.get("openc_native_build_test_release")
    or not active_plan.get("openc_native_benchmark_and_package_verification")
    or not active_plan.get("optional_historical_bootstrap_audit_kit_separate")
    or not active_plan.get("sh20_performance_regression_required")
    or not active_plan.get("byte_identical_release_archives_required")
    or not active_plan.get("bounded_process_and_packaging_memory_required")
):
    errors.append("SH-21 OpenC-native workflows must be active after SH-20")
sh21_progress = active_plan.get("progress", {})
if (
    sh21_progress.get("status") != "TRANCHE_4_PASS_MILESTONE_ACTIVE"
    or sh21_progress.get("evidence")
    != "compiler/selfhost/SH21_NATIVE_PE_AUDIT_TRANCHE4_EVIDENCE.md"
    or sh21_progress.get("tranche_2_evidence")
    != "compiler/selfhost/SH21_NATIVE_PROCESS_GUARD_TRANCHE2_EVIDENCE.md"
    or sh21_progress.get("tranche_3_evidence")
    != "compiler/selfhost/SH21_NATIVE_REPOSITORY_AUDIT_TRANCHE3_EVIDENCE.md"
    or sh21_progress.get("workflow_schema") != "openc.native_workflow.v1"
    or sh21_progress.get("process_guard_schema")
    != "openc.native_process_guard.v1"
    or sh21_progress.get("repository_audit_schema")
    != "openc.native_repository_audit.v1"
    or sh21_progress.get("pe_audit_schema") != "openc.native_pe_audit.v1"
    or sh21_progress.get("native_daily_tasks_passed") != 6
    or sh21_progress.get("native_full_tasks_passed") != 10
    or sh21_progress.get("native_conformance_fixtures_passed") != 278
    or sh21_progress.get("maintained_and_runtime_programs_passed") != 5
    or sh21_progress.get("compiler_source_files") != 119
    or sh21_progress.get("compiler_source_bytes") != 1679762
    or sh21_progress.get("native_compiler_bytes") != 5348864
    or sh21_progress.get("native_compiler_sha256")
    != "2a758dc5f8c70fa09e83bbd33ed69da90a456310e27b77860a849fc845f6f437"
    or not sh21_progress.get("stage2_stage3_byte_equal")
    or not sh21_progress.get("renamed_compiler_workflow_passed")
    or sh21_progress.get("python_invoked_by_native_workflow")
    or sh21_progress.get("d_invoked_by_native_workflow")
    or sh21_progress.get("c_or_tinycc_invoked_by_native_workflow")
    or sh21_progress.get(
        "external_assembler_or_linker_invoked_by_native_workflow"
    )
    or sh21_progress.get("compiler_build_peak_private_bytes", 2**63)
    > 268435456
    or sh21_progress.get("compiler_build_peak_working_set_bytes", 2**63)
    > 67108864
    or sh21_progress.get("workflow_peak_private_bytes", 2**63) > 268435456
    or sh21_progress.get("workflow_peak_working_set_bytes", 2**63)
    > 67108864
    or sh21_progress.get("native_self_check_elapsed_milliseconds", 2**63)
    > 25000
    or not sh21_progress.get("native_self_check_uses_production_validation")
    or sh21_progress.get("native_process_guard_checks_passed") != 4
    or sh21_progress.get("native_process_guard_checks_total") != 4
    or sh21_progress.get("child_output_limit_bytes") != 4194304
    or sh21_progress.get("child_process_memory_limit_bytes") != 268435456
    or sh21_progress.get("child_job_memory_limit_bytes") != 268435456
    or sh21_progress.get("child_working_set_limit_bytes") != 67108864
    or sh21_progress.get("child_default_timeout_milliseconds") != 300000
    or not sh21_progress.get("child_tree_kill_on_close")
    or not sh21_progress.get("child_assigned_suspended")
    or not sh21_progress.get("native_child_process_enforcement_complete")
    or not sh21_progress.get("native_repository_audit_complete")
    or sh21_progress.get("native_required_files_passed") != 365
    or sh21_progress.get("native_pinned_hashes_passed") != 39
    or sh21_progress.get("native_fixture_identities_passed") != 278
    or sh21_progress.get("native_active_rule_coverage_passed") != 466
    or sh21_progress.get("native_grammar_production_coverage_passed") != 174
    or not sh21_progress.get("native_pe_audit_complete")
    or sh21_progress.get("native_pe_audit_checks_passed") != 16
    or sh21_progress.get("native_pe_audit_checks_total") != 16
    or sh21_progress.get("native_pe_sections") != 7
    or sh21_progress.get("native_pe_imports") != 28
    or sh21_progress.get("native_pe_runtime_functions") != 1337
    or sh21_progress.get("native_pe_dir64_relocations") != 4
    or sh21_progress.get("native_pe_negative_cases_rejected") != 4
    or sh21_progress.get("native_pe_audit_peak_private_bytes", 2**63)
    > 268435456
    or sh21_progress.get("native_pe_audit_peak_working_set_bytes", 2**63)
    > 67108864
    or sh21_progress.get("semantic_resolution_observer_peak_private_bytes", 2**63)
    > 268435456
    or sh21_progress.get(
        "semantic_resolution_observer_peak_working_set_bytes", 2**63
    ) > 67108864
    or not sh21_progress.get("native_structure_source_coverage_audits_complete")
    or not sh21_progress.get(
        "native_structure_source_pe_coverage_audits_complete"
    )
    or sh21_progress.get("native_structure_pe_lsp_release_audits_complete")
    or sh21_progress.get("deterministic_native_release_archives_complete")
    or sh21_progress.get("next_slice")
    != "OPENC_NATIVE_LSP_FRAMED_CLIENT_AND_TRANSCRIPT_AUDIT"
):
    errors.append(
        "SH-21 tranche 4 must record bounded native repository and PE audits "
        "without claiming unfinished LSP/release gates"
    )
development_self_hosting = development.get("self_hosting", {})
if development_self_hosting.get("next_milestone") != (
    "SH-21_OPENC_NATIVE_WORKFLOWS_AND_BOOTSTRAP_BOUNDARY"
):
    errors.append("development state must name OpenC-native workflows as SH-21")
development_sh19 = development_self_hosting.get("sh19_acceptance", {})
if (
    development_sh19.get("status") != "PASS"
    or not development_sh19.get("trusted_native_fixed_point")
    or development_sh19.get("native_lowering_runtime_checks_passed") != 63
    or development_sh19.get("native_lowering_runtime_checks_total") != 63
    or development_sh19.get("memory_guard_checks_passed") != 6
    or development_sh19.get("memory_guard_checks_total") != 6
    or development_sh19.get("public_validation_peak_private_bytes", 2**63)
    > 268435456
    or development_sh19.get("public_validation_peak_working_set_bytes", 2**63)
    > 67108864
    or development_sh19.get("public_self_conformance_errors") != 0
    or not development_sh19.get("direct_native_compiler_closure_passed")
    or not development_sh19.get("tinycc_exit_achieved")
    or development_sh19.get("generated_c_required")
    or development_sh19.get("c_runtime_required")
    or development_sh19.get("microsoft_crt_imported")
    or development_sh19.get("native_conformance_fixtures_passed") != 278
    or development_sh19.get("maintained_programs_passed") != 4
    or development_sh19.get("full_workflow_tasks_passed") != 16
):
    errors.append(
        "development state must record complete bounded SH-19 native closure"
    )
development_sh20 = development_self_hosting.get("sh20_acceptance", {})
if (
    development_sh20.get("status") != "PASS"
    or development_sh20.get("public_build_five_run_median_seconds", float("inf"))
    > 25.0
    or development_sh20.get(
        "public_validation_five_run_median_seconds", float("inf")
    ) >= 15.0
    or development_sh20.get("consecutive_closed_rebuilds_observed") != 20
    or not development_sh20.get("semantic_validation_must_not_be_skipped")
    or development_sh20.get("peak_private_bytes", 2**63) > 268435456
    or development_sh20.get("peak_working_set_bytes", 2**63) > 67108864
    or development_sh20.get("max_peak_private_bytes") != 268435456
    or development_sh20.get("max_peak_working_set_bytes") != 67108864
    or development_sh20.get("native_conformance_fixtures_passed") != 278
    or development_sh20.get("maintained_programs_passed") != 4
    or development_sh20.get("standalone_release_checks_passed") != 20
):
    errors.append("development state must record the passed SH-20 evidence")
development_sh21 = development_self_hosting.get("sh21_progress", {})
if (
    development_sh21.get("status") != "TRANCHE_4_PASS_MILESTONE_ACTIVE"
    or development_sh21.get("evidence")
    != "compiler/selfhost/SH21_NATIVE_PE_AUDIT_TRANCHE4_EVIDENCE.md"
    or development_sh21.get("tranche_2_evidence")
    != "compiler/selfhost/SH21_NATIVE_PROCESS_GUARD_TRANCHE2_EVIDENCE.md"
    or development_sh21.get("tranche_3_evidence")
    != "compiler/selfhost/SH21_NATIVE_REPOSITORY_AUDIT_TRANCHE3_EVIDENCE.md"
    or development_sh21.get("workflow_schema") != "openc.native_workflow.v1"
    or development_sh21.get("process_guard_schema")
    != "openc.native_process_guard.v1"
    or development_sh21.get("repository_audit_schema")
    != "openc.native_repository_audit.v1"
    or development_sh21.get("pe_audit_schema") != "openc.native_pe_audit.v1"
    or development_sh21.get("compiler_source_files") != 119
    or development_sh21.get("compiler_source_bytes") != 1679762
    or development_sh21.get("native_compiler_bytes") != 5348864
    or development_sh21.get("native_compiler_sha256")
    != "2a758dc5f8c70fa09e83bbd33ed69da90a456310e27b77860a849fc845f6f437"
    or not development_sh21.get("renamed_compiler_workflow_passed")
    or not development_sh21.get("stage2_stage3_byte_equal")
    or development_sh21.get("native_daily_tasks_passed") != 6
    or development_sh21.get("native_full_tasks_passed") != 10
    or development_sh21.get("native_conformance_fixtures_passed") != 278
    or development_sh21.get("maintained_and_runtime_programs_passed") != 5
    or development_sh21.get("python_invoked_by_native_workflow")
    or development_sh21.get("d_invoked_by_native_workflow")
    or development_sh21.get("c_or_tinycc_invoked_by_native_workflow")
    or development_sh21.get(
        "external_assembler_or_linker_invoked_by_native_workflow"
    )
    or development_sh21.get("compiler_build_peak_private_bytes", 2**63)
    > 268435456
    or development_sh21.get("compiler_build_peak_working_set_bytes", 2**63)
    > 67108864
    or development_sh21.get("workflow_peak_private_bytes", 2**63)
    > 268435456
    or development_sh21.get("workflow_peak_working_set_bytes", 2**63)
    > 67108864
    or development_sh21.get(
        "native_self_check_elapsed_milliseconds", 2**63
    ) > 25000
    or not development_sh21.get(
        "native_self_check_uses_production_validation"
    )
    or development_sh21.get("native_process_guard_checks_passed") != 4
    or development_sh21.get("native_process_guard_checks_total") != 4
    or development_sh21.get("child_output_limit_bytes") != 4194304
    or development_sh21.get("child_process_memory_limit_bytes") != 268435456
    or development_sh21.get("child_job_memory_limit_bytes") != 268435456
    or development_sh21.get("child_working_set_limit_bytes") != 67108864
    or development_sh21.get("child_default_timeout_milliseconds") != 300000
    or not development_sh21.get("child_tree_kill_on_close")
    or not development_sh21.get("child_assigned_suspended")
    or not development_sh21.get("native_child_process_enforcement_complete")
    or not development_sh21.get("native_repository_audit_complete")
    or development_sh21.get("native_required_files_passed") != 365
    or development_sh21.get("native_pinned_hashes_passed") != 39
    or development_sh21.get("native_fixture_identities_passed") != 278
    or development_sh21.get("native_active_rule_coverage_passed") != 466
    or development_sh21.get("native_grammar_production_coverage_passed") != 174
    or not development_sh21.get("native_pe_audit_complete")
    or development_sh21.get("native_pe_audit_checks_passed") != 16
    or development_sh21.get("native_pe_audit_checks_total") != 16
    or development_sh21.get("native_pe_sections") != 7
    or development_sh21.get("native_pe_imports") != 28
    or development_sh21.get("native_pe_runtime_functions") != 1337
    or development_sh21.get("native_pe_dir64_relocations") != 4
    or development_sh21.get("native_pe_negative_cases_rejected") != 4
    or development_sh21.get("native_pe_audit_peak_private_bytes", 2**63)
    > 268435456
    or development_sh21.get("native_pe_audit_peak_working_set_bytes", 2**63)
    > 67108864
    or development_sh21.get(
        "semantic_resolution_observer_peak_private_bytes", 2**63
    ) > 268435456
    or development_sh21.get(
        "semantic_resolution_observer_peak_working_set_bytes", 2**63
    ) > 67108864
    or not development_sh21.get(
        "native_structure_source_coverage_audits_complete"
    )
    or not development_sh21.get(
        "native_structure_source_pe_coverage_audits_complete"
    )
    or development_sh21.get("native_structure_pe_lsp_release_audits_complete")
    or development_sh21.get("deterministic_native_release_archives_complete")
    or development_sh21.get("next_slice")
    != "OPENC_NATIVE_LSP_FRAMED_CLIENT_AND_TRANSCRIPT_AUDIT"
):
    errors.append("development state must record bounded SH-21 tranche 4 progress")
development_sh14 = development_self_hosting.get("sh14_acceptance", {})
if (
    development_sh14.get("status") != "PASS"
    or development_sh14.get("observed_clean_median_seconds", float("inf"))
    > 30.0
    or development_sh14.get("consecutive_closed_rebuilds_observed") != 20
):
    errors.append("development state must record the passed SH-14 evidence")
development_sh15 = development_self_hosting.get("sh15_acceptance", {})
if (
    development_sh15.get("status") != "PASS"
    or development_sh15.get("verification_checks_passed") != 25
    or development_sh15.get("verification_checks_total") != 25
    or not development_sh15.get("stage2_stage3_byte_equal")
):
    errors.append("development state must record the passed SH-15 evidence")
development_sh16 = development_self_hosting.get("sh16_acceptance", {})
if (
    development_sh16.get("status") != "PASS"
    or development_sh16.get("verification_checks_passed") != 34
    or development_sh16.get("verification_checks_total") != 34
    or development_sh16.get("proof_image_bytes") != 6144
    or not development_sh16.get("stage3_stage4_byte_equal")
    or development_sh16.get("microsoft_crt_imported")
    or development_sh16.get("tinycc_used_to_emit_proof_image")
):
    errors.append("development state must record the passed SH-16 evidence")
development_sh17 = development_self_hosting.get("sh17_acceptance", {})
if (
    development_sh17.get("status") != "PASS"
    or development_sh17.get("verification_checks_passed") != 30
    or development_sh17.get("verification_checks_total") != 30
    or development_sh17.get("raw_modules") != 7
    or development_sh17.get("projected_records") != 71425
    or not development_sh17.get("stage2_stage3_byte_equal")
    or development_sh17.get("c_headers_parsed")
    or development_sh17.get("third_party_metadata_library_used")
    or development_sh17.get("ordinary_build_parses_winmd")
):
    errors.append("development state must record the passed SH-17 evidence")
windows_plan = planned.get("windows_independence_plan", {})
sh18 = development_self_hosting.get("sh18_acceptance", {})
if (sh18.get("status") != "PASS" or sh18.get("friendly_modules") != 12
        or sh18.get("verification_checks_passed") != 27
        or sh18.get("verification_checks_total") != 27
        or not sh18.get("stage2_stage3_byte_equal")
        or sh18.get("native_conformance_fixtures_passed") != 278
        or sh18.get("relative_to_d_median", float("inf")) > 1.25):
    errors.append("SH-18 requires modules, behavior, closure, conformance and throughput evidence")
if (
    windows_plan.get("implementation_blocked_until_sh14_pass")
    or not windows_plan.get("implementation_unblocked_by_sh14_pass")
    or not windows_plan.get("sh15_completed")
    or not windows_plan.get("sh16_completed")
    or not windows_plan.get("sh17_completed")
    or not windows_plan.get("sh18_completed")
    or not windows_plan.get("sh19_completed")
    or not windows_plan.get("sh20_completed")
    or windows_plan.get("active_milestone")
    != "SH-21_OPENC_NATIVE_WORKFLOWS_AND_BOOTSTRAP_BOUNDARY"
    or windows_plan.get("sequence", [None])[0]
    != "SH-15_WINDOWS_X64_ABI_AND_MACHINE_CODE_SUBSTRATE"
    or windows_plan.get("sequence", [None])[-1]
    != "SH-24_NATIVE_EDITOR_INTEGRATION_AND_LSP_RESILIENCE"
):
    errors.append(
        "Windows independence must advance to SH-21 with editor work last"
    )

windows_target = json.loads((
    ROOT / "compiler/targets/windows-x86_64.json"
).read_text(encoding="utf-8"))
abi_contract = windows_target.get("abi_contract", {})
artifact_contract = windows_target.get("artifact_contract", {})
if (
    windows_target.get("abi") != "win64"
    or abi_contract.get("schema") != "openc.windows_x64_abi.v1"
    or abi_contract.get("data_model", {}).get("name") != "LLP64"
    or abi_contract.get("arguments", {}).get("shadow_space_bytes") != 32
    or abi_contract.get("stack", {}).get("body_alignment_bytes") != 16
    or abi_contract.get("unwind", {}).get("version") != 1
    or abi_contract.get("unwind", {}).get("runtime_function_entry_bytes") != 12
    or artifact_contract.get("schema") != "openc.windows_pe32_runtime.v1"
    or artifact_contract.get("format") != "PE32+"
    or artifact_contract.get("machine") != "AMD64"
    or artifact_contract.get("sections")
    != [".text", ".rdata", ".data", ".pdata", ".xdata", ".tls", ".reloc"]
    or artifact_contract.get("imports", {}).get("allowed_system_dlls")
    != ["KERNEL32.dll"]
    or not artifact_contract.get("imports", {}).get("microsoft_crt_forbidden")
    or artifact_contract.get("unwind", {}).get("version") != 1
    or not artifact_contract.get("runtime", {}).get("utf8_command_line")
    or windows_target.get("evidence_state")
    != "SH16_PE32_PLUS_CRT_FREE_RUNTIME_PASS"
):
    errors.append(
        "Windows x64 target record must contain the passed SH-15 ABI and "
        "SH-16 PE32+ runtime contracts"
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
sh14_targets = budgets.get("sh14_exit_targets", {})
if (
    sh14_targets.get("status") != "PASS"
    or sh14_targets.get("clean_median_max_seconds") != 30.0
    or sh14_targets.get("clean_each_run_max_seconds") != 45.0
    or sh14_targets.get("consecutive_closed_rebuilds") != 20
    or sh14_targets.get("observed_clean_median_seconds", float("inf")) > 30.0
    or sh14_targets.get("observed_clean_maximum_seconds", float("inf")) > 45.0
    or sh14_targets.get("observed_relative_to_d_median", float("inf")) > 1.25
    or sh14_targets.get("observed_consecutive_closed_rebuilds") != 20
    or not sh14_targets.get(
        "current_900_second_ceiling_is_not_sh14_acceptance"
    )
):
    errors.append("SH-14 throughput exit targets are missing or weakened")
sh17_observation = budgets.get("sh17_regression_observation", {})
if (
    sh17_observation.get("status") != "PASS"
    or sh17_observation.get("clean_runs") != 5
    or sh17_observation.get("clean_median_seconds", float("inf")) > 30.0
    or sh17_observation.get("clean_maximum_seconds", float("inf")) > 45.0
    or sh17_observation.get("relative_to_d_median", float("inf")) > 1.25
    or sh17_observation.get("ordinary_build_parses_winmd")
    or not sh17_observation.get("all_existing_budgets_pass")
):
    errors.append("SH-17 throughput regression observation is missing or failed")
sh19_observation = budgets.get("sh19_native_backend_observation", {})
if (
    budgets.get("milestone")
    != "SH-19_COMPILER_CAPABLE_NATIVE_BACKEND_AND_TINYCC_EXIT"
    or sh19_observation.get("status") != "PASS"
    or sh19_observation.get("native_validation_ceiling_seconds") != 300.0
    or sh19_observation.get("native_validation_ceiling_is_sh20_acceptance")
    or sh19_observation.get("sh20_public_validation_median_target_seconds")
    != 15.0
    or budgets.get("budgets", {}).get("validation", {}).get(
        "max_elapsed_seconds"
    ) != 300.0
):
    errors.append(
        "SH-19 native budget observation must preserve the separate SH-20 "
        "validation target"
    )

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
    errors.append("required native release workflow must not audit the D seed")
if '"native_cli_12_of_12"' not in standalone_verifier:
    errors.append("standalone release must verify the complete SH-9 CLI contract")
if '"native_project_workflow_21_of_21"' not in standalone_verifier:
    errors.append(
        "standalone release must verify the complete SH-10 project workflow"
    )
if '"native_language_service_19_of_19"' not in standalone_verifier:
    errors.append(
        "standalone release must verify the complete SH-11 language-service "
        "contract"
    )
if '"native_semantic_language_service_23_of_23"' not in standalone_verifier:
    errors.append(
        "standalone release must verify the complete SH-12 semantic "
        "language-service contract"
    )
if '"openc.windows_native_workflow.v9"' not in native_workflow:
    errors.append("native workflow must record the SH-19 workflow schema")
if '"windows_friendly_modules"' not in native_workflow:
    errors.append("native workflow must verify the SH-18 friendly modules")

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
