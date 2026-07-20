#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
: "${DUB:=dub}"
"$DUB" build --root=runtime --build=release
"$DUB" build --root=standard_library --build=release
"$DUB" build --root=compiler --config=compiler --build=release
printf '%s\n' "OpenC compiler source build completed: compiler/openc"
