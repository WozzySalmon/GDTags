@echo off
setlocal

call "%~dp0build_native.cmd" %*
if errorlevel 1 exit /b %ERRORLEVEL%

call "%~dp0test_native.cmd"
exit /b %ERRORLEVEL%
