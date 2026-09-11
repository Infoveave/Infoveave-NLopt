#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bash "$repository_root/scripts/validate-release-tag.sh" 'v1.0.0-preview.1'

if bash "$repository_root/scripts/validate-release-tag.sh" 'v1.0.0-preview.2' >/dev/null 2>&1; then
  echo "expected mismatched release tag to be rejected" >&2
  exit 1
fi

echo "release-tag-tests: PASS"
