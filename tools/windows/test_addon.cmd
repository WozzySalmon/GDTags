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

call :run_script_test "GDScript Gameplay Tags workflow smoke test" "res://tests/test_gameplay_tags.gd" || exit /b 1
call :run_script_test "GDScript editor workflow tests" "res://tests/test_editor_workflows.gd" || exit /b 1
call :run_script_test "GDScript runtime edge-case tests" "res://tests/test_runtime_edge_cases.gd" || exit /b 1
call :run_script_test "GDScript tag lifecycle tests" "res://tests/test_tag_lifecycle.gd" || exit /b 1
call :run_expected_runtime_error_test "Shared harness runtime-error regression probe" "res://tests/fixtures/runtime_error_after_assertion.gd" "runtime_error_after_assertion raised a script runtime error" || exit /b 1
call :run_editor_script_test "GDScript editor picker interaction tests" "res://tests/test_editor_picker_interactions.gd" || exit /b 1
call :run_editor_smoke || exit /b 1

echo.
echo All Gameplay Tags smoke tests passed.
exit /b 0

:run_script_test
set "TEST_OUTPUT=%TEMP%\gameplay_tags_script_test_%RANDOM%%RANDOM%.log"
echo.
echo === %~1 ===
"%GODOT_BIN%" --headless --path "%PROJECT_DIR%" --script "%~2" > "%TEST_OUTPUT%" 2>&1
set "GODOT_EXIT=%ERRORLEVEL%"
type "%TEST_OUTPUT%"
call :check_log "%TEST_OUTPUT%" || exit /b 1
if not "%GODOT_EXIT%"=="0" (
    del "%TEST_OUTPUT%" >nul 2>nul
    exit /b %GODOT_EXIT%
)
del "%TEST_OUTPUT%" >nul 2>nul
exit /b 0

:run_expected_runtime_error_test
set "TEST_OUTPUT=%TEMP%\gameplay_tags_expected_failure_%RANDOM%%RANDOM%.log"
echo.
echo === %~1 ===
"%GODOT_BIN%" --headless --path "%PROJECT_DIR%" --script "%~2" > "%TEST_OUTPUT%" 2>&1
set "GODOT_EXIT=%ERRORLEVEL%"
type "%TEST_OUTPUT%"
if "%GODOT_EXIT%"=="0" (
    echo Expected the harness probe to fail, but Godot exited successfully.
    echo Full log:
    echo   %TEST_OUTPUT%
    exit /b 1
)
findstr /L /C:"%~3" "%TEST_OUTPUT%" >nul
if errorlevel 1 (
    echo The harness probe did not report the expected captured runtime error.
    echo Full log:
    echo   %TEST_OUTPUT%
    exit /b 1
)
findstr /L /C:"PASS runtime_error_after_assertion" "%TEST_OUTPUT%" >nul
if not errorlevel 1 (
    echo The harness incorrectly reported PASS after a script runtime error.
    echo Full log:
    echo   %TEST_OUTPUT%
    exit /b 1
)
del "%TEST_OUTPUT%" >nul 2>nul
exit /b 0

:run_editor_script_test
set "TEST_OUTPUT=%TEMP%\gameplay_tags_editor_script_test_%RANDOM%%RANDOM%.log"
echo.
echo === %~1 ===
"%GODOT_BIN%" --headless --editor --path "%PROJECT_DIR%" --script "%~2" > "%TEST_OUTPUT%" 2>&1
set "GODOT_EXIT=%ERRORLEVEL%"
type "%TEST_OUTPUT%"
call :check_log "%TEST_OUTPUT%" || exit /b 1
if not "%GODOT_EXIT%"=="0" (
    del "%TEST_OUTPUT%" >nul 2>nul
    exit /b %GODOT_EXIT%
)
del "%TEST_OUTPUT%" >nul 2>nul
exit /b 0

:run_editor_smoke
set "EDITOR_OUTPUT=%TEMP%\gameplay_tags_editor_smoke_%RANDOM%%RANDOM%.log"
echo.
echo === Editor/plugin smoke check ===
"%GODOT_BIN%" --headless --editor --path "%PROJECT_DIR%" --quit > "%EDITOR_OUTPUT%" 2>&1
set "GODOT_EXIT=%ERRORLEVEL%"
call :check_log "%EDITOR_OUTPUT%" || exit /b 1
if not "%GODOT_EXIT%"=="0" (
    echo Godot editor exited with code %GODOT_EXIT%.
    type "%EDITOR_OUTPUT%"
    del "%EDITOR_OUTPUT%" >nul 2>nul
    exit /b %GODOT_EXIT%
)
del "%EDITOR_OUTPUT%" >nul 2>nul
exit /b 0

:check_log
findstr /I /C:"SCRIPT ERROR" /C:"Compile Error" /C:"Parse Error" /C:"Parser Error" "%~1" >nul
if not errorlevel 1 (
    echo Godot reported script errors:
    findstr /I /C:"SCRIPT ERROR" /C:"Compile Error" /C:"Parse Error" /C:"Parser Error" "%~1"
    echo Full log:
    echo   %~1
    exit /b 1
)
exit /b 0
