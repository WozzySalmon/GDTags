@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0package_addon.ps1" %*
exit /b %ERRORLEVEL%
