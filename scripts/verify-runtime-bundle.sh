#!/usr/bin/env bash
set -euo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_directory/.." && pwd)"
runtime_root="${1:-}"
expected_rid="${2:-}"
expected_native_version="${3:-}"
expected_runtime_compatibility="${4:-}"

if [ -z "$runtime_root" ] || [ -z "$expected_rid" ] || [ -z "$expected_native_version" ] || [ -z "$expected_runtime_compatibility" ]; then
  echo "usage: $0 <runtime-root> <expected-rid> <expected-native-version> <expected-runtime-compatibility>" >&2
  exit 2
fi

python3 - \
  "$repository_root/eng/native-source.json" \
  "$runtime_root" \
  "$expected_rid" \
  "$expected_native_version" \
  "$expected_runtime_compatibility" <<'PY'
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys

lock_path, runtime_root, expected_rid, expected_version, expected_compatibility = sys.argv[1:]
root = pathlib.Path(runtime_root).resolve()
manifest_path = root / "manifest.json"
if not manifest_path.is_file():
    raise SystemExit(f"error: bundle manifest not found: {manifest_path}")

with open(lock_path, encoding="utf-8") as source:
    lock = json.load(source)
with open(manifest_path, encoding="utf-8") as source:
    manifest = json.load(source)

def require(condition, message):
    if not condition:
        raise SystemExit(f"error: {message}")

require(manifest.get("schemaVersion") == 1, "unsupported manifest schema")
require(manifest.get("rid") == expected_rid, "runtime identifier does not match")
require(manifest.get("nativeVersion") == expected_version, "native version does not match")
require(manifest.get("runtimeCompatibility") == expected_compatibility, "managed runtime compatibility does not match")
require(manifest.get("nativeVersion") == lock["nativeVersion"], "native version differs from the source lock")
source = manifest.get("source", {})
for key in ("tag", "commit", "archiveUrl", "archiveSha256"):
    require(source.get(key) == lock[key], f"source {key} differs from the source lock")

expected_native_paths = {
    "linux-x64": "native/libnlopt.so",
    "win-x64": "native/nlopt.dll",
    "osx-arm64": "native/libnlopt.dylib",
}
require(expected_rid in expected_native_paths, "unsupported runtime identifier")
native_library = manifest.get("nativeLibrary")
require(native_library == expected_native_paths[expected_rid], "native library path is not canonical")
require(isinstance(manifest.get("dependencies"), list) and manifest["dependencies"], "runtime dependencies are missing")
require(isinstance(manifest.get("toolchain"), dict), "toolchain provenance is missing")
require(isinstance(manifest.get("buildOptions"), dict), "build options are missing")

entries = manifest.get("files")
require(isinstance(entries, list), "file inventory is missing")
expected_inventory = {"THIRD-PARTY-NOTICES.md", native_library}
actual_inventory = set()
for entry in entries:
    relative = entry.get("path") if isinstance(entry, dict) else None
    require(isinstance(relative, str) and relative, "file inventory contains an invalid path")
    path = pathlib.PurePosixPath(relative)
    require(not path.is_absolute() and ".." not in path.parts and "." not in path.parts, f"unsafe bundle path: {relative}")
    require(relative not in actual_inventory, f"duplicate bundle path: {relative}")
    actual_inventory.add(relative)
    full_path = root.joinpath(*path.parts)
    require(not full_path.is_symlink(), f"bundle files must not be symbolic links: {relative}")
    require(full_path.is_file(), f"bundle file is missing: {relative}")
    require(full_path.resolve().is_relative_to(root), f"bundle file escapes the runtime root: {relative}")
    digest = hashlib.sha256(full_path.read_bytes()).hexdigest()
    require(entry.get("sha256") == digest, f"SHA-256 mismatch: {relative}")
    require(entry.get("size") == full_path.stat().st_size, f"size mismatch: {relative}")
require(actual_inventory == expected_inventory, "bundle file inventory is incomplete or contains unexpected files")

disk_inventory = {
    path.relative_to(root).as_posix()
    for path in root.rglob("*")
    if path.is_file() and path.name != "manifest.json"
}
require(disk_inventory == expected_inventory, "bundle contains files not covered by the manifest")

native_path = root.joinpath(*pathlib.PurePosixPath(native_library).parts)
description = subprocess.run(
    ["file", "-b", str(native_path)],
    check=True,
    capture_output=True,
    text=True,
).stdout
architecture_markers = {
    "linux-x64": ("ELF 64-bit", "x86-64"),
    "win-x64": ("PE32+", "x86-64"),
    "osx-arm64": ("Mach-O 64-bit", "arm64"),
}
require(all(marker in description for marker in architecture_markers[expected_rid]), "native library architecture does not match the RID")

if expected_rid == "linux-x64":
    dynamic = subprocess.run(["readelf", "-d", str(native_path)], check=True, capture_output=True, text=True).stdout
    actual_dependencies = sorted(set(re.findall(r"Shared library: \[([^]]+)\]", dynamic)))
elif expected_rid == "osx-arm64":
    linked = subprocess.run(["otool", "-L", str(native_path)], check=True, capture_output=True, text=True).stdout.splitlines()
    actual_dependencies = sorted({line.strip().split()[0] for line in linked[2:] if line.strip()})
    load_commands = subprocess.run(["otool", "-l", str(native_path)], check=True, capture_output=True, text=True).stdout
    require(re.search(r"\bminos 15\.0\b", load_commands) is not None, "macOS deployment target is not 15.0")
else:
    actual_dependencies = sorted(manifest["dependencies"])
require(actual_dependencies == sorted(manifest["dependencies"]), "runtime dependency declarations do not match the native library")
PY

echo "verified runtime bundle: $runtime_root"
