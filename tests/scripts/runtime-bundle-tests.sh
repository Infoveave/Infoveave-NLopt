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

verify()
{
  bash "$repository_root/scripts/verify-runtime-bundle.sh" \
    "$1" "$2" "$3" "$4"
}

verify "$runtime_root" "$runtime_identifier" "2.11.0" "managed-api-v1"

if verify "$runtime_root" "linux-x64" "2.11.0" "managed-api-v1" >/dev/null 2>&1; then
  echo "expected wrong RID to be rejected" >&2
  exit 1
fi
if verify "$runtime_root" "$runtime_identifier" "2.10.0" "managed-api-v1" >/dev/null 2>&1; then
  echo "expected wrong native version to be rejected" >&2
  exit 1
fi
if verify "$runtime_root" "$runtime_identifier" "2.11.0" "managed-api-v2" >/dev/null 2>&1; then
  echo "expected wrong managed compatibility to be rejected" >&2
  exit 1
fi

tampered_root="$temporary_directory/tampered"
cp -R "$runtime_root" "$tampered_root"
printf 'tampered\n' >> "$tampered_root/THIRD-PARTY-NOTICES.md"
if verify "$tampered_root" "$runtime_identifier" "2.11.0" "managed-api-v1" >/dev/null 2>&1; then
  echo "expected a corrupted bundle file to be rejected" >&2
  exit 1
fi

unsafe_root="$temporary_directory/unsafe"
cp -R "$runtime_root" "$unsafe_root"
python3 - "$unsafe_root/manifest.json" <<'PY'
import json
import sys

path = sys.argv[1]
manifest = json.load(open(path, encoding="utf-8"))
manifest["files"][0]["path"] = "../outside"
with open(path, "w", encoding="utf-8") as output:
    json.dump(manifest, output)
PY
if verify "$unsafe_root" "$runtime_identifier" "2.11.0" "managed-api-v1" >/dev/null 2>&1; then
  echo "expected an unsafe manifest path to be rejected" >&2
  exit 1
fi

archive_file="$(bash "$repository_root/scripts/package-runtime-bundle.sh" \
  "$runtime_identifier" \
  "$runtime_root" \
  "$temporary_directory/release")"
test "$(basename "$archive_file")" = \
  "infoveave-nlopt-runtime-1-nlopt-2.11.0-$runtime_identifier.zip"
test -s "$archive_file"
test -s "$archive_file.sha256"
test -s "$archive_file.THIRD-PARTY-NOTICES.md"
grep -q 'SLSQP COPYRIGHT' "$archive_file.THIRD-PARTY-NOTICES.md"
(
  cd "$(dirname "$archive_file")"
  shasum -a 256 -c "$(basename "$archive_file").sha256"
)
mkdir "$temporary_directory/extracted"
unzip -q "$archive_file" -d "$temporary_directory/extracted"
verify "$temporary_directory/extracted/nlopt" "$runtime_identifier" "2.11.0" "managed-api-v1"

echo "runtime-bundle-tests: PASS"
