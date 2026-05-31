@echo off
setlocal EnableExtensions

set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

where gdlint >nul 2>nul
if errorlevel 1 (
    echo gdlint was not found.
    echo.
    echo Install optional GDScript linting tools with:
    echo   python -m pip install --user gdtoolkit
    exit /b 1
)

gdlint "%PROJECT_DIR%\addons\gameplay_tags" "%PROJECT_DIR%\benchmarks" "%PROJECT_DIR%\tests" %*
exit /b %ERRORLEVEL%
