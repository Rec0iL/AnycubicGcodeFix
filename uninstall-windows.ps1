<#
.SYNOPSIS
  Removes Anycubic GcodeFix (app, Python environment and shortcuts).
.PARAMETER Purge  also delete settings and history (%APPDATA%\AnycubicGcodeFix)
#>
param([switch]$Purge)

$ErrorActionPreference = 'Stop'
$root = Join-Path $env:LOCALAPPDATA 'AnycubicGcodeFix'

foreach ($folder in 'Programs', 'SendTo', 'Desktop') {
    $lnk = Join-Path ([Environment]::GetFolderPath($folder)) 'Anycubic GcodeFix.lnk'
    if (Test-Path $lnk) { Remove-Item $lnk -Force }
}
try {
    if (Test-Path $root) { Remove-Item $root -Recurse -Force }
} catch {
    Write-Host "xx  Could not remove $root - close Anycubic GcodeFix and try again. ($($_.Exception.Message))" -ForegroundColor Red
    exit 1
}
if ($Purge) {
    $cfg = Join-Path $env:APPDATA 'AnycubicGcodeFix'
    if (Test-Path $cfg) { Remove-Item $cfg -Recurse -Force }
    Write-Host 'Settings and history removed.'
}
Write-Host 'Anycubic GcodeFix uninstalled.'
