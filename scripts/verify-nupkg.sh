#!/usr/bin/env bash
set -euo pipefail

package_directory="${1:-artifacts/nupkg}"
if [ ! -d "$package_directory" ]; then
  echo "error: package directory not found: $package_directory" >&2
  exit 1
fi

found=0
for package_file in "$package_directory"/Infoveave.NLopt.*.nupkg; do
  [ -e "$package_file" ] || continue
  case "$package_file" in *.snupkg) continue ;; esac
  found=1
  if [ "$(wc -c < "$package_file" | tr -d ' ')" -gt $((5 * 1024 * 1024)) ]; then
    echo "error: managed package exceeds 5 MiB: $package_file" >&2
    exit 1
  fi

  inventory="$(mktemp)"
  trap 'rm -f "$inventory"' EXIT
  unzip -Z1 "$package_file" | tr -d '\r' > "$inventory"
  if grep -Eq '(^|/)(nlopt\.dll|libnlopt\.so|libnlopt\.dylib)$|^runtimes/.*/native/' "$inventory"; then
    echo "error: managed package contains a native runtime asset" >&2
    exit 1
  fi
  for required in \
    'buildTransitive/Infoveave.NLopt.targets' \
    'lib/net10.0/Infoveave.NLopt.dll' \
    'lib/net10.0/Infoveave.NLopt.xml' \
    'PACKAGE.md' \
    'THIRD-PARTY-NOTICES.md'; do
    grep -Fxq "$required" "$inventory" || {
      echo "error: managed package is missing $required" >&2
      exit 1
    }
  done

  targets="$(unzip -p "$package_file" 'buildTransitive/Infoveave.NLopt.targets')"
  if printf '%s' "$targets" | grep -E 'DownloadFile|https?://' >/dev/null; then
    echo "error: buildTransitive target contains download behavior" >&2
    exit 1
  fi
  nuspec="$(unzip -p "$package_file" '*.nuspec')"
  printf '%s' "$nuspec" | grep -Fq '<license type="expression">UNLICENSED</license>' || {
    echo "error: managed package license declaration is missing" >&2
    exit 1
  }
done

if [ "$found" -eq 0 ]; then
  echo "error: no Infoveave.NLopt nupkg found in $package_directory" >&2
  exit 1
fi

echo "verify-nupkg: PASS"
