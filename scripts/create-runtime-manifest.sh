#!/usr/bin/env bash
set -euo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_directory/.." && pwd)"
runtime_identifier="${1:-}"
runtime_root="${2:-}"
build_directory="${3:-}"

if [ -z "$runtime_identifier" ] || [ -z "$runtime_root" ] || [ -z "$build_directory" ]; then
  echo "usage: $0 <runtime-identifier> <runtime-root> <cmake-build-directory>" >&2
  exit 2
fi
if [ ! -f "$build_directory/CMakeCache.txt" ]; then
  echo "error: CMake cache not found: $build_directory/CMakeCache.txt" >&2
  exit 1
fi

case "$runtime_identifier" in
  linux-x64) native_relative_path="native/libnlopt.so" ;;
  osx-arm64) native_relative_path="native/libnlopt.dylib" ;;
  *) echo "error: unsupported runtime identifier: $runtime_identifier" >&2; exit 1 ;;
esac

native_file="$runtime_root/$native_relative_path"
notices_file="$runtime_root/THIRD-PARTY-NOTICES.md"
if [ ! -f "$native_file" ] || [ ! -f "$notices_file" ]; then
  echo "error: runtime root is missing the native library or notices" >&2
  exit 1
fi

compiler_path="$(sed -n 's/^CMAKE_C_COMPILER:FILEPATH=//p' "$build_directory/CMakeCache.txt" | head -n 1)"
if [ -z "$compiler_path" ] || [ ! -x "$compiler_path" ]; then
  echo "error: C compiler could not be resolved from CMakeCache.txt" >&2
  exit 1
fi
compiler_version="$($compiler_path --version | head -n 1)"
cmake_version="$(cmake --version | head -n 1)"
dependencies_file="$(mktemp)"
trap 'rm -f "$dependencies_file"' EXIT

case "$runtime_identifier" in
  linux-x64)
    readelf -d "$native_file" \
      | sed -n 's/.*Shared library: \[\([^]]*\)\].*/\1/p' \
      | sort -u > "$dependencies_file"
    ;;
  osx-arm64)
    otool -L "$native_file" \
      | tail -n +3 \
      | awk '{print $1}' \
      | sort -u > "$dependencies_file"
    ;;
esac

if [ ! -s "$dependencies_file" ]; then
  echo "error: no runtime dependencies were discovered for $native_file" >&2
  exit 1
fi

python3 - \
  "$repository_root/eng/native-source.json" \
  "$runtime_root" \
  "$runtime_identifier" \
  "$native_relative_path" \
  "$cmake_version" \
  "$compiler_version" \
  "$dependencies_file" <<'PY'
import hashlib
import json
import os
import platform
import sys

lock_path, runtime_root, rid, native_library, cmake_version, compiler_version, dependencies_path = sys.argv[1:]
with open(lock_path, encoding="utf-8") as source:
    lock = json.load(source)

def file_entry(relative_path):
    full_path = os.path.join(runtime_root, relative_path)
    digest = hashlib.sha256()
    with open(full_path, "rb") as content:
        for chunk in iter(lambda: content.read(1024 * 1024), b""):
            digest.update(chunk)
    return {
        "path": relative_path,
        "size": os.path.getsize(full_path),
        "sha256": digest.hexdigest(),
    }

with open(dependencies_path, encoding="utf-8") as source:
    dependencies = [line.strip() for line in source if line.strip()]

manifest = {
    "schemaVersion": 1,
    "runtimeCompatibility": "managed-api-v1",
    "nativeVersion": lock["nativeVersion"],
    "rid": rid,
    "nativeLibrary": native_library,
    "source": {
        "tag": lock["tag"],
        "commit": lock["commit"],
        "archiveUrl": lock["archiveUrl"],
        "archiveSha256": lock["archiveSha256"],
    },
    "toolchain": {
        "cmake": cmake_version,
        "cCompiler": compiler_version,
        "buildHostSystem": platform.system(),
        "buildHostArchitecture": platform.machine(),
    },
    "buildOptions": {
        "BUILD_SHARED_LIBS": "ON",
        "CMAKE_BUILD_TYPE": "Release",
        "DISABLE_FP_CONTRACT": "ON",
        "NLOPT_CXX": "OFF",
        "NLOPT_LUKSAN": "OFF",
        "NLOPT_FORTRAN": "OFF",
        "NLOPT_GUILE": "OFF",
        "NLOPT_JAVA": "OFF",
        "NLOPT_MATLAB": "OFF",
        "NLOPT_OCTAVE": "OFF",
        "NLOPT_PYTHON": "OFF",
        "NLOPT_SWIG": "OFF",
        "NLOPT_TESTS": "OFF",
    },
    "dependencies": dependencies,
    "files": [
        file_entry("THIRD-PARTY-NOTICES.md"),
        file_entry(native_library),
    ],
}
if rid == "osx-arm64":
    manifest["toolchain"]["deploymentTarget"] = "15.0"

manifest_path = os.path.join(runtime_root, "manifest.json")
with open(manifest_path, "w", encoding="utf-8") as output:
    json.dump(manifest, output, indent=2, sort_keys=True)
    output.write("\n")
PY
