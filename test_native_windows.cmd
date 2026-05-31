@echo off
setlocal EnableExtensions

set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

if not defined GODOT_BIN (
    set "GODOT_BIN=C:\Users\Big-Boi\Desktop\Game develpoment Programs\Godot_v4.6.3-stable_win64.exe"
)

if not exist "%GODOT_BIN%" (
    echo Could not find Godot executable:
    echo   %GODOT_BIN%
    echo.
    echo Set GODOT_BIN before running this script, for example:
    echo   set "GODOT_BIN=C:\Path\To\Godot_v4.6.x-stable_win64.exe"
    exit /b 1
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
