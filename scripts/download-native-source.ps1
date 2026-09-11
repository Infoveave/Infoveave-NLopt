[CmdletBinding()]
param(
    [string] $DestinationRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts/native-source'),
    [string] $Archive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path $PSScriptRoot -Parent
$lock = Get-Content (Join-Path $repositoryRoot 'eng/native-source.json') -Raw | ConvertFrom-Json
if (Test-Path $DestinationRoot) {
    throw "Destination already exists: $DestinationRoot"
}

$temporaryArchive = $null
try {
    if ([string]::IsNullOrWhiteSpace($Archive)) {
        $temporaryArchive = [IO.Path]::GetTempFileName()
        Invoke-WebRequest -Uri $lock.archiveUrl -OutFile $temporaryArchive -MaximumRetryCount 5
        $Archive = $temporaryArchive
    }
    elseif (-not (Test-Path $Archive -PathType Leaf)) {
        throw "Source archive not found: $Archive"
    }

    $actualHash = (Get-FileHash $Archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $lock.archiveSha256) {
        throw "SHA-256 mismatch for NLopt source archive. Expected $($lock.archiveSha256), actual $actualHash."
    }

    $entries = & tar -tzf $Archive
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not inspect the NLopt source archive.'
    }
    foreach ($entry in $entries) {
        if ([IO.Path]::IsPathRooted($entry) -or (($entry -split '[/\\]') -contains '..')) {
            throw "Unsafe archive path: $entry"
        }
    }

    New-Item -ItemType Directory -Path $DestinationRoot | Out-Null
    & tar -xzf $Archive -C $DestinationRoot
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not extract the NLopt source archive.'
    }

    $sourceDirectory = Join-Path $DestinationRoot "nlopt-$($lock.nativeVersion)"
    if (-not (Test-Path (Join-Path $sourceDirectory 'CMakeLists.txt') -PathType Leaf) -or
        -not (Test-Path (Join-Path $sourceDirectory 'src/api/nlopt.h') -PathType Leaf)) {
        throw "Pinned NLopt source layout was not found under $sourceDirectory"
    }

    Write-Output $sourceDirectory
}
finally {
    if ($null -ne $temporaryArchive -and (Test-Path $temporaryArchive)) {
        Remove-Item $temporaryArchive -Force
    }
}
