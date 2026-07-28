& "C:\Users\Windows10_new\Documents\OpenC Programming Language\OpenC-1.0\compiler\openc.exe" check "demos\hello\main.p"
if ($?) { Write-Host "  hello: check passed" } else { Write-Host "  hello: CHECK FAILED" }

& "C:\Users\Windows10_new\Documents\OpenC Programming Language\OpenC-1.0\compiler\openc.exe" check "demos\calculator\main.p"
if ($?) { Write-Host "  calculator: check passed" } else { Write-Host "  calculator: CHECK FAILED" }

& "C:\Users\Windows10_new\Documents\OpenC Programming Language\OpenC-1.0\compiler\openc.exe" check "demos\types\main.p"
if ($?) { Write-Host "  types: check passed" } else { Write-Host "  types: CHECK FAILED" }

& "C:\Users\Windows10_new\Documents\OpenC Programming Language\OpenC-1.0\compiler\openc.exe" check "demos\strings\main.p"
if ($?) { Write-Host "  strings: check passed" } else { Write-Host "  strings: CHECK FAILED" }

& "C:\Users\Windows10_new\Documents\OpenC Programming Language\OpenC-1.0\compiler\openc.exe" check "demos\ownership\main.p"
if ($?) { Write-Host "  ownership: check passed" } else { Write-Host "  ownership: CHECK FAILED" }

& "C:\Users\Windows10_new\Documents\OpenC Programming Language\OpenC-1.0\compiler\openc.exe" check "demos\unsafe\main.p"
if ($?) { Write-Host "  unsafe: check passed" } else { Write-Host "  unsafe: CHECK FAILED" }