#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
find "$ROOT" -type d -name .dub -prune -exec rm -rf {} +
find "$ROOT" -type d -name build -not -path "$ROOT/build" -prune -exec rm -rf {} +
find "$ROOT" -type f \( -name '*.o' -o -name '*.obj' -o -name '*.exe' -o -name 'openc' \) -delete
