[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidateSet('win-x64')] [string] $RuntimeIdentifier,
    [Parameter(Mandatory)] [string] $SourceDirectory,
    [Parameter(Mandatory)] [string] $OutputRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
    throw 'win-x64 must be built on a Windows x64 host.'
}
if (-not (Test-Path (Join-Path $SourceDirectory 'CMakeLists.txt') -PathType Leaf)) {
    throw "Invalid NLopt source directory: $SourceDirectory"
}
if (Test-Path $OutputRoot) {
    throw "Output root already exists: $OutputRoot"
}

$repositoryRoot = Split-Path $PSScriptRoot -Parent
$buildDirectory = Join-Path $OutputRoot 'build'
$installDirectory = Join-Path $OutputRoot 'install'
$runtimeRoot = Join-Path $OutputRoot 'nlopt'
$configureArguments = @(
    '-S', $SourceDirectory,
    '-B', $buildDirectory,
    '-A', 'x64',
    "-DCMAKE_INSTALL_PREFIX=$installDirectory",
    '-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL',
    '-DBUILD_SHARED_LIBS=ON',
    '-DNLOPT_CXX=OFF',
    '-DNLOPT_LUKSAN=OFF',
    '-DNLOPT_FORTRAN=OFF',
    '-DNLOPT_PYTHON=OFF',
    '-DNLOPT_OCTAVE=OFF',
    '-DNLOPT_MATLAB=OFF',
    '-DNLOPT_GUILE=OFF',
    '-DNLOPT_JAVA=OFF',
    '-DNLOPT_SWIG=OFF',
    '-DNLOPT_TESTS=OFF',
    '-DDISABLE_FP_CONTRACT=ON'
)
& cmake @configureArguments
if ($LASTEXITCODE -ne 0) { throw 'CMake configuration failed.' }
& cmake --build $buildDirectory --config Release --parallel
if ($LASTEXITCODE -ne 0) { throw 'Native build failed.' }
& cmake --install $buildDirectory --config Release
if ($LASTEXITCODE -ne 0) { throw 'Native install failed.' }

$installedNative = Join-Path $installDirectory 'bin/nlopt.dll'
if (-not (Test-Path $installedNative -PathType Leaf)) {
    throw "CMake did not install nlopt.dll at $installedNative"
}
$nativeDirectory = Join-Path $runtimeRoot 'native'
New-Item -ItemType Directory -Path $nativeDirectory -Force | Out-Null
$nativeFile = Join-Path $nativeDirectory 'nlopt.dll'
Copy-Item $installedNative $nativeFile

$noticesFile = Join-Path $runtimeRoot 'THIRD-PARTY-NOTICES.md'
@(
    '# Third-party notices',
    '',
    'This bundle contains NLopt 2.11.0 built without the Luksan and C++ sources.',
    'The following notices are copied verbatim from the pinned NLopt source archive.'
) | Set-Content $noticesFile -Encoding utf8
$notices = [ordered]@{
    'NLopt root COPYING' = 'COPYING'
    'NLopt root COPYRIGHT' = 'COPYRIGHT'
    'BOBYQA COPYRIGHT' = 'src/algs/bobyqa/COPYRIGHT'
    'COBYLA COPYRIGHT' = 'src/algs/cobyla/COPYRIGHT'
    'DIRECT COPYING' = 'src/algs/direct/COPYING'
    'ESCH COPYRIGHT' = 'src/algs/esch/COPYRIGHT'
    'NEWUOA COPYRIGHT' = 'src/algs/newuoa/COPYRIGHT'
    'SLSQP COPYRIGHT' = 'src/algs/slsqp/COPYRIGHT'
}
foreach ($notice in $notices.GetEnumerator()) {
    Add-Content $noticesFile "`n## $($notice.Key)`n`n``````text"
    Add-Content $noticesFile (Get-Content (Join-Path $SourceDirectory $notice.Value) -Raw)
    Add-Content $noticesFile '```'
}

$dumpbin = & (Join-Path $PSScriptRoot 'resolve-dumpbin.ps1')
$dependencyOutput = & $dumpbin /DEPENDENTS $nativeFile 2>&1
if ($LASTEXITCODE -ne 0) { throw 'dumpbin dependency inspection failed.' }
$dependencies = @(
    $dependencyOutput |
        ForEach-Object { $_.ToString().Trim() } |
        Where-Object { $_ -match '^[A-Za-z0-9_.-]+\.dll$' } |
        Sort-Object -Unique
)
if ($dependencies.Count -eq 0) { throw 'No runtime dependencies were discovered for nlopt.dll.' }

$lock = Get-Content (Join-Path $repositoryRoot 'eng/native-source.json') -Raw | ConvertFrom-Json
$cmakeVersion = (& cmake --version | Select-Object -First 1).Trim()
$compilerFile = Get-ChildItem $buildDirectory -Recurse -Filter CMakeCCompiler.cmake | Select-Object -First 1
$compilerVersion = if ($null -ne $compilerFile) {
    $match = Select-String -Path $compilerFile.FullName -Pattern 'set\(CMAKE_C_COMPILER_VERSION "([^"]+)"' | Select-Object -First 1
    if ($null -ne $match) { "MSVC $($match.Matches[0].Groups[1].Value)" } else { 'MSVC (version unavailable)' }
} else { 'MSVC (version unavailable)' }

function New-FileEntry([string] $RelativePath) {
    $fullPath = Join-Path $runtimeRoot $RelativePath
    [ordered]@{
        path = $RelativePath.Replace('\', '/')
        size = (Get-Item $fullPath).Length
        sha256 = (Get-FileHash $fullPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$manifest = [ordered]@{
    schemaVersion = 1
    runtimeCompatibility = 'managed-api-v1'
    nativeVersion = $lock.nativeVersion
    rid = $RuntimeIdentifier
    nativeLibrary = 'native/nlopt.dll'
    source = [ordered]@{
        tag = $lock.tag
        commit = $lock.commit
        archiveUrl = $lock.archiveUrl
        archiveSha256 = $lock.archiveSha256
    }
    toolchain = [ordered]@{
        cmake = $cmakeVersion
        cCompiler = $compilerVersion
        buildHostSystem = 'Windows'
        buildHostArchitecture = 'AMD64'
    }
    buildOptions = [ordered]@{
        BUILD_SHARED_LIBS = 'ON'; CMAKE_BUILD_TYPE = 'Release'; CMAKE_MSVC_RUNTIME_LIBRARY = 'MultiThreadedDLL'
        DISABLE_FP_CONTRACT = 'ON'
        NLOPT_CXX = 'OFF'; NLOPT_LUKSAN = 'OFF'; NLOPT_FORTRAN = 'OFF'; NLOPT_GUILE = 'OFF'
        NLOPT_JAVA = 'OFF'; NLOPT_MATLAB = 'OFF'; NLOPT_OCTAVE = 'OFF'; NLOPT_PYTHON = 'OFF'
        NLOPT_SWIG = 'OFF'; NLOPT_TESTS = 'OFF'
    }
    dependencies = $dependencies
    files = @(
        (New-FileEntry 'THIRD-PARTY-NOTICES.md'),
        (New-FileEntry 'native/nlopt.dll')
    )
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $runtimeRoot 'manifest.json') -Encoding utf8

& (Join-Path $PSScriptRoot 'verify-runtime-bundle.ps1') $runtimeRoot $RuntimeIdentifier '2.11.0' 'managed-api-v1'
Write-Output $runtimeRoot
