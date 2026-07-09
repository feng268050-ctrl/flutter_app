#!/usr/bin/env bash
# Rockchip upgrade_tool wrapper (命令行开发工具使用文档.pdf).
#
#   ld              list RockUSB (Loader / Maskrom)
#   ul [loader]     §1.3 flash loader (Loader or Maskrom)
#   uf [update.img] §1.6 flash firmware (Loader or Maskrom)
#   -s LocationID   §1.11 select device (multi-device)
#
#   adb reboot loader → RockUSB Loader (not Android `reboot bootloader`)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTION="${1:-}"

UPGRADE_TOOL_DIR="$ROOT/tools/upgrade_tool"
UPGRADE_TOOL="$UPGRADE_TOOL_DIR/upgrade_tool"
SDK="$(bash "$ROOT/scripts/link-sdk.sh" --print)"
FIRMWARE_DIR="$SDK/output/firmware"
UPDATE_IMG="${UPDATE_IMG:-${LWS_HMI_UPDATE_IMG:-$FIRMWARE_DIR/update.img}}"
if [[ "$ACTION" == upgrade || "$ACTION" == uf || "$ACTION" == update ]] && [[ -n "${2:-}" ]]; then
  UPDATE_IMG="$2"
fi
LOADER_BIN="${LWS_HMI_LOADER:-$FIRMWARE_DIR/MiniLoaderAll.bin}"

SERIAL="${SERIAL:-${LWS_HMI_SERIAL:-}}"
LOADER_NORESET="${LOADER_NORESET:-}"
UPGRADE_NORESET="${UPGRADE_NORESET:-}"
BOOTLOADER_WAIT_SEC="${BOOTLOADER_WAIT_SEC:-60}"
UPGRADE_TOOL_LOCATION=""

usage() {
  cat <<EOF
Usage: $0 {devices|bootloader|loader|upgrade}

  devices      List connected devices (mode column)
  bootloader   adb reboot loader
  loader       upgrade_tool ul <MiniLoaderAll.bin>  [LOADER_NORESET=1]
  upgrade      upgrade_tool uf <update.img>        [UPGRADE_NORESET=1]

Selection: SERIAL
Image:      make upgrade IMAGE=/path/to/update.img
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_macos() {
  [[ "$(uname -s)" == Darwin ]] || die "USB flash is supported on macOS only"
}

ensure_upgrade_tool() {
  [[ -f "$UPGRADE_TOOL" ]] || die "upgrade_tool not found: $UPGRADE_TOOL"
  [[ -x "$UPGRADE_TOOL" ]] || chmod +x "$UPGRADE_TOOL"
}

maybe_pull_from_docker_volume() {
  [[ "$(uname -s)" == Darwin ]] || return 0
  local volume="${LWS_HMI_DOCKER_VOLUME:-lws-hmi-sdk}"
  docker volume inspect "$volume" >/dev/null 2>&1 || return 0
  bash "$ROOT/scripts/docker-volume.sh" pull
}

ensure_readable() {
  local path="$1" label="$2"
  maybe_pull_from_docker_volume
  [[ -r "$path" ]] || die "$label not readable: $path"
}

rockusb_list_output() {
  ensure_upgrade_tool
  (cd "$UPGRADE_TOOL_DIR" && "$UPGRADE_TOOL" ld) 2>&1 \
    | grep -v '^Using ' || true
}

rockusb_connected_count() {
  local out="$1"
  if [[ "$out" =~ connected\(([0-9]+)\) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo 0
  fi
}

parse_rockusb_line() {
  local line="$1"
  _DEVNO="$(sed -n 's/.*DevNo=\([0-9][0-9]*\).*/\1/p' <<<"$line")"
  _VID="$(sed -n 's/.*Vid=0x\([0-9a-fA-F]*\).*/\1/p' <<<"$line")"
  _PID="$(sed -n 's/.*Pid=0x\([0-9a-fA-F]*\).*/\1/p' <<<"$line")"
  _LOCATION="$(sed -n 's/.*LocationID=\([0-9a-fA-F]*\).*/\1/p' <<<"$line")"
  _MODE="$(sed -n 's/.*Mode=\([^[:space:]]*\).*/\1/p' <<<"$line")"
  _SERIAL="$(sed -n 's/.*SerialNo=\([^[:space:]]*\).*/\1/p' <<<"$line")"
}

# Rows: MODE, SERIAL, LocationID, USB (fields separated by FS)
DEVICE_TABLE_FS=$'\t'
declare -a DEVICE_TABLE_ROWS=()

device_table_add() {
  DEVICE_TABLE_ROWS+=("${1}${DEVICE_TABLE_FS}${2}${DEVICE_TABLE_FS}${3}${DEVICE_TABLE_FS}${4}")
}

device_table_print() {
  local w_mode=4 w_serial=6 w_loc=10 w_usb=3
  local row mode serial loc usb
  local -a modes=() serials=() locs=() usbs=()

  if [[ ${#DEVICE_TABLE_ROWS[@]} -eq 0 ]]; then
    printf '%s\n' "MODE  SERIAL  LocationID  USB"
    printf '%s\n' "(none)"
    return 0
  fi

  for row in "${DEVICE_TABLE_ROWS[@]}"; do
    IFS="$DEVICE_TABLE_FS" read -r mode serial loc usb <<<"$row"
    modes+=("$mode")
    serials+=("$serial")
    locs+=("$loc")
    usbs+=("$usb")
    (( ${#mode} > w_mode )) && w_mode=${#mode}
    (( ${#serial} > w_serial )) && w_serial=${#serial}
    (( ${#loc} > w_loc )) && w_loc=${#loc}
    (( ${#usb} > w_usb )) && w_usb=${#usb}
  done
  (( w_mode < 4 )) && w_mode=4
  (( w_serial < 6 )) && w_serial=6
  (( w_loc < 10 )) && w_loc=10
  (( w_usb < 3 )) && w_usb=3

  local sep_mode sep_serial sep_loc sep_usb i
  sep_mode="$(printf '%*s' "$w_mode" '' | tr ' ' '-')"
  sep_serial="$(printf '%*s' "$w_serial" '' | tr ' ' '-')"
  sep_loc="$(printf '%*s' "$w_loc" '' | tr ' ' '-')"
  sep_usb="$(printf '%*s' "$w_usb" '' | tr ' ' '-')"

  printf "%-${w_mode}s  %-${w_serial}s  %-${w_loc}s  %-${w_usb}s\n" \
    MODE SERIAL LocationID USB
  printf "%-${w_mode}s  %-${w_serial}s  %-${w_loc}s  %-${w_usb}s\n" \
    "$sep_mode" "$sep_serial" "$sep_loc" "$sep_usb"
  for i in "${!modes[@]}"; do
    printf "%-${w_mode}s  %-${w_serial}s  %-${w_loc}s  %-${w_usb}s\n" \
      "${modes[$i]}" "${serials[$i]}" "${locs[$i]}" "${usbs[$i]}"
  done
}

list_devices() {
  local out line mode serial loc usb state

  DEVICE_TABLE_ROWS=()

  if command -v adb >/dev/null 2>&1; then
    [[ -n "$SERIAL" ]] && adb connect "$SERIAL" >/dev/null 2>&1 || true
    while read -r serial state _; do
      [[ -z "$serial" ]] && continue
      case "$state" in
        device) mode=android ;;
        *) mode="$state" ;;
      esac
      device_table_add "$mode" "$serial" "-" "-"
    done < <(adb devices 2>/dev/null | awk 'NR>1 && NF {print $1, $2}')
  fi

  out="$(rockusb_list_output)"
  while read -r line; do
    parse_rockusb_line "$line"
    [[ -n "$_DEVNO" ]] || continue
    mode="${_MODE:-RockUSB}"
    serial="${_SERIAL:--}"
    loc="${_LOCATION:--}"
    if [[ -n "$_VID" && -n "$_PID" ]]; then
      usb="0x${_VID}:0x${_PID}"
    else
      usb="-"
    fi
    device_table_add "$mode" "$serial" "$loc" "$usb"
  done < <(grep -E 'DevNo=[0-9]+' <<<"$out" || true)

  device_table_print
}

resolve_upgrade_tool_location() {
  local out="$1" count line
  count="$(rockusb_connected_count "$out")"
  [[ "$count" -gt 0 ]] || return 1

  if [[ -n "$SERIAL" ]]; then
    while read -r line; do
      parse_rockusb_line "$line"
      [[ "$_SERIAL" == "$SERIAL" ]] || continue
      UPGRADE_TOOL_LOCATION="$_LOCATION"
      return 0
    done < <(grep -E 'DevNo=[0-9]+' <<<"$out")
    die "SERIAL=$SERIAL not found (make devices)"
  fi

  if [[ "$count" -eq 1 ]]; then
    line="$(grep -E 'DevNo=[0-9]+' <<<"$out" | head -1)"
    parse_rockusb_line "$line"
    UPGRADE_TOOL_LOCATION="$_LOCATION"
    [[ -n "$UPGRADE_TOOL_LOCATION" ]] || UPGRADE_TOOL_LOCATION="$_DEVNO"
    return 0
  fi

  die "$count RockUSB devices — set SERIAL (make devices)"
}

upgrade_tool_cmd() {
  if [[ -n "$UPGRADE_TOOL_LOCATION" ]]; then
    (cd "$UPGRADE_TOOL_DIR" && "$UPGRADE_TOOL" -s "$UPGRADE_TOOL_LOCATION" "$@")
  else
    (cd "$UPGRADE_TOOL_DIR" && "$UPGRADE_TOOL" "$@")
  fi
}

require_rockusb_device() {
  local out count
  out="$(rockusb_list_output)"
  count="$(rockusb_connected_count "$out")"
  [[ "$count" -gt 0 ]] || die "No RockUSB device (upgrade_tool ld). Use make bootloader or MaskROM."
  resolve_upgrade_tool_location "$out"
}

ensure_adb() {
  command -v adb >/dev/null 2>&1 || die "adb not found"
}

resolve_adb_serial() {
  local lines=() count
  if [[ -n "$SERIAL" ]]; then
    adb connect "$SERIAL" >/dev/null 2>&1 || true
    echo "$SERIAL"
    return 0
  fi
  while IFS= read -r serial; do
    [[ -n "$serial" ]] && lines+=("$serial")
  done < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
  count="${#lines[@]}"
  [[ "$count" -gt 0 ]] || die "No adb device (set SERIAL)"
  [[ "$count" -eq 1 ]] || die "Multiple adb devices (set SERIAL)"
  echo "${lines[0]}"
}

reboot_to_rockusb_loader() {
  local serial="$1"
  echo "adb -s $serial reboot loader"
  adb -s "$serial" reboot loader 2>/dev/null \
    || adb -s "$serial" shell reboot loader 2>/dev/null \
    || die "adb reboot loader failed"
}

wait_for_rockusb() {
  local i count
  for ((i = 1; i <= BOOTLOADER_WAIT_SEC; i++)); do
    count="$(rockusb_connected_count "$(rockusb_list_output)")"
    [[ "$count" -gt 0 ]] && return 0
    sleep 1
  done
  die "Timed out waiting for RockUSB (upgrade_tool ld)"
}

run_bootloader() {
  ensure_adb
  reboot_to_rockusb_loader "$(resolve_adb_serial)"
  wait_for_rockusb
  echo "RockUSB ready."
}

run_loader() {
  local -a args=(ul "$LOADER_BIN")
  ensure_upgrade_tool
  ensure_readable "$LOADER_BIN" "LOADER"
  require_rockusb_device
  [[ "$LOADER_NORESET" == 1 ]] && args+=(-noreset)
  echo "upgrade_tool ${args[*]}"
  upgrade_tool_cmd "${args[@]}"
}

run_upgrade() {
  local -a args=(uf "$UPDATE_IMG")
  ensure_upgrade_tool
  ensure_readable "$UPDATE_IMG" "UPDATE_IMG"
  require_rockusb_device
  [[ "$UPGRADE_NORESET" == 1 ]] && args+=(-noreset)
  echo "upgrade_tool ${args[*]}"
  upgrade_tool_cmd "${args[@]}"
}

case "$ACTION" in
  ""|-h|--help|help) usage; exit 0 ;;
esac

require_macos

case "$ACTION" in
  devices|ld) list_devices ;;
  bootloader|boot) run_bootloader ;;
  loader|ul) run_loader ;;
  upgrade|uf|update) run_upgrade ;;
  *) die "Unknown action: $ACTION" ;;
esac
