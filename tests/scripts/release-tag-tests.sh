#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bash "$repository_root/scripts/validate-release-tag.sh" 'v2.11.0'

if bash "$repository_root/scripts/validate-release-tag.sh" 'v2.11.1' >/dev/null 2>&1; then
  echo "expected mismatched release tag to be rejected" >&2
  exit 1
fi

echo "release-tag-tests: PASS"
