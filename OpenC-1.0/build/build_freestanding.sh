#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
: "${DUB:=dub}"
"$DUB" build --root=runtime --build=release --compiler="${DC:-ldc2}"
printf '%s\n' "Freestanding runtime library source build completed."
printf '%s\n' "Target integration must supply openc.runtime.freestanding hooks."
