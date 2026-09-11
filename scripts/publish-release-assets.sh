#!/usr/bin/env bash
set -euo pipefail

release_tag="${1:?usage: $0 <release-tag> <asset-directory>}"
asset_directory="${2:?usage: $0 <release-tag> <asset-directory>}"

if ! gh release view "$release_tag" >/dev/null 2>&1; then
  release_arguments=(
    "$release_tag"
    --title "Infoveave.NLopt ${release_tag#v}"
    --generate-notes
  )
  if [[ "$release_tag" == *-* ]]; then
    release_arguments+=(--prerelease)
  fi
  gh release create "${release_arguments[@]}"
fi

existing_assets="$(gh release view "$release_tag" --json assets --jq '.assets[].name')"
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT

found_asset=false
for asset_file in "$asset_directory"/*; do
  [ -f "$asset_file" ] || continue
  found_asset=true
  asset_name="$(basename "$asset_file")"

  if grep -Fqx "$asset_name" <<<"$existing_assets"; then
    gh release download "$release_tag" --pattern "$asset_name" --dir "$temporary_directory"
    if ! cmp -s "$asset_file" "$temporary_directory/$asset_name"; then
      echo "error: published release asset has different bytes: $asset_name" >&2
      exit 1
    fi
    echo "release asset already published with identical bytes: $asset_name"
    continue
  fi

  gh release upload "$release_tag" "$asset_file"
done

if [ "$found_asset" = false ]; then
  echo "error: no release assets found in $asset_directory" >&2
  exit 1
fi
