#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT

dotnet pack "$repository_root/src/Infoveave.NLopt/Infoveave.NLopt.csproj" \
  -c Release \
  -o "$temporary_directory/packages"

bash "$repository_root/scripts/verify-nupkg.sh" "$temporary_directory/packages"

package_file="$(find "$temporary_directory/packages" -maxdepth 1 -name 'Infoveave.NLopt.*.nupkg' ! -name '*.snupkg' -print -quit)"
test -s "$package_file"
entries="$temporary_directory/entries.txt"
unzip -Z1 "$package_file" | tr -d '\r' > "$entries"
grep -q '^buildTransitive/Infoveave.NLopt.targets$' "$entries"
grep -q '^PACKAGE.md$' "$entries"
grep -q '^THIRD-PARTY-NOTICES.md$' "$entries"
grep -q '^lib/net10.0/Infoveave.NLopt.dll$' "$entries"
if grep -Eq '(^|/)(nlopt\.dll|libnlopt\.so|libnlopt\.dylib)$' "$entries"; then
  echo "managed package must not contain native NLopt binaries" >&2
  exit 1
fi

echo "package-tests: PASS"
