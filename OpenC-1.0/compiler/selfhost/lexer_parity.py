#!/usr/bin/env python3
"""Compare stage-0 and compiler-in-OpenC lexer observations."""
from __future__ import annotations

import argparse
import difflib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CANONICAL_ROOTS = (
    ROOT / "compiler",
    ROOT / "conformance",
    ROOT / "examples",
    ROOT / "programs",
    ROOT / "standard_library",
    ROOT / "tests",
    ROOT / "runtime",
    ROOT / "tools",
)

PROBES = {
    "valid_all_symbols.p": (
        "<<= >>= == != <= >= << >> && || += -= *= /= %= &= |= ^= .. "
        "; , . ( ) { } [ ] : + - * / % & | ^ ! ~ = < >\n"
    ),
    "valid_unicode_payloads.p": '// π 😀\ntext value = "π 😀";\n',
    "unterminated_comment.p": "/*",
    "numeric_suffix.p": "123u32",
    "numeric_separator_repeat.p": "1__2",
    "numeric_separator_trailing.p": "1_",
    "numeric_hex_missing_digits.p": "0x",
    "text_line_break.p": '"line\nnext',
    "text_unknown_escape.p": '"\\q"',
    "text_unicode_shape.p": '"\\u{}"',
    "text_unicode_scalar.p": '"\\u{D800}"',
    "text_unterminated.p": '"unterminated',
    "optional_question_mark.p": "?",
    "invalid_character_ascii.p": "@",
    "invalid_character_utf8.p": "π",
}

EXPECTED_DIAGNOSTIC_RULES = {
    "OPENC-LEX-COMMENT-001",
    "OPENC-LEX-NUMBER-SUFFIX-001",
    "OPENC-LEX-NUMBER-SEPARATOR-001",
    "OPENC-LEX-NUMBER-001",
    "OPENC-LEX-TEXT-LINE-001",
    "OPENC-LEX-TEXT-ESCAPE-001",
    "OPENC-LEX-TEXT-UNICODE-001",
    "OPENC-LITERAL-UNICODE-001",
    "OPENC-LEX-TEXT-001",
    "OPENC-SYNTAX-OPTIONAL-001",
    "OPENC-LEX-TOKEN-001",
    "OPENC-SOURCE-INVALID-001",
}


def canonical_sources() -> list[Path]:
    sources: set[Path] = set()
    for root in CANONICAL_ROOTS:
        if root.is_dir():
            sources.update(path.resolve() for path in root.rglob("*.p"))
    return sorted(sources, key=lambda path: path.relative_to(ROOT).as_posix())


def execute(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=ROOT, text=True, capture_output=True, encoding="utf-8")


def observed_rules(output: str) -> set[str]:
    rules: set[str] = set()
    for line in output.splitlines():
        if line.startswith("ERROR ") or line.startswith("SOURCE_ERROR "):
            rules.add(line.split()[1])
    return rules


def compare_one(
    stage0: Path, stage1: Path, source: Path
) -> tuple[bool, str, int, set[str]]:
    reference = execute([str(stage0), "lex-observe", str(source)])
    candidate = execute([str(stage1), str(source)])
    if reference.returncode not in (0, 1):
        return False, f"stage 0 infrastructure exit {reference.returncode}: {reference.stderr}", 0, set()
    if candidate.returncode not in (0, 1):
        return False, f"stage 1 infrastructure exit {candidate.returncode}: {candidate.stderr}", 0, set()
    if reference.returncode != candidate.returncode or reference.stdout != candidate.stdout:
        difference = "".join(
            difflib.unified_diff(
                reference.stdout.splitlines(keepends=True),
                candidate.stdout.splitlines(keepends=True),
                fromfile="stage0",
                tofile="stage1",
                n=3,
            )
        )
        return (
            False,
            f"exit stage0={reference.returncode} stage1={candidate.returncode}\n"
            f"{difference[:12000]}",
            0,
            set(),
        )
    return True, "", reference.returncode, observed_rules(reference.stdout)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage0", type=Path, default=ROOT / "compiler" / "openc.exe")
    parser.add_argument(
        "--stage1",
        type=Path,
        default=ROOT / "build-output" / "selfhost" / "openc-selfhost-lexer.exe",
    )
    parser.add_argument("--output", type=Path, default=ROOT / "build-output" / "selfhost")
    args = parser.parse_args()

    stage0 = args.stage0.resolve()
    stage1 = args.stage1.resolve()
    output = args.output.resolve()
    probe_root = output / "lexer-parity-probes"
    probe_root.mkdir(parents=True, exist_ok=True)
    for name, source in PROBES.items():
        (probe_root / name).write_text(source, encoding="utf-8", newline="\n")

    canonical = canonical_sources()
    probes = sorted(probe_root.glob("*.p"), key=lambda path: path.name)
    failures: list[dict[str, str]] = []
    accepted = 0
    rejected = 0
    diagnostic_rules: set[str] = set()
    for source in canonical + probes:
        matched, detail, exit_code, rules = compare_one(stage0, stage1, source)
        if not matched:
            try:
                label = source.relative_to(ROOT).as_posix()
            except ValueError:
                label = str(source)
            failures.append({"source": label, "detail": detail})
            if len(failures) == 10:
                break
        elif exit_code == 0:
            accepted += 1
        else:
            rejected += 1
        diagnostic_rules.update(rules)

    missing_rules = EXPECTED_DIAGNOSTIC_RULES - diagnostic_rules
    if missing_rules:
        failures.append({
            "source": "<diagnostic-coverage>",
            "detail": "missing observed rules: " + ", ".join(sorted(missing_rules)),
        })

    result = {
        "schema": "openc.self_host_lexer_parity.v1",
        "stage": "SH-2A_LEXER_PARITY",
        "status": "PASS" if not failures else "FAIL",
        "protocol": "OPENC-LEX-OBSERVATION 1",
        "stage0": str(stage0),
        "stage1": str(stage1),
        "canonical_sources": len(canonical),
        "focused_probes": len(probes),
        "comparisons": len(canonical) + len(probes) if not failures else accepted + rejected + len(failures),
        "accepted": accepted,
        "lexically_rejected": rejected,
        "diagnostic_rules_matched": sorted(diagnostic_rules),
        "diagnostic_rule_count": len(diagnostic_rules),
        "failures": failures,
        "matched_fields": [
            "process_exit",
            "token_kind",
            "token_byte_offset",
            "token_byte_length",
            "diagnostic_rule",
            "diagnostic_byte_offset",
            "diagnostic_byte_length",
            "source_encoding_rule",
            "token_count",
            "error_count",
        ],
    }
    (output / "lexer-parity-result.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    if failures:
        first = failures[0]
        raise SystemExit(f"lexer parity failed: {first['source']}\n{first['detail']}")
    print(
        "self-host lexer parity: PASS; "
        f"canonical={len(canonical)} probes={len(probes)} "
        f"comparisons={len(canonical) + len(probes)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
