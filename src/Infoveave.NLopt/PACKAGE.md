# Infoveave.NLopt

Safe .NET bindings for NLopt with separately released native runtime bundles.

The NuGet package contains managed code only. For an executable or test project, acquire the matching verified runtime ZIP from the corresponding GitHub release, extract it, and set:

```xml
<InfoveaveNLoptRuntimeAssetRoot>/absolute/path/to/nlopt</InfoveaveNLoptRuntimeAssetRoot>
```

The required runtime compatibility is `1`, the native version is `2.11.0`, and the supported RIDs are `linux-x64`, `win-x64`, and `osx-arm64`. The package never downloads a runtime and never searches for a system-installed NLopt library.

Class-library builds do not require runtime assets. Executable, test, and publish builds fail with an actionable message when their bundle is absent. `InfoveaveNLoptRuntimeAssetSkip=true` is available only for deliberate compile-only operations.
