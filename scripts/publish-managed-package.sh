#!/usr/bin/env bash
set -euo pipefail

package_file="${1:?usage: $0 <package-file>}"
owner="${GITHUB_REPOSITORY_OWNER:?GITHUB_REPOSITORY_OWNER is required}"
username="${GITHUB_ACTOR:?GITHUB_ACTOR is required}"
token="${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
package_name="$(basename "$package_file")"
case "$package_name" in
  Infoveave.NLopt.*.nupkg) ;;
  *) echo "error: unexpected managed package filename: $package_name" >&2; exit 1 ;;
esac
version="${package_name#Infoveave.NLopt.}"
version="${version%.nupkg}"
lower_version="$(printf '%s' "$version" | tr '[:upper:]' '[:lower:]')"

temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT
service_index="$temporary_directory/service-index.json"
curl --fail --silent --show-error --location \
  --user "$username:$token" \
  "https://nuget.pkg.github.com/$owner/index.json" \
  --output "$service_index"
package_base_address="$(python3 - "$service_index" <<'PY'
import json
import sys

index = json.load(open(sys.argv[1], encoding="utf-8"))
for resource in index["resources"]:
    resource_type = resource.get("@type", "")
    if resource_type == "PackageBaseAddress/3.0.0" or resource_type.startswith("PackageBaseAddress/3.0.0;"):
        print(resource["@id"].rstrip("/"))
        break
else:
    raise SystemExit("PackageBaseAddress resource was not found")
PY
)"

existing_package="$temporary_directory/$package_name"
download_url="$package_base_address/infoveave.nlopt/$lower_version/infoveave.nlopt.$lower_version.nupkg"
http_status="$(curl --silent --show-error --location \
  --user "$username:$token" \
  --output "$existing_package" \
  --write-out '%{http_code}' \
  "$download_url")"

case "$http_status" in
  200)
    if ! cmp -s "$package_file" "$existing_package"; then
      echo "error: published managed package has different bytes: $package_name" >&2
      exit 1
    fi
    echo "managed package already published with identical bytes: $package_name"
    ;;
  404)
    dotnet nuget push "$package_file" \
      --source "https://nuget.pkg.github.com/$owner/index.json" \
      --api-key "$token"
    ;;
  *)
    echo "error: package lookup returned HTTP $http_status" >&2
    exit 1
    ;;
esac
