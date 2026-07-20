@echo off
setlocal
set "ROOT=%~dp0.."
if "%PYTHON%"=="" set "PYTHON=python"
set "PYTHONPATH=%ROOT%\compiler\bootstrap\python;%PYTHONPATH%"
"%PYTHON%" -m openc %*
exit /b %ERRORLEVEL%
