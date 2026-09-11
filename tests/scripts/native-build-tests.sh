#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source_archive="${NLOPT_TEST_SOURCE_ARCHIVE:?Set NLOPT_TEST_SOURCE_ARCHIVE to the pinned NLopt source archive}"
runtime_identifier="${NLOPT_TEST_RID:-osx-arm64}"
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT

source_directory="$(bash "$repository_root/scripts/download-native-source.sh" \
  --archive "$source_archive" \
  "$temporary_directory/source")"
runtime_root="$(bash "$repository_root/scripts/build-native.sh" \
  "$runtime_identifier" \
  "$source_directory" \
  "$temporary_directory/runtime")"

case "$runtime_identifier" in
  linux-x64) native_file="$runtime_root/native/libnlopt.so" ;;
  win-x64) native_file="$runtime_root/native/nlopt.dll" ;;
  osx-arm64) native_file="$runtime_root/native/libnlopt.dylib" ;;
  *) echo "unsupported test RID: $runtime_identifier" >&2; exit 1 ;;
esac

test -s "$native_file"
test -s "$runtime_root/THIRD-PARTY-NOTICES.md"
test -s "$runtime_root/manifest.json"
grep -q "NLopt root COPYING" "$runtime_root/THIRD-PARTY-NOTICES.md"
grep -q "SLSQP COPYRIGHT" "$runtime_root/THIRD-PARTY-NOTICES.md"
if grep -q "Luksan COPYRIGHT" "$runtime_root/THIRD-PARTY-NOTICES.md"; then
  echo "disabled Luksan sources must not be represented as compiled bundle content" >&2
  exit 1
fi
if [ "$runtime_identifier" = "osx-arm64" ]; then
  file "$native_file" | grep -q "arm64"
fi

bash "$repository_root/scripts/verify-runtime-bundle.sh" \
  "$runtime_root" \
  "$runtime_identifier" \
  "2.11.0" \
  "managed-api-v1"

python3 - "$runtime_root/manifest.json" <<'PY'
import json
import sys

manifest = json.load(open(sys.argv[1], encoding="utf-8"))
assert manifest["schemaVersion"] == 1
assert manifest["runtimeCompatibility"] == "managed-api-v1"
assert manifest["nativeVersion"] == "2.11.0"
assert manifest["source"]["commit"] == "88c424d4f458412787df96fcc95218acbca224fd"
assert manifest["source"]["archiveSha256"] == "53e552d83e9294d67db37f0f4a23f15933a9ef698485301a18b98b40004cf0de"
assert manifest["rid"] in {"linux-x64", "win-x64", "osx-arm64"}
assert manifest["toolchain"]["cmake"]
assert manifest["toolchain"]["cCompiler"]
assert manifest["buildOptions"]["NLOPT_LUKSAN"] == "OFF"
assert manifest["buildOptions"]["NLOPT_CXX"] == "OFF"
assert manifest["dependencies"]
assert {entry["path"] for entry in manifest["files"]} == {
    "THIRD-PARTY-NOTICES.md",
    manifest["nativeLibrary"],
}
assert all(len(entry["sha256"]) == 64 for entry in manifest["files"])
PY

python3 "$repository_root/tests/scripts/native-smoke.py" \
  "$runtime_root" \
  "$runtime_identifier"

echo "native-build-tests: PASS"
