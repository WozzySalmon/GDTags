@echo off
setlocal EnableExtensions

for %%I in ("%~dp0..\..") do set "PROJECT_DIR=%%~fI"

where gdlint >nul 2>nul
if errorlevel 1 (
    echo gdlint was not found.
    echo.
    echo Install optional GDScript linting tools with:
    echo   python -m pip install --user gdtoolkit
    exit /b 1
)

pushd "%PROJECT_DIR%" || exit /b 1
gdlint "addons\gameplay_tags" "benchmarks" "tests" %*
set "LINT_EXIT=%ERRORLEVEL%"
popd
exit /b %LINT_EXIT%
