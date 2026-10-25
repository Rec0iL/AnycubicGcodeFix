@echo off
rem Double-click to install Anycubic GcodeFix for the current user (no admin rights needed).
rem Options are passed through, e.g.  install-windows.bat -Desktop
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-windows.ps1" %*
echo.
pause
