#!/usr/bin/env bash
set -euo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_directory/.." && pwd)"
archive_file=""
release_tag=""

case "${1:-}" in
  --archive)
    archive_file="${2:-}"
    shift 2
    ;;
  --release-tag)
    release_tag="${2:-}"
    shift 2
    ;;
  *)
    echo "usage: $0 (--archive <file> | --release-tag <tag>) <rid> <sha256> [destination-parent]" >&2
    exit 2
    ;;
esac

runtime_identifier="${1:-}"
expected_hash="${2:-}"
destination_parent="${3:-$repository_root/artifacts/acquired-runtime/$runtime_identifier}"
case "$runtime_identifier" in
  linux-x64|win-x64|osx-arm64) ;;
  *) echo "error: unsupported runtime identifier: $runtime_identifier" >&2; exit 1 ;;
esac
if ! printf '%s' "$expected_hash" | grep -Eq '^[0-9a-f]{64}$'; then
  echo "error: expected SHA-256 must contain 64 lowercase hexadecimal characters" >&2
  exit 1
fi
if [ -e "$destination_parent" ]; then
  echo "error: destination already exists: $destination_parent" >&2
  exit 1
fi

archive_name="infoveave-nlopt-runtime-1-nlopt-2.11.0-$runtime_identifier.zip"
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT
if [ -n "$release_tag" ]; then
  if ! printf '%s' "$release_tag" | grep -Eq '^v[0-9A-Za-z.-]+$'; then
    echo "error: invalid release tag: $release_tag" >&2
    exit 1
  fi
  archive_file="$temporary_directory/$archive_name"
  archive_url="https://github.com/Infoveave/Infoveave-NLopt/releases/download/$release_tag/$archive_name"
  curl --proto '=https' --tlsv1.2 --retry 5 --retry-all-errors --fail --location --silent --show-error \
    "$archive_url" --output "$archive_file"
elif [ ! -f "$archive_file" ]; then
  echo "error: runtime archive not found: $archive_file" >&2
  exit 1
fi

actual_hash="$(shasum -a 256 "$archive_file" | cut -d ' ' -f 1)"
if [ "$actual_hash" != "$expected_hash" ]; then
  echo "error: SHA-256 mismatch for NLopt runtime archive" >&2
  echo "expected: $expected_hash" >&2
  echo "actual:   $actual_hash" >&2
  exit 1
fi

mkdir -p "$destination_parent"
python3 - "$archive_file" "$destination_parent" <<'PY'
import pathlib
import stat
import sys
import zipfile

archive_path, destination = sys.argv[1:]
with zipfile.ZipFile(archive_path) as archive:
    for entry in archive.infolist():
        path = pathlib.PurePosixPath(entry.filename.replace("\\", "/"))
        if path.is_absolute() or ".." in path.parts:
            raise SystemExit(f"error: unsafe archive path: {entry.filename}")
        mode = entry.external_attr >> 16
        if stat.S_ISLNK(mode):
            raise SystemExit(f"error: symbolic links are not permitted: {entry.filename}")
    archive.extractall(destination)
PY

runtime_root="$destination_parent/nlopt"
bash "$script_directory/verify-runtime-bundle.sh" \
  "$runtime_root" "$runtime_identifier" '2.11.0' 'managed-api-v1' >&2
echo "$runtime_root"
