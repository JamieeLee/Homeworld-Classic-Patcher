@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title Homeworld 1 Classic 2.303 Portable Patcher
echo Homeworld 1 Classic Patcher - build 2.303
echo.
set "operation="
if not "%~1"=="" goto RUN
echo Select an action:
echo    1. Install Patch
echo    2. Restore Original EXE
echo    3. Clean Up Backups
echo    4. Exit
choice /C 1234 /N /M "Choose [1/2/3/4]: "
if errorlevel 4 exit /b 0
if errorlevel 3 goto CHOOSE_CLEAN
if errorlevel 2 goto CHOOSE_RESTORE
goto RUN

:CHOOSE_CLEAN
set "operation=-CleanBackups"
goto RUN

:CHOOSE_RESTORE
set "operation=-RestoreOriginal"

:RUN
powershell.exe -NoProfile -File "%~dp0Patch-Homeworld1Classic.ps1" %operation% %*
set "status=%errorlevel%"
if "%status%"=="0" goto END

rem The patcher uses exit 2 for normal patch/validation errors.
rem Exit 1 can indicate Windows prevented PowerShell from launching the script.
if not "%status%"=="1" goto END
echo.
echo PowerShell could not start the patcher.
echo If the error above mentions execution policy, you may allow a
echo temporary override for this run only. No system settings change.
choice /C YN /N /M "Retry with a temporary override? [Y/N]: "
if errorlevel 2 goto MANUAL
echo.
echo Retrying with the temporary override you approved.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Patch-Homeworld1Classic.ps1" %operation% %*
set "status=%errorlevel%"
goto END

:MANUAL
echo.
echo No override used. To review your PowerShell policy, run:
echo    powershell.exe -NoProfile -Command "Get-ExecutionPolicy -List"
echo Review your policy or unblock the downloaded script before retrying.

:END
echo.
if not "%status%"=="0" echo Patcher stopped with status %status%. See details above.
pause
exit /b %status%
