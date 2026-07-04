@echo off
setlocal EnableExtensions

for %%I in ("%~dp0..\..") do set "PROJECT_DIR=%%~fI"

set "FORCE=0"
if /I "%~1"=="--force" set "FORCE=1"

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
set "CACHE_FILE=%PROJECT_DIR%\.godot\global_script_class_cache.cfg"
if not "%FORCE%"=="1" if exist "%CACHE_FILE%" exit /b 0

set "PREP_OUTPUT=%TEMP%\gameplay_tags_editor_import_%RANDOM%%RANDOM%.log"

echo Preparing Godot project cache with:
echo   %GODOT_BIN%
"%GODOT_BIN%" --headless --editor --path "%PROJECT_DIR%" --quit > "%PREP_OUTPUT%" 2>&1
set "GODOT_EXIT=%ERRORLEVEL%"

findstr /I /C:"SCRIPT ERROR" /C:"Compile Error" /C:"Parse Error" /C:"Parser Error" "%PREP_OUTPUT%" >nul
if not errorlevel 1 (
    echo.
    echo Godot editor import reported script errors:
    findstr /I /C:"SCRIPT ERROR" /C:"Compile Error" /C:"Parse Error" /C:"Parser Error" "%PREP_OUTPUT%"
    echo.
    echo Full log:
    echo   %PREP_OUTPUT%
    copy "%PREP_OUTPUT%" "%PREP_OUTPUT%.failed" >nul 2>nul
    echo Saved failed log:
    echo   %PREP_OUTPUT%.failed
    exit /b 1
)

if not "%GODOT_EXIT%"=="0" (
    if exist "%CACHE_FILE%" (
        echo Godot editor import exited with code %GODOT_EXIT% after creating the script class cache; continuing.
        del "%PREP_OUTPUT%" >nul 2>nul
        exit /b 0
    )

    echo.
    echo Godot editor import failed with code %GODOT_EXIT%.
    type "%PREP_OUTPUT%"
    del "%PREP_OUTPUT%" >nul 2>nul
    exit /b %GODOT_EXIT%
)

del "%PREP_OUTPUT%" >nul 2>nul
echo Godot project cache prepared.
exit /b 0
