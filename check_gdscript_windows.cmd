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

set "CHECK_OUTPUT=%TEMP%\gameplay_tags_gdscript_check_%RANDOM%%RANDOM%.log"

echo Running Godot editor script scan...
"%GODOT_BIN%" --headless --editor --path "%PROJECT_DIR%" --quit > "%CHECK_OUTPUT%" 2>&1
set "GODOT_EXIT=%ERRORLEVEL%"

if not "%GODOT_EXIT%"=="0" (
    echo.
    echo Godot exited with code %GODOT_EXIT%.
    type "%CHECK_OUTPUT%"
    del "%CHECK_OUTPUT%" >nul 2>nul
    exit /b %GODOT_EXIT%
)

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

del "%CHECK_OUTPUT%" >nul 2>nul
echo GDScript project scan passed.
exit /b 0
