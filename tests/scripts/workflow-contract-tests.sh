#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ci="$repository_root/.github/workflows/ci.yml"
publish="$repository_root/.github/workflows/publish.yml"
test -s "$ci"
test -s "$publish"

for workflow in "$ci" "$publish"; do
  grep -q 'ubuntu-22.04' "$workflow"
  grep -q 'windows-2022' "$workflow"
  grep -q 'macos-15' "$workflow"
  grep -q 'linux-x64' "$workflow"
  grep -q 'win-x64' "$workflow"
  grep -q 'osx-arm64' "$workflow"
  grep -q 'CMAKE_VERSION: 4.4.3' "$workflow"
  grep -q 'actions/checkout@v7' "$workflow"
  grep -q 'actions/setup-dotnet@v6' "$workflow"
done
grep -q 'actions/upload-artifact@v7' "$ci"
grep -q 'actions/download-artifact@v8' "$publish"
grep -q 'nuget.pkg.github.com' "$repository_root/scripts/publish-managed-package.sh"
grep -q 'permissions:' "$ci"
grep -q 'contents: read' "$ci"
grep -q 'publish-release-assets.sh' "$publish"
grep -q 'publish-managed-package.sh' "$publish"
test "$(grep -c 'contents: write' "$publish")" -eq 1
test "$(grep -c 'packages: write' "$publish")" -eq 1
test "$(grep -c 'persist-credentials: false' "$publish")" -eq 3
if grep -Eq 'ubuntu-latest|windows-latest|macos-latest|--skip-duplicate|--clobber' "$ci" "$publish"; then
  echo "workflows must pin runners and reject replacement of published bytes" >&2
  exit 1
fi

echo "workflow-contract-tests: PASS"
