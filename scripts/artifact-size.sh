#!/usr/bin/env bash
# Print artifact paths with human-readable and byte sizes (macOS/Linux).
set -euo pipefail

bytes_of() {
  local path="$1"
  if [[ -d "$path" ]]; then
    du -sk "$path" | awk '{print $1 * 1024}'
    return 0
  fi
  stat -c '%s' "$path" 2>/dev/null || stat -f '%z' "$path"
}

human_bytes() {
  awk -v bytes="$1" 'BEGIN {
    split("B KiB MiB GiB TiB", unit, " ");
    value = bytes + 0;
    i = 1;
    while (value >= 1024 && i < 5) {
      value = value / 1024;
      i++;
    }
    if (i == 1) {
      printf "%d %s", value, unit[i];
    } else {
      printf "%.1f %s", value, unit[i];
    }
  }'
}

print_artifact() {
  local path="$1"
  local bytes
  [[ -e "$path" ]] || return 0
  bytes="$(bytes_of "$path" | tr -d '[:space:]')"
  printf '%s (%s, %s bytes)\n' "$path" "$(human_bytes "$bytes")" "$bytes"
}

if [[ "$#" -eq 0 ]]; then
  echo "Usage: $0 <artifact>..." >&2
  exit 2
fi

for path in "$@"; do
  print_artifact "$path"
done
