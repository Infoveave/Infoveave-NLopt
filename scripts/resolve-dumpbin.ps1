[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$command = Get-Command dumpbin.exe -ErrorAction SilentlyContinue
if ($null -ne $command) {
    Write-Output $command.Source
    exit 0
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
if (-not (Test-Path $vswhere -PathType Leaf)) {
    throw 'dumpbin.exe is unavailable and Visual Studio Installer could not be located.'
}

$matches = @(
    & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find 'VC\Tools\MSVC\**\bin\Hostx64\x64\dumpbin.exe'
)
if ($LASTEXITCODE -ne 0 -or $matches.Count -eq 0) {
    throw 'Visual Studio x64 dumpbin.exe could not be located.'
}

Write-Output ($matches | Sort-Object | Select-Object -Last 1)
