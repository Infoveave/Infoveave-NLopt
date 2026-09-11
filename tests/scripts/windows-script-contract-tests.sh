#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

for script in \
  download-native-source.ps1 \
  build-native.ps1 \
  verify-runtime-bundle.ps1 \
  package-runtime-bundle.ps1; do
  test -s "$repository_root/scripts/$script"
done

grep -q 'SHA256' "$repository_root/scripts/download-native-source.ps1"
grep -q 'win-x64' "$repository_root/scripts/build-native.ps1"
grep -q 'NLOPT_LUKSAN=OFF' "$repository_root/scripts/build-native.ps1"
grep -q 'dumpbin' "$repository_root/scripts/build-native.ps1"
grep -q 'manifest.json' "$repository_root/scripts/build-native.ps1"
grep -q '88c424d4f458412787df96fcc95218acbca224fd' "$repository_root/scripts/verify-runtime-bundle.ps1"
grep -q '0x8664' "$repository_root/scripts/verify-runtime-bundle.ps1"
grep -q 'Compress-Archive' "$repository_root/scripts/package-runtime-bundle.ps1"

echo "windows-script-contract-tests: PASS"
