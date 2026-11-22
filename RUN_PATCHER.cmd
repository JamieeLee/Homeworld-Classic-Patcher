@echo off
setlocal
cd /d "%~dp0"
title Homeworld 1 Classic 2.303 Portable Patcher
echo This is a readable, offline PowerShell patch kit. No third-party installer.
echo It verifies the stock Homeworld.exe and backs it up before modification.
echo.
echo PowerShell execution-policy bypass applies ONLY to this process.
echo It does NOT change your Windows security settings permanently.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Patch-Homeworld1Classic.ps1" %*
set "status=%errorlevel%"
echo.
if not "%status%"=="0" echo Patcher stopped. See the message above.
pause
exit /b %status%
