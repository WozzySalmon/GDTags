@echo off
setlocal
call "%~dp0build_native.cmd" "target=template_release" %*
exit /b %ERRORLEVEL%
