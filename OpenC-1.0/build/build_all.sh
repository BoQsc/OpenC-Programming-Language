#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
exec "${PYTHON:-python3}" "$ROOT/build/build_all.py" --tools "$@"
