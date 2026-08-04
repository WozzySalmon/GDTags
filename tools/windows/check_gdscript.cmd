@echo off
setlocal EnableExtensions

rem Keep the quick-check entry point aligned with the complete smoke suite so it
rem cannot miss editor-only parse, compile, or plugin-loading failures.
call "%~dp0test_addon.cmd" %*
exit /b %ERRORLEVEL%
