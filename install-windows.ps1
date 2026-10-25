<#
.SYNOPSIS
  Installs Anycubic GcodeFix for the current user (no admin rights needed).

.DESCRIPTION
  - finds Python 3.10+ (install one with:  winget install Python.Python.3.12)
  - copies the app to %LOCALAPPDATA%\AnycubicGcodeFix\app and creates a Python environment next to it
  - installs PySide6 with pip (a few hundred MB, one time)
  - adds a Start menu shortcut and a right-click "Send to > Anycubic GcodeFix" entry

.PARAMETER Desktop   also put a shortcut on the Desktop
.PARAMETER NoSendTo  do not add the "Send to" entry
.PARAMETER Link      run straight from this folder instead of copying (for development)
.PARAMETER NoPip     skip the pip download (offline packaging / tests)
#>
param(
    [switch]$Desktop,
    [switch]$NoSendTo,
    [switch]$Link,
    [switch]$NoPip
)

$ErrorActionPreference = 'Stop'
$src = Split-Path -Parent $MyInvocation.MyCommand.Path

function Say($msg)  { Write-Host "==> $msg" -ForegroundColor Magenta }
function Warn($msg) { Write-Host "!!  $msg" -ForegroundColor Yellow }
function Die($msg)  { Write-Host "xx  $msg" -ForegroundColor Red; exit 1 }

if (-not (Test-Path (Join-Path $src 'shaders\bg.frag.qsb'))) { Die 'shaders\bg.frag.qsb is missing - is this the full download?' }

# ---------------------------------------------------------------- python 3.10+
function Find-Python {
    $candidates = @(
        @{ Exe = 'py';      Args = @('-3.13') },
        @{ Exe = 'py';      Args = @('-3.12') },
        @{ Exe = 'py';      Args = @('-3.11') },
        @{ Exe = 'py';      Args = @('-3.10') },
        @{ Exe = 'py';      Args = @('-3') },
        @{ Exe = 'python';  Args = @() },
        @{ Exe = 'python3'; Args = @() }
    )
    foreach ($c in $candidates) {
        if (-not (Get-Command $c.Exe -ErrorAction SilentlyContinue)) { continue }
        try {
            $exe = $c.Exe; $pre = $c.Args
            $ok = & $exe @pre -c "import sys; print(int(sys.version_info >= (3, 10)))" 2>$null
            if ($LASTEXITCODE -eq 0 -and "$ok".Trim() -eq '1') {
                $path = & $exe @pre -c "import sys; print(sys.executable)" 2>$null
                if ($LASTEXITCODE -eq 0 -and $path) { return "$path".Trim() }
            }
        } catch { }   # e.g. the Microsoft Store "python" stub - ignore and try the next one
    }
    return $null
}

$python = Find-Python
if (-not $python) {
    Warn 'Python 3.10 or newer was not found.'
    Warn '  Install it with:  winget install Python.Python.3.12'
    Warn '  or download it from https://www.python.org/downloads/  (tick "Add python.exe to PATH")'
    Die 'Install Python, then run this installer again.'
}
Say "Using $python"

# ---------------------------------------------------------------- folders
$root   = Join-Path $env:LOCALAPPDATA 'AnycubicGcodeFix'
$venv   = Join-Path $root 'venv'
$appDir = if ($Link) { $src } else { Join-Path $root 'app' }
$venvPy = Join-Path $venv 'Scripts\python.exe'
$venvPyw = Join-Path $venv 'Scripts\pythonw.exe'

try {
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    if (Test-Path $venv) { Remove-Item $venv -Recurse -Force }
    if ((-not $Link) -and (Test-Path $appDir)) { Remove-Item $appDir -Recurse -Force }
} catch {
    Die "Could not replace the old install - close Anycubic GcodeFix if it is running, then try again. ($($_.Exception.Message))"
}

# ---------------------------------------------------------------- python environment
Say 'Creating Python environment'
& $python -m venv $venv
if ($LASTEXITCODE -ne 0) { Die 'Could not create a virtual environment.' }
if (-not $NoPip) {
    Say 'Installing PySide6 with pip (a few hundred MB, one time)...'
    & $venvPy -m pip install --quiet --upgrade pip
    & $venvPy -m pip install --quiet "PySide6>=6.6"
    if ($LASTEXITCODE -ne 0) { Die 'pip could not install PySide6 (offline? unsupported Python version?).' }
}

# ---------------------------------------------------------------- app files
if (-not $Link) {
    Say "Installing app files to $appDir"
    New-Item -ItemType Directory -Force -Path (Join-Path $appDir 'shaders'), (Join-Path $appDir 'packaging') | Out-Null
    Copy-Item (Join-Path $src 'gcodefix') $appDir -Recurse -Force
    Copy-Item (Join-Path $src 'qml') $appDir -Recurse -Force
    Copy-Item (Join-Path $src 'main.py') $appDir -Force
    Copy-Item (Join-Path $src 'packaging\anycubic-gcodefix.ico'), (Join-Path $src 'packaging\anycubic-gcodefix.svg') (Join-Path $appDir 'packaging') -Force
    Copy-Item (Join-Path $src 'shaders\bg.frag'), (Join-Path $src 'shaders\bg.frag.qsb') (Join-Path $appDir 'shaders') -Force
    Get-ChildItem $appDir -Recurse -Directory -Filter '__pycache__' | Remove-Item -Recurse -Force
}

# ---------------------------------------------------------------- shortcuts
function New-AppShortcut($lnkPath) {
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($lnkPath)
    $lnk.TargetPath       = $venvPyw                                  # pythonw = no console window
    $lnk.Arguments        = '"' + (Join-Path $appDir 'main.py') + '"'
    $lnk.WorkingDirectory = $appDir
    $lnk.IconLocation     = (Join-Path $appDir 'packaging\anycubic-gcodefix.ico')
    $lnk.Description      = 'Make any G-code printable on your Anycubic printer'
    $lnk.Save()
}

$start = Join-Path ([Environment]::GetFolderPath('Programs')) 'Anycubic GcodeFix.lnk'
Say "Creating Start menu shortcut"
New-AppShortcut $start

if (-not $NoSendTo) {
    Say 'Adding right-click "Send to > Anycubic GcodeFix"'
    New-AppShortcut (Join-Path ([Environment]::GetFolderPath('SendTo')) 'Anycubic GcodeFix.lnk')
}
if ($Desktop) {
    New-AppShortcut (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Anycubic GcodeFix.lnk')
}

# ---------------------------------------------------------------- sanity check
& $venvPy -c "import PySide6.QtQuick, PySide6.QtQuickControls2" 2>$null
if ($LASTEXITCODE -ne 0 -and -not $NoPip) {
    Warn 'PySide6 is installed but Qt Quick failed to load.'
    Warn 'Install the "Microsoft Visual C++ Redistributable" (winget install Microsoft.VCRedist.2015+.x64) and try again.'
}

Say 'Done! Open "Anycubic GcodeFix" from the Start menu, then drop .gcode files onto the window.'
Say 'Or right-click a .gcode file > Send to > Anycubic GcodeFix.'
