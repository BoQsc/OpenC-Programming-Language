$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $Root
$Dub = if ($env:DUB) { $env:DUB } else { "dub" }
& $Dub build --root=runtime --build=release
& $Dub build --root=standard_library --build=release
& $Dub build --root=compiler --config=compiler --build=release
Write-Host "OpenC compiler source build completed."
