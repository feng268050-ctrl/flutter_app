#!/usr/bin/env bash
# Verify bundleFirmwareAssets copies the "latest" firmware (by filename HW/SW integer rules)
# into app assets.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

GRADLE_USER_HOME="${GRADLE_USER_HOME:-$HOME/.gradle}" ./gradlew :app:bundleFirmwareAssets -PskipBundledFetch=true --quiet

assets_dir="app/src/main/assets/firmware"
shopt -s nullglob
bins=("$assets_dir"/LSW01H????S????.bin)
shopt -u nullglob

# If no source firmware exists, bundleFirmwareAssets should skip and assets should have no bin.
src_bins=(firmware/LSW01H????S????.bin)
shopt -u nullglob

if [[ ${#src_bins[@]} -eq 0 ]]; then
  if [[ ${#bins[@]} -ne 0 ]]; then
    echo "ERROR: expected no bundled firmware in $assets_dir when firmware/ has none" >&2
    exit 1
  fi
  echo "OK: no firmware source present; bundleFirmwareAssets skipped"
  exit 0
fi

if [[ ${#bins[@]} -ne 1 ]]; then
  echo "ERROR: expected exactly one bundled firmware under $assets_dir, got ${#bins[@]}" >&2
  exit 1
fi

expected="$(python3 - <<'PY'
import glob, re
pat = re.compile(r"^LSW01H(?P<hw>\\d{4})S(?P<sw>\\d{4})\\.bin$", re.I)
best=None  # (sw, hw, name)
for p in glob.glob("firmware/LSW01H????S????.bin"):
    name = p.split("/")[-1]
    m = pat.match(name)
    if not m:
        continue
    hw=int(m.group("hw"))
    sw=int(m.group("sw"))
    cand=(sw, hw, name)
    if best is None or (cand[0],cand[1])>(best[0],best[1]):
        best=cand
print(best[2] if best else "")
PY
)"

if [[ -z "$expected" ]]; then
  echo "ERROR: could not compute expected firmware from firmware/ filenames" >&2
  exit 1
fi

actual="$(basename "${bins[0]}")"
if [[ "$actual" != "$expected" ]]; then
  echo "ERROR: bundled firmware mismatch: actual=$actual expected=$expected" >&2
  exit 1
fi

echo "OK: bundled firmware asset ${bins[0]} (latest by SW/HW)"
