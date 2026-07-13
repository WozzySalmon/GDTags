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

call "%~dp0prepare_project.cmd" --force
if errorlevel 1 exit /b %ERRORLEVEL%


call :run_test "GDScript Gameplay Tags workflow smoke test" "res://tests/test_gameplay_tags.gd" || exit /b 1
call :run_editor_smoke || exit /b 1

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

:run_editor_smoke
set "EDITOR_OUTPUT=%TEMP%\gameplay_tags_editor_smoke_%RANDOM%%RANDOM%.log"
echo.
echo === Editor/plugin smoke check ===
"%GODOT_BIN%" --headless --editor --path "%PROJECT_DIR%" --quit > "%EDITOR_OUTPUT%" 2>&1
set "GODOT_EXIT=%ERRORLEVEL%"

findstr /I /C:"SCRIPT ERROR" /C:"Compile Error" /C:"Parse Error" /C:"Parser Error" "%EDITOR_OUTPUT%" >nul
if not errorlevel 1 (
    echo Godot editor reported script errors:
    findstr /I /C:"SCRIPT ERROR" /C:"Compile Error" /C:"Parse Error" /C:"Parser Error" "%EDITOR_OUTPUT%"
    echo Full log:
    echo   %EDITOR_OUTPUT%
    exit /b 1
)

if not "%GODOT_EXIT%"=="0" (
    echo Godot editor exited with code %GODOT_EXIT%.
    type "%EDITOR_OUTPUT%"
    del "%EDITOR_OUTPUT%" >nul 2>nul
    exit /b %GODOT_EXIT%
)

del "%EDITOR_OUTPUT%" >nul 2>nul
exit /b 0
