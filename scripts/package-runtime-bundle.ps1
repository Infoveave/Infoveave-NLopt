[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidateSet('win-x64')] [string] $RuntimeIdentifier,
    [string] $RuntimeRoot,
    [string] $OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path $PSScriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($RuntimeRoot)) {
    $RuntimeRoot = Join-Path $repositoryRoot "artifacts/runtime-bundles/$RuntimeIdentifier/nlopt"
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repositoryRoot 'artifacts/runtime-releases'
}
$manifestPath = Join-Path $RuntimeRoot 'manifest.json'
if (-not (Test-Path $manifestPath -PathType Leaf)) { throw "Runtime manifest not found: $manifestPath" }
$nativeVersion = '2.11.0'
$runtimeCompatibility = 'managed-api-v1'
$verifyArguments = @($RuntimeRoot, $RuntimeIdentifier, $nativeVersion, $runtimeCompatibility)
& (Join-Path $PSScriptRoot 'verify-runtime-bundle.ps1') @verifyArguments

$archiveName = "infoveave-nlopt-runtime-1-nlopt-$nativeVersion-$RuntimeIdentifier.zip"
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$archivePath = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) $archiveName
if ((Test-Path $archivePath) -or (Test-Path "$archivePath.sha256") -or (Test-Path "$archivePath.THIRD-PARTY-NOTICES.md")) {
    throw "Release archive already exists: $archivePath"
}

Compress-Archive -Path $RuntimeRoot -DestinationPath $archivePath -CompressionLevel Optimal
$archiveHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
"$archiveHash  $archiveName" | Set-Content "$archivePath.sha256" -Encoding ascii
Copy-Item (Join-Path $RuntimeRoot 'THIRD-PARTY-NOTICES.md') "$archivePath.THIRD-PARTY-NOTICES.md"
Write-Output $archivePath
