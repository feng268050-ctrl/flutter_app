#!/usr/bin/env bash
# Fail if local linux-sdk/ violates board/linux-sdk-whitelist.txt.
# Usage: make check-linux-sdk
#        SDK=… bash scripts/check-linux-sdk-whitelist.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-${SDK:-$ROOT/linux-sdk}}"
WHITELIST="${WHITELIST:-$ROOT/board/linux-sdk-whitelist.txt}"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -f "$WHITELIST" ]] || die "missing whitelist: $WHITELIST"
[[ -d "$SDK" ]] || die "linux-sdk missing: $SDK"

fail=0
warn=0
soft_max=""

echo "check-linux-sdk: SDK=$SDK"
echo "check-linux-sdk: whitelist=$WHITELIST"

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" ]] && continue
  key="${line%%=*}"
  val="${line#*=}"
  case "$key" in
    FORBID_TOP)
      if [[ -e "$SDK/$val" ]]; then
        echo "FAIL: forbidden top-level present: $val" >&2
        fail=1
      fi
      ;;
    FORBID_PATH)
      if [[ -e "$SDK/$val" ]]; then
        echo "FAIL: forbidden path present: $val" >&2
        fail=1
      fi
      ;;
    REQUIRE_TOP)
      if [[ ! -e "$SDK/$val" ]]; then
        echo "FAIL: required path missing: $val" >&2
        fail=1
      fi
      ;;
    SOFT_MAX_GIB)
      soft_max="$val"
      ;;
  esac
done < "$WHITELIST"

echo "--- size (excluding buildroot/dl, buildroot/output, output; soft-max excludes prebuilts) ---"
total_kb=0
prebuilts_kb=0
for d in buildroot kernel-6.1 kernel device rkbin external tools u-boot innohi prebuilts; do
  [[ -e "$SDK/$d" ]] || continue
  if [[ "$d" == "buildroot" ]]; then
    br_total=$(du -sk "$SDK/buildroot" 2>/dev/null | awk '{print $1}')
    br_dl=0
    br_out=0
    [[ -d "$SDK/buildroot/dl" ]] && br_dl=$(du -sk "$SDK/buildroot/dl" 2>/dev/null | awk '{print $1}')
    [[ -d "$SDK/buildroot/output" ]] && br_out=$(du -sk "$SDK/buildroot/output" 2>/dev/null | awk '{print $1}')
    kb=$((br_total - br_dl - br_out))
    [[ "$kb" -lt 0 ]] && kb=0
  else
    kb=$(du -sk "$SDK/$d" 2>/dev/null | awk '{print $1}')
  fi
  [[ -n "$kb" ]] || kb=0
  if [[ "$d" == "prebuilts" ]]; then
    prebuilts_kb=$kb
  else
    total_kb=$((total_kb + kb))
  fi
  printf "  %6d MiB  %s\n" "$((kb / 1024))" "$d"
done
total_gib=$(awk -v kb="$total_kb" 'BEGIN { printf "%.2f", kb/1024/1024 }')
pre_gib=$(awk -v kb="$prebuilts_kb" 'BEGIN { printf "%.2f", kb/1024/1024 }')
echo "  TOTAL ~${total_gib} GiB (source band, excl. prebuilts)"
echo "  prebuilts ~${pre_gib} GiB (toolchain cache; excluded from soft max)"
if [[ -n "$soft_max" ]]; then
  over=$(awk -v t="$total_gib" -v m="$soft_max" 'BEGIN { print (t > m+0) ? 1 : 0 }')
  if [[ "$over" == "1" ]]; then
    echo "WARN: source size ${total_gib} GiB exceeds soft max ${soft_max} GiB" >&2
    warn=1
  fi
fi

if [[ "$fail" -ne 0 ]]; then
  echo "check-linux-sdk: FAILED" >&2
  exit 1
fi
if [[ "$warn" -ne 0 ]]; then
  echo "check-linux-sdk: OK (with warnings)"
else
  echo "check-linux-sdk: OK"
fi
exit 0
