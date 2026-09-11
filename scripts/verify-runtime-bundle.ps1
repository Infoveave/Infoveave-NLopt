[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $RuntimeRoot,
    [Parameter(Mandatory)] [string] $ExpectedRuntimeIdentifier,
    [Parameter(Mandatory)] [string] $ExpectedNativeVersion,
    [Parameter(Mandatory)] [string] $ExpectedRuntimeCompatibility
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expectedSourceCommit = '88c424d4f458412787df96fcc95218acbca224fd'
$expectedArchiveHash = '53e552d83e9294d67db37f0f4a23f15933a9ef698485301a18b98b40004cf0de'
$manifestPath = Join-Path $RuntimeRoot 'manifest.json'
if (-not (Test-Path $manifestPath -PathType Leaf)) { throw "Bundle manifest not found: $manifestPath" }
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

if ($manifest.schemaVersion -ne 1) { throw 'Unsupported manifest schema.' }
if ($manifest.rid -ne $ExpectedRuntimeIdentifier) { throw 'Runtime identifier does not match.' }
if ($manifest.nativeVersion -ne $ExpectedNativeVersion) { throw 'Native version does not match.' }
if ($manifest.runtimeCompatibility -ne $ExpectedRuntimeCompatibility) { throw 'Runtime compatibility does not match.' }
if ($manifest.source.commit -ne $expectedSourceCommit) { throw 'Source commit does not match.' }
if ($manifest.source.archiveSha256 -ne $expectedArchiveHash) { throw 'Source archive hash does not match.' }
if ($ExpectedRuntimeIdentifier -ne 'win-x64' -or $manifest.nativeLibrary -ne 'native/nlopt.dll') {
    throw 'Native library path does not match win-x64.'
}
if (@($manifest.dependencies).Count -eq 0) { throw 'Runtime dependencies are missing.' }

$rootPath = [IO.Path]::GetFullPath($RuntimeRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$expectedFiles = @('THIRD-PARTY-NOTICES.md', 'native/nlopt.dll')
$manifestFiles = @($manifest.files)
if ($manifestFiles.Count -ne $expectedFiles.Count) { throw 'Bundle file inventory is incomplete.' }
foreach ($entry in $manifestFiles) {
    $relativePath = [string]$entry.path
    if ([IO.Path]::IsPathRooted($relativePath) -or (($relativePath -split '[/\\]') -contains '..')) {
        throw "Unsafe manifest path: $relativePath"
    }
    if ($relativePath -notin $expectedFiles) { throw "Unexpected bundle file: $relativePath" }
    $fullPath = [IO.Path]::GetFullPath((Join-Path $RuntimeRoot ($relativePath -replace '/', [IO.Path]::DirectorySeparatorChar)))
    if (-not $fullPath.StartsWith($rootPath, [StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes runtime root: $relativePath" }
    if (-not (Test-Path $fullPath -PathType Leaf)) { throw "Bundle file is missing: $relativePath" }
    if ((Get-Item $fullPath).LinkType) { throw "Bundle file must not be a symbolic link: $relativePath" }
    if ((Get-Item $fullPath).Length -ne [long]$entry.size) { throw "Size mismatch: $relativePath" }
    $actualHash = (Get-FileHash $fullPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $entry.sha256) { throw "SHA-256 mismatch: $relativePath" }
}

$diskFiles = @(
    Get-ChildItem $RuntimeRoot -File -Recurse |
        Where-Object { $_.FullName -ne [IO.Path]::GetFullPath($manifestPath) } |
        ForEach-Object { [IO.Path]::GetRelativePath($RuntimeRoot, $_.FullName).Replace('\', '/') } |
        Sort-Object
)
if (($diskFiles -join '|') -ne (($expectedFiles | Sort-Object) -join '|')) { throw 'Bundle contains unmanifested files.' }

$nativePath = Join-Path $RuntimeRoot 'native/nlopt.dll'
$stream = [IO.File]::OpenRead($nativePath)
try {
    $reader = [IO.BinaryReader]::new($stream)
    if ($reader.ReadUInt16() -ne 0x5A4D) { throw 'Native library is not a PE file.' }
    $stream.Position = 0x3C
    $peOffset = $reader.ReadInt32()
    $stream.Position = $peOffset
    if ($reader.ReadUInt32() -ne 0x00004550) { throw 'Native library has no PE signature.' }
    if ($reader.ReadUInt16() -ne 0x8664) { throw 'Native library is not x64.' }
}
finally {
    $stream.Dispose()
}

Write-Output "verified runtime bundle: $RuntimeRoot"
