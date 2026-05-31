@echo off
setlocal EnableExtensions

set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

where gdformat >nul 2>nul
if errorlevel 1 (
    echo gdformat was not found.
    echo.
    echo Install optional GDScript formatting tools with:
    echo   python -m pip install --user gdtoolkit
    exit /b 1
)

gdformat "%PROJECT_DIR%\addons\gameplay_tags" "%PROJECT_DIR%\benchmarks" "%PROJECT_DIR%\tests" %*
exit /b %ERRORLEVEL%
