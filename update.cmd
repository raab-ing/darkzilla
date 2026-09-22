@echo off
rem darkzilla updater - downloads the newest release and overlays the install.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Update %*
echo.
pause
