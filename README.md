# Infoveave.NLopt

Safe .NET 10 bindings and separately released, verified runtime bundles for NLopt.

**Repository:** https://github.com/Infoveave/Infoveave-NLopt

- **Managed package:** `Infoveave.NLopt`
- **Initial managed version:** `1.0.0-preview.1`
- **NLopt native version:** `2.11.0`
- **Runtime compatibility:** `1`

The managed package and native engine are versioned independently. The NuGet package never embeds or downloads native files. Executable and test consumers explicitly acquire a matching runtime bundle and pass its extracted `nlopt/` directory through `InfoveaveNLoptRuntimeAssetRoot`. Class-library builds do not require native assets.

## Supported runtimes

| RID | Native file | Build and minimum runtime |
| --- | --- | --- |
| `linux-x64` | `libnlopt.so` | GCC on Ubuntu 22.04; glibc 2.35 floor |
| `win-x64` | `nlopt.dll` | MSVC on Windows Server 2022; x64 Windows 10 / Server 2022 floor |
| `osx-arm64` | `libnlopt.dylib` | Apple Clang on arm64 macOS 15; deployment target macOS 14.0 |

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

## Planned repository layout

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

