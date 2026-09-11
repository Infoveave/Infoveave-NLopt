# Infoveave.NLopt

Safe .NET 10 bindings and separately released, verified runtime bundles for NLopt.

**Repository:** https://github.com/Infoveave/Infoveave-NLopt

- **Managed package:** `Infoveave.NLopt`
- **Managed version:** `2.11.0` (aligned with the pinned NLopt native version)
- **NLopt native version:** `2.11.0`
- **Runtime compatibility:** `1`

The managed package and native engine are versioned independently. The NuGet package never embeds or downloads native files. Executable and test consumers explicitly acquire a matching runtime bundle and pass its extracted `nlopt/` directory through `InfoveaveNLoptRuntimeAssetRoot`. Class-library builds do not require native assets.

## Supported runtimes

| RID | Native file | Build and minimum runtime |
| --- | --- | --- |
| `linux-x64` | `libnlopt.so` | GCC 11 on Ubuntu 22.04; glibc 2.35 floor |
| `win-x64` | `nlopt.dll` | MSVC and execution on Windows Server 2022; Windows Server 2022 floor |
| `osx-arm64` | `libnlopt.dylib` | Apple Clang and execution on arm64 macOS 15; deployment target macOS 15.0 |

Every supported file is built and run on its declared architecture. Additional RIDs require their own build, dependency inspection, and runtime evidence.

## Native source and license

`eng/native-source.json` pins NLopt `v2.11.0` by commit, HTTPS archive, and SHA-256. Builds use a shared release library with:

```text
BUILD_SHARED_LIBS=ON
NLOPT_CXX=OFF
NLOPT_LUKSAN=OFF
NLOPT_FORTRAN=OFF
NLOPT_PYTHON=OFF
NLOPT_OCTAVE=OFF
NLOPT_MATLAB=OFF
NLOPT_GUILE=OFF
NLOPT_JAVA=OFF
NLOPT_SWIG=OFF
NLOPT_TESTS=OFF
DISABLE_FP_CONTRACT=ON
```

NLopt documents the build without its Luksan sources as MIT-licensed. C++-only algorithms are also excluded because the What-If consumer requires the C COBYLA implementation and does not need a C++ runtime dependency.

NLoptNet is pinned as an API/test reference only. Its source and bundled NLopt 2.6.1 binaries are not copied.

## Package boundary

The package exposes generic optimizer construction, bounds, objective and inequality callbacks, stopping criteria, initial step, optimization, requested force-stop, raw result codes, native version, and deterministic disposal. It contains no Infoveave formula syntax, row data, weights, scenarios, or business diagnostics.

NLopt inequalities use `g(x) <= 0`. A positive native result is a termination reason, not proof that an application target was achieved.

## Consumer setup

Configure `https://nuget.pkg.github.com/Infoveave/index.json` as an authenticated NuGet source, then reference the managed package:

```xml
<PackageReference Include="Infoveave.NLopt" Version="2.11.0" />
```

Download the runtime ZIP for the application's RID from the matching GitHub release and verify it using the published SHA-256. The acquisition script requires that expected hash as caller input; it never trusts a checksum downloaded implicitly:

```bash
bash scripts/acquire-runtime-bundle.sh \
  --release-tag v2.11.0 \
  osx-arm64 \
  <64-character-published-sha256> \
  /absolute/path/to/runtime
```

Point the executable or test project at the extracted directory:

```xml
<PropertyGroup>
  <InfoveaveNLoptRuntimeAssetRoot>/absolute/path/to/runtime/nlopt</InfoveaveNLoptRuntimeAssetRoot>
  <InfoveaveNLoptRuntimeIdentifier>osx-arm64</InfoveaveNLoptRuntimeIdentifier>
</PropertyGroup>
```

The RID property is optional when the build host matches the target. Build and publish copy the complete verified bundle to `nlopt/` beside the application. A class library can restore and build without the runtime. `InfoveaveNLoptRuntimeAssetSkip=true` permits an intentional compile-only executable build, but the resulting program cannot use NLopt until a verified `nlopt/` directory is materialized.

The managed loader accepts only runtime compatibility `1`, NLopt `2.11.0`, the current process RID, the pinned source provenance, and the native file hash recorded in the manifest. It loads that exact file by absolute path and never searches system library locations.

## Build native bundles locally

Unix hosts build only their native target:

```bash
source_directory="$(bash scripts/download-native-source.sh artifacts/native-source)"
bash scripts/build-native.sh osx-arm64 "$source_directory" artifacts/runtime-bundles/osx-arm64
bash scripts/package-runtime-bundle.sh osx-arm64
```

Windows x64 uses PowerShell:

```powershell
$sourceDirectory = ./scripts/download-native-source.ps1 -DestinationRoot artifacts/native-source
./scripts/build-native.ps1 -RuntimeIdentifier win-x64 -SourceDirectory $sourceDirectory -OutputRoot artifacts/runtime-bundles/win-x64
./scripts/package-runtime-bundle.ps1 -RuntimeIdentifier win-x64
```

CI pins CMake `4.4.3`, GCC `11` for Linux, and fixed runner generations for MSVC and Apple Clang. Every manifest records the exact compiler, CMake, host, dependency, and build-option values that produced its binary.

## Repository layout

```text
src/Infoveave.NLopt/              managed wrapper and buildTransitive target
tests/Infoveave.NLopt.Tests/      managed and real-native tests
tests/consumers/                  clean direct and transitive consumers
eng/                              immutable source and release locks
scripts/                          explicit acquire/build/verify/package commands
runtime/                          third-party notices
.github/workflows/                platform CI, publish, and qualification
evidence/                         WIF task evidence
```

## Build and release contract

CI uses xUnit v3 on Microsoft Testing Platform consistently. It restores and builds with warnings as errors, builds NLopt on each actual target runner, executes real-native tests, verifies package and bundle contents, and retains evidence.

Tag `v<managed-package-version>` publishes the managed package to the Infoveave GitHub Packages NuGet feed and attaches all verified runtime ZIP/checksum pairs to the matching GitHub release. A manual validation run retains artifacts but does not claim a stable release. Published bytes are immutable; an existing version with a different hash is rejected.

Credentials come only from scoped GitHub Actions tokens and consumer NuGet configuration. Secrets are never written into repository files, packages, manifests, logs, or evidence.

Managed package versions mirror the pinned NLopt native version. Stable tags use `v<native-version>` and publish only after every platform qualification job in the same workflow succeeds and release execution has been explicitly authorized. A future managed-only compatibility change would add a fourth version component rather than pretending to track a different native release.

For cross-repository GitHub Actions consumption, grant the consuming repository access to the package in GitHub Packages and pass a token with `read:packages` through the consumer repository's NuGet configuration. Use the workflow actor as the NuGet username and keep the token in Actions secrets; do not commit it to `NuGet.config`.

## Upgrade and rollback

Treat the managed package version and runtime compatibility/native version as one qualified deployment choice even though they are released independently. To upgrade, select a complete release, update the `PackageReference`, acquire that release's RID-specific ZIP using its published checksum, and run the application's smoke tests before deployment.

To roll back, restore both the previous managed package version and its previously verified runtime directory. Do not mix a newer package with an older incompatible manifest, replace files inside a published bundle, or reuse a checksum from another RID.
