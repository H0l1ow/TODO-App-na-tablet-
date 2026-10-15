@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Build-Win32.ps1" -QtRoot "C:\Qt\5.15.2\mingw81_32" -MingwRoot "C:\Qt\Tools\mingw810_32"
if errorlevel 1 (
    echo Build failed. Check the error messages above.
    pause
    exit /b 1
)
echo Build complete. ZIP in out\DomowyPlan-Win32-x86-v0.4.1.zip
pause
