@echo off
setlocal EnableExtensions

for %%I in ("%~dp0..\..") do set "PROJECT_DIR=%%~fI"

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

set "CHECK_OUTPUT=%TEMP%\gameplay_tags_gdscript_check_%RANDOM%%RANDOM%.log"

if exist "%PROJECT_DIR%\.godot\extension_list.cfg" (
    del "%PROJECT_DIR%\.godot\extension_list.cfg" >nul 2>nul
)

echo Running Godot GDScript smoke check...
"%GODOT_BIN%" --headless --path "%PROJECT_DIR%" --script "res://tests/test_gameplay_tags.gd" > "%CHECK_OUTPUT%" 2>&1
set "GODOT_EXIT=%ERRORLEVEL%"

findstr /I /C:"SCRIPT ERROR" /C:"Compile Error" /C:"Parse Error" /C:"Parser Error" "%CHECK_OUTPUT%" >nul
if not errorlevel 1 (
    echo.
    echo GDScript script errors were found:
    findstr /I /C:"SCRIPT ERROR" /C:"Compile Error" /C:"Parse Error" /C:"Parser Error" "%CHECK_OUTPUT%"
    echo.
    echo Full log:
    echo   %CHECK_OUTPUT%
    exit /b 1
)

if not "%GODOT_EXIT%"=="0" (
    echo.
    echo Godot exited with code %GODOT_EXIT%.
    type "%CHECK_OUTPUT%"
    del "%CHECK_OUTPUT%" >nul 2>nul
    exit /b %GODOT_EXIT%
)

del "%CHECK_OUTPUT%" >nul 2>nul
echo GDScript smoke check passed.
exit /b 0
