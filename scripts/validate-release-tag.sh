#!/usr/bin/env bash
set -euo pipefail

release_tag="${1:-}"
if [ -z "$release_tag" ]; then
  echo "usage: $0 <v-managed-package-version>" >&2
  exit 2
fi

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_directory/.." && pwd)"
managed_version="$(python3 - "$repository_root/Directory.Build.props" <<'PY'
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
element = root.find('.//ManagedPackageVersion')
if element is None or not element.text:
    raise SystemExit('error: ManagedPackageVersion was not found')
print(element.text.strip())
PY
)"
expected_tag="v$managed_version"
if [ "$release_tag" != "$expected_tag" ]; then
  echo "error: release tag '$release_tag' does not match managed package version '$managed_version' (expected '$expected_tag')" >&2
  exit 1
fi

echo "release tag matches managed package version: $release_tag"
