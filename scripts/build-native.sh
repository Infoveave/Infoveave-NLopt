#!/usr/bin/env bash
set -euo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
runtime_identifier="${1:-}"
source_directory="${2:-}"
output_root="${3:-}"

if [ -z "$runtime_identifier" ] || [ -z "$source_directory" ] || [ -z "$output_root" ]; then
  echo "usage: $0 <linux-x64|osx-arm64> <source-directory> <output-root>" >&2
  exit 2
fi
if [ ! -f "$source_directory/CMakeLists.txt" ]; then
  echo "error: NLopt source directory is invalid: $source_directory" >&2
  exit 1
fi
if [ -e "$output_root" ]; then
  echo "error: output root already exists: $output_root" >&2
  exit 1
fi

case "$runtime_identifier" in
  linux-x64)
    if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
      echo "error: linux-x64 must be built on a Linux x86_64 host" >&2
      exit 1
    fi
    native_name="libnlopt.so"
    platform_options=()
    ;;
  osx-arm64)
    if [ "$(uname -s)" != "Darwin" ] || [ "$(uname -m)" != "arm64" ]; then
      echo "error: osx-arm64 must be built on an Apple Silicon host" >&2
      exit 1
    fi
    native_name="libnlopt.dylib"
    platform_options=(
      "-DCMAKE_OSX_ARCHITECTURES=arm64"
      "-DCMAKE_OSX_DEPLOYMENT_TARGET=15.0"
    )
    ;;
  *)
    echo "error: unsupported Unix runtime identifier: $runtime_identifier" >&2
    exit 1
    ;;
esac

build_directory="$output_root/build"
install_directory="$output_root/install"
runtime_root="$output_root/nlopt"

cmake -S "$source_directory" -B "$build_directory" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$install_directory" \
  -DBUILD_SHARED_LIBS=ON \
  -DNLOPT_CXX=OFF \
  -DNLOPT_LUKSAN=OFF \
  -DNLOPT_FORTRAN=OFF \
  -DNLOPT_PYTHON=OFF \
  -DNLOPT_OCTAVE=OFF \
  -DNLOPT_MATLAB=OFF \
  -DNLOPT_GUILE=OFF \
  -DNLOPT_JAVA=OFF \
  -DNLOPT_SWIG=OFF \
  -DNLOPT_TESTS=OFF \
  -DDISABLE_FP_CONTRACT=ON \
  "${platform_options[@]}" >&2
cmake --build "$build_directory" --config Release --parallel >&2
cmake --install "$build_directory" --config Release >&2

installed_native="$install_directory/lib/$native_name"
if [ ! -f "$installed_native" ]; then
  installed_native="$install_directory/lib64/$native_name"
fi
if [ ! -f "$installed_native" ]; then
  echo "error: CMake did not install $native_name" >&2
  exit 1
fi

mkdir -p "$runtime_root/native"
cp -L "$installed_native" "$runtime_root/native/$native_name"
if [ "$runtime_identifier" = "osx-arm64" ]; then
  install_name_tool -id "@rpath/$native_name" "$runtime_root/native/$native_name"
fi

notices_file="$runtime_root/THIRD-PARTY-NOTICES.md"
{
  printf '%s\n\n' '# Third-party notices' \
    'This bundle contains NLopt 2.11.0 built without the Luksan and C++ sources.' \
    'The following notices are copied verbatim from the pinned NLopt source archive.'
  while IFS='|' read -r label relative_path; do
    printf '\n## %s\n\n```text\n' "$label"
    sed 's/^\/\* *//; s/ *\*\/$//; s/^ \* *//' "$source_directory/$relative_path"
    printf '%s\n' '```'
  done <<'NOTICES'
NLopt root COPYING|COPYING
NLopt root COPYRIGHT|COPYRIGHT
BOBYQA COPYRIGHT|src/algs/bobyqa/COPYRIGHT
COBYLA COPYRIGHT|src/algs/cobyla/COPYRIGHT
DIRECT COPYING|src/algs/direct/COPYING
ESCH COPYRIGHT|src/algs/esch/COPYRIGHT
NEWUOA COPYRIGHT|src/algs/newuoa/COPYRIGHT
SLSQP COPYRIGHT|src/algs/slsqp/COPYRIGHT
NOTICES
} > "$notices_file"

bash "$script_directory/create-runtime-manifest.sh" \
  "$runtime_identifier" \
  "$runtime_root" \
  "$build_directory"

echo "$runtime_root"
