@echo off
setlocal
set "ROOT=%~dp0.."
if "%PYTHON%"=="" set "PYTHON=python"
"%PYTHON%" "%ROOT%\build\build_all.py" --tools %*
exit /b %ERRORLEVEL%
