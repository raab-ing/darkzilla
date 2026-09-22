@echo off
rem darkzilla installer - double-clickable wrapper.
rem .cmd files are not subject to the PowerShell execution policy, so this
rem works even where install.ps1 is blocked as unsigned.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
echo.
pause
