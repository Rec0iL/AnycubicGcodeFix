@echo off
rem Double-click to uninstall.  Add -Purge to also delete settings and history.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall-windows.ps1" %*
echo.
pause
