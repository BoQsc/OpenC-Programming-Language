$root = "C:\Users\Windows10_new\Documents\OpenC Programming Language\OpenC-1.0"
$compiler = "$root\compiler\openc.exe"
$demos = @("hello", "calculator", "types", "strings", "ownership", "unsafe")

Push-Location -LiteralPath $root

Write-Host "Building and running all OpenC demos..."
Write-Host "========================================`n"

$passed = 0
$failed = 0

foreach ($demo in $demos) {
    $src = "demos\$demo\main.p"
    $out = "demos\$demo\build\$demo.exe"
    Write-Host "[$demo]" -ForegroundColor Cyan

    $null = & $compiler build $src --output=$out 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  build: ok  ($out)" -ForegroundColor Green
    } else {
        Write-Host "  build: FAILED" -ForegroundColor Red
        $failed++
        continue
    }

    $null = & $compiler check $src 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  check: ok" -ForegroundColor Green
    } else {
        Write-Host "  check: FAILED" -ForegroundColor Red
        $failed++
        continue
    }

    $output = & $compiler run $src 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  run:   ok" -ForegroundColor Green
        Write-Host "  output:"
        $output | ForEach-Object { Write-Host "    $_" }
        $passed++
    } else {
        Write-Host "  run:   FAILED (exit $LASTEXITCODE)" -ForegroundColor Red
        $output | ForEach-Object { Write-Host "    $_" }
        $failed++
    }
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Result: $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })

Pop-Location