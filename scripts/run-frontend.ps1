$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$env:APPDATA = Join-Path $root '.appdata'
$flutter = Join-Path $root 'flutter\bin\flutter.bat'
Push-Location (Join-Path $root 'frontend')
try { & $flutter pub get; & $flutter run -d windows } finally { Pop-Location }
