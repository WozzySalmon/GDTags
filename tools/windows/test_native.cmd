@echo off
setlocal EnableExtensions

for %%I in ("%~dp0..\..") do set "PROJECT_DIR=%%~fI"

if not defined GODOT_BIN set "GODOT_BIN=godot"

if exist "%GODOT_BIN%" goto :godot_ready

for /f "delims=" %%I in ('where "%GODOT_BIN%" 2^>nul') do (
    set "GODOT_BIN=%%~fI"
    goto :godot_ready
)

echo Could not find Godot executable:
echo   %GODOT_BIN%
echo.
echo Put Godot on PATH or set GODOT_BIN before running this script, for example:
echo   set "GODOT_BIN=C:\Path\To\Godot.exe"
exit /b 1

:godot_ready

call "%~dp0prepare_project.cmd"
if errorlevel 1 exit /b %ERRORLEVEL%

if exist "%PROJECT_DIR%\.godot\extension_list.cfg" (
    del "%PROJECT_DIR%\.godot\extension_list.cfg" >nul 2>nul
)

call :run_test "GDScript runtime smoke test" "res://tests/test_gameplay_tags.gd" || exit /b 1
call :run_test "Native smoke test" "res://tests/test_native_gameplay_tags_headless.gd" || exit /b 1
call :run_test "Autoload native-selection smoke test" "res://tests/test_gameplay_tags_autoload_native_headless.gd" || exit /b 1

echo.
echo All Gameplay Tags smoke tests passed.
exit /b 0

:run_test
echo.
echo === %~1 ===
"%GODOT_BIN%" --headless --path "%PROJECT_DIR%" --script "%~2"
if errorlevel 1 (
    echo.
    echo FAILED: %~1
    exit /b 1
)
exit /b 0
