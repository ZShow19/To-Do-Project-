$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$env:DOTNET_CLI_HOME = Join-Path $root '.dotnet_home'
$env:APPDATA = Join-Path $root '.appdata'
$env:NUGET_PACKAGES = Join-Path $root '.nuget_packages'
& dotnet run --project (Join-Path $root 'backend\Todo.Api\Todo.Api.csproj') --urls http://localhost:5107
