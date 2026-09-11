#!/usr/bin/env bash
set -euo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_directory/.." && pwd)"
lock_file="$repository_root/eng/native-source.json"
archive_file=""

if [ "${1:-}" = "--archive" ]; then
  archive_file="${2:-}"
  shift 2
fi

destination_root="${1:-$repository_root/artifacts/native-source}"
if [ -e "$destination_root" ]; then
  echo "error: destination already exists: $destination_root" >&2
  exit 1
fi

read_lock()
{
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))[sys.argv[2]])' "$lock_file" "$1"
}

archive_url="$(read_lock archiveUrl)"
expected_hash="$(read_lock archiveSha256)"
native_version="$(read_lock nativeVersion)"
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT

if [ -z "$archive_file" ]; then
  archive_file="$temporary_directory/nlopt.tar.gz"
  curl --proto '=https' --tlsv1.2 --retry 5 --retry-all-errors --fail --location --silent --show-error \
    "$archive_url" --output "$archive_file"
elif [ ! -f "$archive_file" ]; then
  echo "error: source archive not found: $archive_file" >&2
  exit 1
fi

actual_hash="$(shasum -a 256 "$archive_file" | cut -d ' ' -f 1)"
if [ "$actual_hash" != "$expected_hash" ]; then
  echo "error: SHA-256 mismatch for NLopt source archive" >&2
  echo "expected: $expected_hash" >&2
  echo "actual:   $actual_hash" >&2
  exit 1
fi

python3 -c '
import sys, tarfile
with tarfile.open(sys.argv[1], "r:gz") as archive:
    for member in archive.getmembers():
        normalized = member.name.replace("\\", "/")
        if normalized.startswith("/") or ".." in normalized.split("/"):
            raise SystemExit(f"error: unsafe archive path: {member.name}")
' "$archive_file"

mkdir -p "$destination_root"
tar -xzf "$archive_file" -C "$destination_root"
source_directory="$destination_root/nlopt-$native_version"
if [ ! -f "$source_directory/CMakeLists.txt" ] || [ ! -f "$source_directory/src/api/nlopt.h" ]; then
  echo "error: pinned NLopt source layout was not found under $source_directory" >&2
  exit 1
fi

echo "$source_directory"
