#!/usr/bin/env bash
set -euo pipefail

runtime_identifier="${1:-}"
if [ -z "$runtime_identifier" ]; then
  echo "usage: $0 <linux-x64|win-x64|osx-arm64> [runtime-root] [output-directory]" >&2
  exit 2
fi

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_directory/.." && pwd)"
runtime_root="${2:-$repository_root/artifacts/runtime-bundles/$runtime_identifier/nlopt}"
output_directory="${3:-$repository_root/artifacts/runtime-releases}"
manifest_file="$runtime_root/manifest.json"

if [ ! -f "$manifest_file" ]; then
  echo "error: runtime manifest not found: $manifest_file" >&2
  exit 1
fi

read_manifest()
{
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))[sys.argv[2]])' \
    "$manifest_file" "$1"
}

native_version="$(read_manifest nativeVersion)"
runtime_compatibility="$(read_manifest runtimeCompatibility)"
if [[ "$runtime_compatibility" != managed-api-v* ]]; then
  echo "error: unsupported runtime compatibility: $runtime_compatibility" >&2
  exit 1
fi
compatibility_version="${runtime_compatibility#managed-api-v}"

bash "$script_directory/verify-runtime-bundle.sh" \
  "$runtime_root" \
  "$runtime_identifier" \
  "$native_version" \
  "$runtime_compatibility" >&2

mkdir -p "$output_directory"
output_directory="$(cd "$output_directory" && pwd)"
archive_name="infoveave-nlopt-runtime-$compatibility_version-nlopt-$native_version-$runtime_identifier.zip"
archive_file="$output_directory/$archive_name"
runtime_parent="$(cd "$runtime_root/.." && pwd)"
runtime_directory_name="$(basename "$runtime_root")"

if [ -e "$archive_file" ] || [ -e "$archive_file.sha256" ]; then
  echo "error: release archive already exists: $archive_file" >&2
  exit 1
fi
(
  cd "$runtime_parent"
  zip -X -q -r "$archive_file" "$runtime_directory_name"
)

archive_hash="$(shasum -a 256 "$archive_file" | cut -d ' ' -f 1)"
printf '%s  %s\n' "$archive_hash" "$archive_name" > "$archive_file.sha256"

echo "$archive_file"
