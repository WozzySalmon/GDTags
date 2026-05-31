@echo off
setlocal

call "%~dp0build_native_windows.cmd" %*
if errorlevel 1 exit /b %ERRORLEVEL%

call "%~dp0test_native_windows.cmd"
exit /b %ERRORLEVEL%
