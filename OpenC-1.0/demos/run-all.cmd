@echo off
setlocal enabledelayedexpansion

set "ROOT=C:\Users\Windows10_new\Documents\OpenC Programming Language\OpenC-1.0"
set "COMPILER=%ROOT%\compiler\openc.exe"

cd /d "%ROOT%"

set PASSED=0
set FAILED=0

echo Building and running all OpenC demos...
echo ========================================
echo.

for %%D in (hello calculator types strings ownership unsafe) do (
    echo [%%D]

    "%COMPILER%" build "demos\%%D\main.p" --output="demos\%%D\build\%%D.exe" >nul 2>&1
    if errorlevel 1 (
        echo   build: FAILED
        set /A FAILED+=1
    ) else (
        echo   build: ok  (demos\%%D\build\%%D.exe)

        "%COMPILER%" check "demos\%%D\main.p" >nul 2>&1
        if errorlevel 1 (
            echo   check: FAILED
            set /A FAILED+=1
        ) else (
            echo   check: ok

            "%COMPILER%" run "demos\%%D\main.p" 2>&1
            if errorlevel 1 (
                echo   run:   FAILED
                set /A FAILED+=1
            ) else (
                echo   run:   ok
                set /A PASSED+=1
            )
        )
    )
    echo.
)

echo ========================================
echo Result: %PASSED% passed, %FAILED% failed
endlocal