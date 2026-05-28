@echo off
setlocal

for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSINSTALL=%%i"

if not defined VSINSTALL (
    echo Could not find Visual Studio C++ tools. Install the Desktop development with C++ workload.
    exit /b 1
)

call "%VSINSTALL%\VC\Auxiliary\Build\vcvars64.bat" || exit /b 1
pushd "%~dp0" || exit /b 1
python -m SCons platform=windows target=template_debug %*
set "BUILD_EXIT=%ERRORLEVEL%"
popd
exit /b %BUILD_EXIT%
