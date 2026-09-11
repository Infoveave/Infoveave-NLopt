#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
runtime_root="${NLOPT_TEST_RUNTIME_ROOT:?NLOPT_TEST_RUNTIME_ROOT is required}"
runtime_identifier="${NLOPT_TEST_RID:?NLOPT_TEST_RID is required}"
package_source="${NLOPT_TEST_MANAGED_PACKAGE_SOURCE:?NLOPT_TEST_MANAGED_PACKAGE_SOURCE is required}"
if command -v cygpath >/dev/null 2>&1; then
  runtime_root="$(cygpath -u "$runtime_root")"
fi

temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT
consumer_root="$temporary_directory/consumers"
package_directory="$temporary_directory/packages"
package_cache="$temporary_directory/package-cache"
cp -R "$repository_root/tests/consumers" "$consumer_root"
mkdir -p "$package_directory" "$package_cache"
if command -v cygpath >/dev/null 2>&1; then
  runtime_root="$(cygpath -m "$runtime_root")"
  consumer_root="$(cygpath -m "$consumer_root")"
  package_directory="$(cygpath -m "$package_directory")"
  package_cache="$(cygpath -m "$package_cache")"
  export MSYS2_ARG_CONV_EXCL='*'
fi
feed_properties=("-p:RestoreSources=$package_source" "-p:RestorePackagesPath=$package_cache")

dotnet restore "$consumer_root/ClassLibrary/ClassLibrary.csproj" "${feed_properties[@]}"
dotnet restore "$consumer_root/Direct/Direct.csproj" "${feed_properties[@]}"
dotnet restore "$consumer_root/TransitiveLibrary/TransitiveLibrary.csproj" "${feed_properties[@]}"
dotnet pack "$consumer_root/TransitiveLibrary/TransitiveLibrary.csproj" --no-restore -c Release -o "$package_directory"
dotnet restore "$consumer_root/TransitiveApp/TransitiveApp.csproj" \
  "-p:RestoreSources=$package_directory;$package_source" "-p:RestorePackagesPath=$package_cache"

offline_environment=(
  'http_proxy=http://127.0.0.1:9'
  'https_proxy=http://127.0.0.1:9'
  'HTTP_PROXY=http://127.0.0.1:9'
  'HTTPS_PROXY=http://127.0.0.1:9'
  'NO_PROXY='
)
runtime_properties=(
  "-p:InfoveaveNLoptRuntimeAssetRoot=$runtime_root"
  "-p:InfoveaveNLoptRuntimeIdentifier=$runtime_identifier"
)

env "${offline_environment[@]}" dotnet build "$consumer_root/ClassLibrary/ClassLibrary.csproj" --no-restore -c Release
env "${offline_environment[@]}" dotnet build "$consumer_root/Direct/Direct.csproj" --no-restore -c Release \
  "${runtime_properties[@]}"
env "${offline_environment[@]}" dotnet run --project "$consumer_root/Direct/Direct.csproj" --no-build --no-restore -c Release

publish_directory="$temporary_directory/publish"
env "${offline_environment[@]}" dotnet publish "$consumer_root/Direct/Direct.csproj" --no-restore -c Release \
  -o "$publish_directory" "${runtime_properties[@]}"
env "${offline_environment[@]}" dotnet "$publish_directory/Direct.dll"

env "${offline_environment[@]}" dotnet build "$consumer_root/TransitiveApp/TransitiveApp.csproj" --no-restore -c Release \
  "${runtime_properties[@]}"
env "${offline_environment[@]}" dotnet run --project "$consumer_root/TransitiveApp/TransitiveApp.csproj" \
  --no-build --no-restore -c Release

echo "published-consumer-tests: PASS ($runtime_identifier)"
