"""OpenC command-line driver implementation."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from .commands import normalize_parenthesis
from .compiler import Compiler
from .conformance import ConformanceRunner
from .explain import RuleDatabase
from .formatter import Formatter
from .lsp import run_stdio


VERSION = "1.0.0-rc.6"
CANONICAL_SOURCE_EXTENSION = ".p"


def repository_root() -> Path:
    current = Path(__file__).resolve()
    for parent in current.parents:
        if (parent / "standard" / "core" / "OpenC_Core_Current.md").exists():
            return parent
    return current.parents[3]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="openc", description="OpenC 1.0 authored bootstrap toolchain")
    parser.add_argument("--version", action="version", version=f"OpenC {VERSION}")
    sub = parser.add_subparsers(dest="command", required=True)

    for name in ("check", "generate", "build"):
        command = sub.add_parser(name)
        command.add_argument("project", nargs="?", default=".")
        command.add_argument("--diagnostics-format", choices=["human", "json", "jsonl"], default="human")
        if name == "build":
            command.add_argument("--output")

    fmt = sub.add_parser("fmt")
    fmt.add_argument("files", nargs="+")
    fmt.add_argument("--check", action="store_true")

    info = sub.add_parser("info")
    info.add_argument("project", nargs="?", default=".")
    info.add_argument("--context", action="store_true")
    info.add_argument("--sources", action="store_true")
    info.add_argument("--limits", action="store_true")

    explain = sub.add_parser("explain")
    explain.add_argument("rule_id")
    explain.add_argument("--format", choices=["human", "json"], default="human")

    validate = sub.add_parser("validate")
    validate.add_argument("bundle")
    validate.add_argument("--output", default="build/conformance-result.json")

    sub.add_parser("lsp").add_argument("--stdio", action="store_true", default=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if len(argv) == 1 and "(" in argv[0] and argv[0].endswith(")"):
        request = normalize_parenthesis(argv[0])
        argv = [request.command, *request.positionals]
        for key, value in request.options.items():
            option = "--" + key.replace("_", "-")
            if isinstance(value, bool):
                if value:
                    argv.append(option)
            elif isinstance(value, list):
                for item in value:
                    argv.extend([option, str(item)])
            elif value is not None:
                argv.extend([option, str(value)])
    args = build_parser().parse_args(argv)
    root = repository_root()

    if args.command in {"check", "generate", "build"}:
        compiler = Compiler()
        project = compiler.load_project(Path(args.project))
        result = compiler.check(project) if args.command == "check" else compiler.generate(project) if args.command == "generate" else compiler.build(project, Path(args.output).resolve() if args.output else None)
        render_diagnostics(compiler, args.diagnostics_format)
        if result.build_record:
            record_path = project.output_directory / "records" / f"{args.command}-record.json"
            record_path.parent.mkdir(parents=True, exist_ok=True)
            record_path.write_text(json.dumps(result.build_record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return 0 if result.success else 1

    if args.command == "fmt":
        formatter = Formatter()
        changed = False
        for name in args.files:
            path = Path(name)
            original = path.read_text(encoding="utf-8")
            formatted = formatter.format_text(str(path), original)
            if formatted != original:
                changed = True
                if not args.check:
                    path.write_text(formatted, encoding="utf-8", newline="\n")
        return 1 if args.check and changed else 0

    if args.command == "info":
        compiler = Compiler()
        project = compiler.load_project(Path(args.project))
        data = {
            "schema": "openc.tool_context.v1",
            "tool": {"name": "openc", "version": VERSION},
            "project": {"name": project.name, "version": project.version, "file": str(project.project_file)},
            "edition": project.edition,
            "profile": project.profile,
            "canonical_source_extension": CANONICAL_SOURCE_EXTENSION,
            "target": project.target_name,
            "modules": {name: [str(path) for path in paths] for name, paths in sorted(project.modules.items())},
            "build_context": dict(sorted(project.target().build_context.items())),
            "implementation_limits": {
                "maximum_source_bytes": 268435456,
                "maximum_tokens_per_source": 16777216,
                "maximum_block_nesting": 4096,
                "maximum_diagnostics": 10000,
            },
        }
        print(json.dumps(data, indent=2, sort_keys=True))
        return 0

    if args.command == "explain":
        explanation = RuleDatabase(root).explain(args.rule_id)
        if args.format == "json":
            print(json.dumps(explanation, indent=2, sort_keys=True))
        else:
            print(f"{explanation['rule_id']} — {explanation['title']}")
            if explanation["summary"]:
                print("\n" + explanation["summary"])
            if explanation["phase"]:
                print(f"\nphase: {explanation['phase']}")
            if explanation["category"]:
                print(f"category: {explanation['category']}")
        return 0 if explanation["known"] else 1

    if args.command == "validate":
        report = ConformanceRunner(root).run_bundle(Path(args.bundle), Path(args.output))
        print(json.dumps(report["summary"], indent=2, sort_keys=True))
        return 0 if report["summary"]["failed"] == 0 and report["summary"]["infrastructure_failures"] == 0 else 1

    if args.command == "lsp":
        return run_stdio(root)
    return 2


def render_diagnostics(compiler: Compiler, format_name: str) -> None:
    if format_name == "json":
        print(json.dumps(compiler.diagnostics.to_json(), indent=2, sort_keys=True))
    elif format_name == "jsonl":
        for item in compiler.diagnostics.to_json():
            print(json.dumps(item, sort_keys=True))
    else:
        rendered = compiler.diagnostics.render()
        if rendered:
            print(rendered, file=sys.stderr)


if __name__ == "__main__":
    raise SystemExit(main())
