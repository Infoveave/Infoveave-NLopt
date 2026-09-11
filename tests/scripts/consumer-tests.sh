#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
runtime_root="${NLOPT_TEST_RUNTIME_ROOT:?Set NLOPT_TEST_RUNTIME_ROOT to an extracted, verified nlopt directory}"
runtime_identifier="${NLOPT_TEST_RID:-osx-arm64}"
if command -v cygpath >/dev/null 2>&1; then
  runtime_root="$(cygpath -u "$runtime_root")"
fi
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT
package_directory="$temporary_directory/packages"
package_cache="$temporary_directory/package-cache"
consumer_root="$temporary_directory/consumers"

dotnet pack "$repository_root/src/Infoveave.NLopt/Infoveave.NLopt.csproj" -c Release -o "$package_directory"
cp -R "$repository_root/tests/consumers" "$consumer_root"
common_properties=("-p:RestoreSources=$package_directory" "-p:RestorePackagesPath=$package_cache")
if [ "$runtime_identifier" = 'linux-x64' ]; then
  wrong_runtime_identifier='osx-arm64'
else
  wrong_runtime_identifier='linux-x64'
fi

dotnet pack "$consumer_root/TransitiveLibrary/TransitiveLibrary.csproj" -c Release -o "$package_directory" \
  "${common_properties[@]}"

dotnet build "$consumer_root/ClassLibrary/ClassLibrary.csproj" -c Release "${common_properties[@]}"

if dotnet build "$consumer_root/Direct/Direct.csproj" -c Release "${common_properties[@]}" \
  >"$temporary_directory/absent.stdout" 2>"$temporary_directory/absent.stderr"; then
  echo "expected executable build without a runtime bundle to fail" >&2
  exit 1
fi
grep -q 'runtime assets are required' "$temporary_directory/absent.stdout" "$temporary_directory/absent.stderr"

skip_output="$temporary_directory/skip-output/"
dotnet build "$consumer_root/Direct/Direct.csproj" -c Release "${common_properties[@]}" \
  "-p:BaseOutputPath=$skip_output" -p:InfoveaveNLoptRuntimeAssetSkip=true
if dotnet "$skip_output/Release/net10.0/Direct.dll" \
  >"$temporary_directory/no-fallback.stdout" 2>"$temporary_directory/no-fallback.stderr"; then
  echo "expected a compile-only executable without a bundle to fail at runtime" >&2
  exit 1
fi
grep -q 'verified NLopt runtime manifest was not found' \
  "$temporary_directory/no-fallback.stdout" "$temporary_directory/no-fallback.stderr"

if dotnet build "$consumer_root/Direct/Direct.csproj" -c Release "${common_properties[@]}" \
  "-p:InfoveaveNLoptRuntimeAssetRoot=$runtime_root" \
  "-p:InfoveaveNLoptRuntimeIdentifier=$wrong_runtime_identifier" \
  >"$temporary_directory/wrong-rid.stdout" 2>"$temporary_directory/wrong-rid.stderr"; then
  echo "expected a mismatched RID bundle to fail" >&2
  exit 1
fi
grep -q 'native library not found' "$temporary_directory/wrong-rid.stdout" "$temporary_directory/wrong-rid.stderr"

dotnet run --project "$consumer_root/Direct/Direct.csproj" -c Release "${common_properties[@]}" \
  "-p:InfoveaveNLoptRuntimeAssetRoot=$runtime_root" "-p:InfoveaveNLoptRuntimeIdentifier=$runtime_identifier"

publish_directory="$temporary_directory/publish"
dotnet publish "$consumer_root/Direct/Direct.csproj" -c Release -o "$publish_directory" \
  "${common_properties[@]}" "-p:InfoveaveNLoptRuntimeAssetRoot=$runtime_root" \
  "-p:InfoveaveNLoptRuntimeIdentifier=$runtime_identifier"
test -s "$publish_directory/nlopt/manifest.json"
test -s "$publish_directory/nlopt/native/libnlopt.dylib" || \
  test -s "$publish_directory/nlopt/native/libnlopt.so" || \
  test -s "$publish_directory/nlopt/native/nlopt.dll"

dotnet run --project "$consumer_root/TransitiveApp/TransitiveApp.csproj" -c Release \
  "${common_properties[@]}" "-p:InfoveaveNLoptRuntimeAssetRoot=$runtime_root" \
  "-p:InfoveaveNLoptRuntimeIdentifier=$runtime_identifier"

corrupted_root="$temporary_directory/corrupted/nlopt"
mkdir -p "$(dirname "$corrupted_root")"
cp -R "$runtime_root" "$corrupted_root"
case "$runtime_identifier" in
  linux-x64) corrupted_native="$corrupted_root/native/libnlopt.so" ;;
  win-x64) corrupted_native="$corrupted_root/native/nlopt.dll" ;;
  osx-arm64) corrupted_native="$corrupted_root/native/libnlopt.dylib" ;;
  *) echo "unsupported test RID: $runtime_identifier" >&2; exit 1 ;;
esac
printf 'corrupted' >> "$corrupted_native"
if dotnet run --project "$consumer_root/Direct/Direct.csproj" -c Release \
  "${common_properties[@]}" "-p:BaseOutputPath=$temporary_directory/corrupted-output/" \
  "-p:InfoveaveNLoptRuntimeAssetRoot=$corrupted_root" "-p:InfoveaveNLoptRuntimeIdentifier=$runtime_identifier" \
  >"$temporary_directory/corrupted.stdout" 2>"$temporary_directory/corrupted.stderr"; then
  echo "expected a corrupted native library to fail at load" >&2
  exit 1
fi
grep -q 'native library SHA-256' "$temporary_directory/corrupted.stdout" "$temporary_directory/corrupted.stderr"

echo "consumer-tests: PASS"
