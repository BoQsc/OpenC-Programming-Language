$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Python = if ($env:PYTHON) { $env:PYTHON } else { "python" }
& $Python "$Root/build/build_all.py" --tools @args
exit $LASTEXITCODE
