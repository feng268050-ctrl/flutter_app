#!/usr/bin/env bash
set -euo pipefail

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

input_dir="$workdir/input"
mkdir -p "$input_dir"
touch "$input_dir/L1.xlsx" "$input_dir/L1 Pro.xlsx" "$input_dir/ignore.txt"

zip_path="$workdir/process-lib.zip"
(cd "$input_dir" && zip -q "$zip_path" "L1.xlsx" "L1 Pro.xlsx" "ignore.txt")

extract_dir="$workdir/extract"
mkdir -p "$extract_dir"
python3 - "$zip_path" "$extract_dir" <<'PY'
import sys
import zipfile
from pathlib import Path

zip_path = Path(sys.argv[1])
extract_dir = Path(sys.argv[2])

with zipfile.ZipFile(zip_path) as zf:
    for name in zf.namelist():
        if name.endswith('/'):
            continue
        leaf = Path(name).name
        if not leaf.lower().endswith('.xlsx'):
            continue
        with zf.open(name) as src, open(extract_dir / leaf, 'wb') as dst:
            dst.write(src.read())

files = sorted(p.name for p in extract_dir.glob('*'))
assert files == ["L1 Pro.xlsx", "L1.xlsx"], f"Unexpected files: {files}"
PY

echo "OK: process-library zip extraction layout verified (xlsx-only, flattened)."
