@echo off
setlocal
call "%~dp0build_native_windows.cmd" "target=template_release" %*
exit /b %ERRORLEVEL%
