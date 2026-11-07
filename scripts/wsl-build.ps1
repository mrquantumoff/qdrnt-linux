# Build the qdrnt ISO in the CachyOS WSL distro. Extra args go to buildiso.sh.
#   .\scripts\wsl-build.ps1          # build
#   .\scripts\wsl-build.ps1 -v       # verbose mkarchiso
param(
    [string]$Distro = "cachyos",
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$BuildArgs
)
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot

wsl.exe -d $Distro -u root --cd $repo -e bash scripts/wsl-build.sh @BuildArgs
if ($LASTEXITCODE -ne 0) { throw "ISO build failed (exit $LASTEXITCODE)" }
Write-Host "ISO written to $repo\out"
