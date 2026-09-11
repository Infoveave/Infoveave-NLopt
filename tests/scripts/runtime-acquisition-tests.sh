#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
runtime_root="${NLOPT_TEST_RUNTIME_ROOT:?Set NLOPT_TEST_RUNTIME_ROOT to an extracted, verified nlopt directory}"
runtime_identifier="${NLOPT_TEST_RID:-osx-arm64}"
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT

archive_file="$(bash "$repository_root/scripts/package-runtime-bundle.sh" \
  "$runtime_identifier" "$runtime_root" "$temporary_directory/release")"
archive_hash="$(shasum -a 256 "$archive_file" | cut -d ' ' -f 1)"

acquired_root="$(bash "$repository_root/scripts/acquire-runtime-bundle.sh" \
  --archive "$archive_file" \
  "$runtime_identifier" \
  "$archive_hash" \
  "$temporary_directory/acquired")"
bash "$repository_root/scripts/verify-runtime-bundle.sh" \
  "$acquired_root" "$runtime_identifier" '2.11.0' 'managed-api-v1'

if bash "$repository_root/scripts/acquire-runtime-bundle.sh" \
  --archive "$archive_file" \
  "$runtime_identifier" \
  '0000000000000000000000000000000000000000000000000000000000000000' \
  "$temporary_directory/rejected" \
  >"$temporary_directory/rejected.stdout" 2>"$temporary_directory/rejected.stderr"; then
  echo "expected a wrong release checksum to be rejected" >&2
  exit 1
fi
grep -q 'SHA-256 mismatch' "$temporary_directory/rejected.stderr"

echo "runtime-acquisition-tests: PASS"
