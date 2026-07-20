$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Get-ChildItem $Root -Recurse -Directory -Filter ".dub" | Remove-Item -Recurse -Force
Get-ChildItem $Root -Recurse -File | Where-Object { $_.Extension -in ".o", ".obj", ".exe" } | Remove-Item -Force
