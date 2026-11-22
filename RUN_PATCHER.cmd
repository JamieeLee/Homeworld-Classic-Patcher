@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title Homeworld 1 Classic 2.303 Portable Patcher
echo Homeworld 1 Classic - Steam and GOG
echo We use your current PowerShell execution policy by default.
echo The patcher verifies the exact game build and asks before changing your EXE.
echo.
set "operation="
if not "%~1"=="" goto RUN
echo Select an action:
echo    1. Install Patch
echo    2. Restore Original EXE
echo    3. Exit
choice /C 123 /N /M "Choose [1/2/3]: "
if errorlevel 3 exit /b 0
if errorlevel 2 set "operation=-RestoreOriginal"

:RUN
powershell.exe -NoProfile -File "%~dp0Patch-Homeworld1Classic.ps1" %operation% %*
set "status=%errorlevel%"
if "%status%"=="0" goto END

rem The patcher uses exit 2 for normal patch/validation errors.
rem Exit 1 can indicate Windows prevented PowerShell from launching the script.
if not "%status%"=="1" goto END
echo.
echo The script did not start successfully. If the message above mentions
echo execution policy, Windows may have blocked the PowerShell script.
echo.
echo You can allow a temporary execution-policy override for THIS run only.
echo It will not change your registry or persistent PowerShell settings.
choice /C YN /N /M "Retry with a one-run execution-policy bypass? [Y/N]: "
if errorlevel 2 goto MANUAL
echo.
echo You explicitly approved the temporary process-only override.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Patch-Homeworld1Classic.ps1" %operation% %*
set "status=%errorlevel%"
goto END

:MANUAL
echo.
echo No override was used. To handle execution policy yourself, run:
echo    powershell.exe -NoProfile -Command "Get-ExecutionPolicy -List"
echo You can review or change your own PowerShell settings, or unblock a
echo downloaded script in File Properties, then run this launcher again.

:END
echo.
if not "%status%"=="0" echo Patcher stopped with status %status%. See details above.
pause
exit /b %status%
