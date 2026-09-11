#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT
fake_bin="$temporary_directory/bin"
remote_assets="$temporary_directory/remote-assets"
local_assets="$temporary_directory/local-assets"
remote_package="$temporary_directory/remote-package.nupkg"
mkdir -p "$fake_bin" "$remote_assets" "$local_assets"
printf 'runtime archive\n' > "$local_assets/runtime.zip"

cat > "$fake_bin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
command="$1 $2"
shift 2
case "$command" in
  'release view')
    shift
    if [ "${1:-}" = '--json' ]; then
      find "$FAKE_REMOTE_ASSETS" -type f -maxdepth 1 -exec basename {} \;
    fi
    ;;
  'release create') exit 0 ;;
  'release upload')
    shift
    cp "$1" "$FAKE_REMOTE_ASSETS/$(basename "$1")"
    ;;
  'release download')
    shift
    pattern=''
    destination=''
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --pattern) pattern="$2"; shift 2 ;;
        --dir) destination="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    cp "$FAKE_REMOTE_ASSETS/$pattern" "$destination/$pattern"
    ;;
  *) echo "unexpected gh command: $command" >&2; exit 1 ;;
esac
SH
chmod +x "$fake_bin/gh"

cat > "$fake_bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
output=''
write_status=false
url=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --output) output="$2"; shift 2 ;;
    --write-out) write_status=true; shift 2 ;;
    --user) shift 2 ;;
    --fail|--silent|--show-error|--location) shift ;;
    *) url="$1"; shift ;;
  esac
done
case "$url" in
  */index.json)
    printf '%s\n' '{"resources":[{"@type":"PackageBaseAddress/3.0.0","@id":"https://packages.example.test/v3-flatcontainer"}]}' > "$output"
    ;;
  *)
    if [ -f "$FAKE_REMOTE_PACKAGE" ]; then
      cp "$FAKE_REMOTE_PACKAGE" "$output"
      status=200
    else
      : > "$output"
      status=404
    fi
    if [ "$write_status" = true ]; then printf '%s' "$status"; fi
    ;;
esac
SH
cat > "$fake_bin/dotnet" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [ "$1 $2" != 'nuget push' ]; then
  echo 'unexpected dotnet command' >&2
  exit 1
fi
cp "$3" "$FAKE_REMOTE_PACKAGE"
SH
chmod +x "$fake_bin/curl" "$fake_bin/dotnet"

PATH="$fake_bin:$PATH" FAKE_REMOTE_ASSETS="$remote_assets" \
  bash "$repository_root/scripts/publish-release-assets.sh" v1.0.0-preview.1 "$local_assets"
cmp "$local_assets/runtime.zip" "$remote_assets/runtime.zip"
PATH="$fake_bin:$PATH" FAKE_REMOTE_ASSETS="$remote_assets" \
  bash "$repository_root/scripts/publish-release-assets.sh" v1.0.0-preview.1 "$local_assets"
printf 'changed\n' > "$local_assets/runtime.zip"
if PATH="$fake_bin:$PATH" FAKE_REMOTE_ASSETS="$remote_assets" \
  bash "$repository_root/scripts/publish-release-assets.sh" v1.0.0-preview.1 "$local_assets" >/dev/null 2>&1; then
  echo 'expected changed published bytes to be rejected' >&2
  exit 1
fi

managed_package="$temporary_directory/Infoveave.NLopt.1.0.0-preview.1.nupkg"
printf 'managed package\n' > "$managed_package"
publication_environment=(
  "PATH=$fake_bin:$PATH"
  'GITHUB_REPOSITORY_OWNER=Infoveave'
  'GITHUB_ACTOR=test-actor'
  'GITHUB_TOKEN=test-token'
  "FAKE_REMOTE_PACKAGE=$remote_package"
)
env "${publication_environment[@]}" \
  bash "$repository_root/scripts/publish-managed-package.sh" "$managed_package"
cmp "$managed_package" "$remote_package"
env "${publication_environment[@]}" \
  bash "$repository_root/scripts/publish-managed-package.sh" "$managed_package"
printf 'changed package\n' > "$managed_package"
if env "${publication_environment[@]}" \
  bash "$repository_root/scripts/publish-managed-package.sh" "$managed_package" >/dev/null 2>&1; then
  echo 'expected changed published package bytes to be rejected' >&2
  exit 1
fi

echo 'publish-script-tests: PASS'
