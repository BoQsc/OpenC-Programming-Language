$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Python = if ($env:PYTHON) { $env:PYTHON } else { "python" }
$separator = [IO.Path]::PathSeparator
$env:PYTHONPATH = "$Root/compiler/bootstrap/python$separator$($env:PYTHONPATH)"
& $Python -m openc @args
exit $LASTEXITCODE
