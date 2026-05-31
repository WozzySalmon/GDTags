@echo off
setlocal EnableExtensions EnableDelayedExpansion

if /I "%~1"=="help" goto :usage
if /I "%~1"=="--help" goto :usage
if /I "%~1"=="/?" goto :usage

set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

set "TARGET_ARG="
set "PLATFORM_ARG="
set "JOBS_ARG="
set "EXTRA_ARGS="

for %%A in (%*) do (
    set "ARG=%%~A"
    if /I "!ARG:~0,7!"=="target=" (
        set "TARGET_ARG=!ARG!"
    ) else if /I "!ARG:~0,9!"=="platform=" (
        set "PLATFORM_ARG=!ARG!"
    ) else if /I "!ARG:~0,2!"=="-j" (
        set "JOBS_ARG=!ARG!"
    ) else (
        set "EXTRA_ARGS=!EXTRA_ARGS! !ARG!"
    )
)

if not defined TARGET_ARG set "TARGET_ARG=target=template_debug"
if not defined PLATFORM_ARG set "PLATFORM_ARG=platform=windows"
if not defined NUMBER_OF_PROCESSORS set "NUMBER_OF_PROCESSORS=1"
if not defined JOBS_ARG set "JOBS_ARG=-j%NUMBER_OF_PROCESSORS%"

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE%" goto :find_vs
echo Could not find vswhere.exe at:
echo   %VSWHERE%
echo Install Visual Studio with the "Desktop development with C++" workload.
exit /b 1

:find_vs
for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSINSTALL=%%i"

if not defined VSINSTALL (
    echo Could not find Visual Studio C++ tools.
    echo Install Visual Studio with the "Desktop development with C++" workload.
    exit /b 1
)

call "%VSINSTALL%\VC\Auxiliary\Build\vcvars64.bat" || exit /b 1
pushd "%PROJECT_DIR%" || exit /b 1

echo.
echo Building Gameplay Tags native extension
echo   %PLATFORM_ARG% %TARGET_ARG% %JOBS_ARG%%EXTRA_ARGS%
echo.

python -m SCons %PLATFORM_ARG% %TARGET_ARG% %JOBS_ARG%%EXTRA_ARGS%
set "BUILD_EXIT=%ERRORLEVEL%"
popd
exit /b %BUILD_EXIT%

:usage
echo Build the Gameplay Tags Godot GDExtension on Windows.
echo.
echo Usage:
echo   build_native_windows.cmd [SCons args]
echo.
echo Defaults:
echo   platform=windows target=template_debug -j%%NUMBER_OF_PROCESSORS%%
echo.
echo Examples:
echo   build_native_windows.cmd
echo   build_native_windows.cmd target=template_release
echo   build_native_windows.cmd -c
echo   build_native_windows.cmd -j1 verbose=yes
exit /b 0
