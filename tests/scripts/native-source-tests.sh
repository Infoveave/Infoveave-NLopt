#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source_archive="${NLOPT_TEST_SOURCE_ARCHIVE:?Set NLOPT_TEST_SOURCE_ARCHIVE to the pinned NLopt source archive}"
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT

source_directory="$(bash "$repository_root/scripts/download-native-source.sh" \
  --archive "$source_archive" \
  "$temporary_directory/source")"

test -f "$source_directory/CMakeLists.txt"
test -f "$source_directory/src/api/nlopt.h"

tampered_archive="$temporary_directory/tampered.tar.gz"
cp "$source_archive" "$tampered_archive"
printf 'changed' >> "$tampered_archive"

if bash "$repository_root/scripts/download-native-source.sh" \
  --archive "$tampered_archive" \
  "$temporary_directory/tampered-output" \
  >"$temporary_directory/tampered.stdout" \
  2>"$temporary_directory/tampered.stderr"; then
  echo "expected a changed source archive to be rejected" >&2
  exit 1
fi

grep -q "SHA-256 mismatch" "$temporary_directory/tampered.stderr"

echo "native-source-tests: PASS"
