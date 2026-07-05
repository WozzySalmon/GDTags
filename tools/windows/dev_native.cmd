@echo off
echo Native GDExtension runtime is deferred in the clean restart.
echo Running the GDScript workflow smoke suite instead.
call "%~dp0test_native.cmd"
exit /b %ERRORLEVEL%
