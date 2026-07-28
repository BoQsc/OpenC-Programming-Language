@echo off
py -3 "%~dp0run_all.py" %*
exit /b %ERRORLEVEL%
