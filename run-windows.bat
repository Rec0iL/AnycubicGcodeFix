@echo off
rem Run Anycubic GcodeFix straight from this folder without installing anything.
rem First start creates a local Python environment (.venv) and downloads PySide6.
rem You can also drag .gcode files onto this file.
setlocal
cd /d "%~dp0"

if exist ".venv\Scripts\pythonw.exe" goto run

echo First start: setting up the Python environment, this takes a minute...
where py >nul 2>&1
if %errorlevel%==0 (py -3 -m venv .venv) else (python -m venv .venv)
if errorlevel 1 goto nopython
".venv\Scripts\python.exe" -m pip install --quiet --upgrade pip
".venv\Scripts\python.exe" -m pip install --quiet "PySide6>=6.6"
if errorlevel 1 goto pipfail

:run
start "" ".venv\Scripts\pythonw.exe" "main.py" %*
exit /b 0

:nopython
echo.
echo Python 3.10 or newer was not found.
echo Install it with:  winget install Python.Python.3.12
echo then run this file again.
pause
exit /b 1

:pipfail
echo.
echo pip could not install PySide6. Check your internet connection and try again.
pause
exit /b 1
