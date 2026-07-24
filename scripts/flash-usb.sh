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
# shellcheck source=scripts/usb-ssh-common.sh
source "$ROOT/scripts/usb-ssh-common.sh"
ACTION="${1:-}"
SIZE_HELPER="$ROOT/scripts/artifact-size.sh"

UPGRADE_TOOL_DIR="$ROOT/tools/upgrade_tool"
UPGRADE_TOOL="$UPGRADE_TOOL_DIR/upgrade_tool"
SDK="$ROOT/linux-sdk"
LWS_FIRMWARE_DIR="$ROOT/output/firmware"
SDK_FIRMWARE_DIR="$SDK/output/firmware"
UPDATE_IMG="${UPDATE_IMG:-${LWS_HMI_UPDATE_IMG:-${IMAGE:-$LWS_FIRMWARE_DIR/update.img}}}"
if [[ "$ACTION" == upgrade || "$ACTION" == uf || "$ACTION" == update ]] && [[ -n "${2:-}" ]]; then
  UPDATE_IMG="$2"
fi
LOADER_BIN="${LWS_HMI_LOADER:-}"
LOADER_CACHE_DIR="$ROOT/output/firmware/.loader-cache"

# SN preferred; SERIAL= deprecated alias. CHIPID= matches ChipID only.
SN="$(device_select_sn)"
CHIPID="$(device_select_chipid)"
# Working token for RockUSB/adb row match (CHIPID wins when set).
SERIAL="${CHIPID:-$SN}"
IP="${IP:-${LWS_HMI_IP:-}}"
LOADER_NORESET="${LOADER_NORESET:-}"
UPGRADE_NORESET="${UPGRADE_NORESET:-}"
BOOTLOADER_WAIT_SEC="${BOOTLOADER_WAIT_SEC:-60}"
LOADER_WAIT_SEC="${LOADER_WAIT_SEC:-90}"
UPGRADE_TOOL_LOCATION=""
ROCKUSB_LIST_OUTPUT=""

usage() {
  cat <<EOF
Usage: $0 {devices|reboot|reboot-loader|loader|upgrade|flash}

  devices        List connected devices (RockUSB + USB-SSH + USB-MTP + SSH; MODE column)
                 (Android emulators omitted)
  reboot         Linux board (USB-SSH or SSH) → reboot; Android → adb reboot
  reboot-loader  Linux board (USB-SSH only) → reboot-loader; Android → adb reboot loader
                 (Android emulator not supported)
  loader         upgrade_tool ul <MiniLoaderAll.bin>  [LOADER_NORESET=1]  (macOS)
  upgrade        upgrade_tool uf <update.img>        [UPGRADE_NORESET=1] (macOS)
  flash          uf update.img; ul first when RockUSB mode is Maskrom (macOS)
                 (Android emulator not supported)
  flash-android  flash with Innohi Android image (optional; not required before Linux)
                 (Android emulator not supported)

Selection: SN / CHIPID / IP (SSH registry only) / IFACE (USB-SSH)
App deploy (no reflash): make build-app && make push-app
Linux HMI → Loader: make reboot-loader
MaskROM Linux:  make flash (macOS)
RockUSB Loader: make flash (macOS; skips ul automatically)
MaskROM Android: make flash-android (macOS)
Image override: make flash IMAGE=/path/to/update.img
EOF
}

resolve_loader_bin() {
  if [[ -n "$LOADER_BIN" && -r "$LOADER_BIN" ]]; then
    return 0
  fi

  if [[ ! -r "$UPDATE_IMG" ]]; then
    LOADER_BIN="$SDK_FIRMWARE_DIR/MiniLoaderAll.bin"
    return 0
  fi

  local sfi line offset size skip count out hash
  mkdir -p "$LOADER_CACHE_DIR"
  hash="$(md5 -q "$UPDATE_IMG" 2>/dev/null || stat -f '%m-%z' "$UPDATE_IMG")"
  out="$LOADER_CACHE_DIR/${hash}.MiniLoaderAll.bin"
  if [[ -r "$out" ]]; then
    LOADER_BIN="$out"
    return 0
  fi

  sfi="$(cd "$UPGRADE_TOOL_DIR" && "$UPGRADE_TOOL" SFI "$UPDATE_IMG" 2>&1 | grep -v '^Using ')"
  line="$(grep -i MiniLoaderAll <<<"$sfi" | head -1 || true)"
  offset="$(grep -oE 'offset=0x[0-9a-fA-F]+' <<<"$line" | head -1 | cut -d= -f2)"
  size="$(grep -oE 'size=0x[0-9a-fA-F]+' <<<"$line" | head -1 | cut -d= -f2)"
  if [[ -z "$offset" || -z "$size" ]]; then
    echo "WARNING: cannot parse MiniLoaderAll from update.img; using SDK loader" >&2
    LOADER_BIN="$SDK_FIRMWARE_DIR/MiniLoaderAll.bin"
    return 0
  fi

  skip=$((offset))
  count=$((size))
  dd if="$UPDATE_IMG" of="$out" bs=1 skip="$skip" count="$count" status=none 2>/dev/null \
    || die "failed to extract MiniLoaderAll from $UPDATE_IMG"
  LOADER_BIN="$out"
  echo "Loader from update.img:"
  bash "$SIZE_HELPER" "$LOADER_BIN"
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# Reject SN=emulator-* for flash / reboot-loader (physical board only).
reject_android_emulator_target() {
  local action="$1"
  local serial="${SERIAL:-}"
  if [[ -n "$serial" ]] && is_android_emulator_serial "$serial"; then
    die "Android emulator ($serial) is not supported for $action (physical board only; see make devices)"
  fi
}

require_macos() {
  [[ "$(uname -s)" == Darwin ]] || die "USB flash is supported on macOS only (use make reboot-loader on Linux to enter RockUSB Loader)"
}

upgrade_tool_available() {
  [[ -f "$UPGRADE_TOOL" ]] || return 1
  [[ -x "$UPGRADE_TOOL" ]] || chmod +x "$UPGRADE_TOOL" 2>/dev/null || true
  [[ -x "$UPGRADE_TOOL" ]] || return 1
  case "$(uname -s)" in
  Darwin) file "$UPGRADE_TOOL" 2>/dev/null | grep -q "Mach-O" ;;
  Linux) file "$UPGRADE_TOOL" 2>/dev/null | grep -qE "ELF|executable" ;;
  *) return 1 ;;
  esac
}

linux_rockusb_usb_count() {
  command -v lsusb >/dev/null 2>&1 || { echo 0; return; }
  lsusb 2>/dev/null | grep -cE '2207:' || echo 0
}

host_rockusb_count() {
  local out count
  if upgrade_tool_available; then
    out="$(rockusb_list_output)"
    count="$(rockusb_connected_count "$out")"
    echo "$count"
    return 0
  fi
  if [[ "$(uname -s)" == Linux ]]; then
    linux_rockusb_usb_count
    return 0
  fi
  echo 0
}

ensure_upgrade_tool() {
  upgrade_tool_available || die "upgrade_tool not found or wrong host OS: $UPGRADE_TOOL"
}

ensure_readable() {
  local path="$1" label="$2"
  [[ -r "$path" ]] || die "$label not readable: $path (run: make build-img — exports firmware to host automatically on macOS Docker)"
}

rockusb_list_output() {
  upgrade_tool_available || return 0
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

# Rows: MODE, SN, ChipID, LocationID, IFACE, IP, USB (fields separated by FS)
DEVICE_TABLE_FS=$'\t'
declare -a DEVICE_TABLE_ROWS=()

device_table_add() {
  DEVICE_TABLE_ROWS+=("${1}${DEVICE_TABLE_FS}${2}${DEVICE_TABLE_FS}${3}${DEVICE_TABLE_FS}${4}${DEVICE_TABLE_FS}${5}${DEVICE_TABLE_FS}${6}${DEVICE_TABLE_FS}${7}")
}

device_table_print() {
  local w_mode=4 w_sn=2 w_chip=6 w_loc=10 w_iface=5 w_ip=2 w_usb=3
  local row mode sn chip loc iface ip usb
  local -a modes=() sns=() chips=() locs=() ifaces=() ips=() usbs=()

  if [[ ${#DEVICE_TABLE_ROWS[@]} -eq 0 ]]; then
    printf '%s\n' "MODE  SN  ChipID  LocationID  IFACE  IP  USB"
    printf '%s\n' "(none)"
    return 0
  fi

  for row in "${DEVICE_TABLE_ROWS[@]}"; do
    IFS="$DEVICE_TABLE_FS" read -r mode sn chip loc iface ip usb <<<"$row"
    modes+=("$mode")
    sns+=("$sn")
    chips+=("$chip")
    locs+=("$loc")
    ifaces+=("$iface")
    ips+=("$ip")
    usbs+=("$usb")
    (( ${#mode} > w_mode )) && w_mode=${#mode}
    (( ${#sn} > w_sn )) && w_sn=${#sn}
    (( ${#chip} > w_chip )) && w_chip=${#chip}
    (( ${#loc} > w_loc )) && w_loc=${#loc}
    (( ${#iface} > w_iface )) && w_iface=${#iface}
    (( ${#ip} > w_ip )) && w_ip=${#ip}
    (( ${#usb} > w_usb )) && w_usb=${#usb}
  done
  (( w_mode < 4 )) && w_mode=4
  (( w_sn < 2 )) && w_sn=2
  (( w_chip < 6 )) && w_chip=6
  (( w_loc < 10 )) && w_loc=10
  (( w_iface < 5 )) && w_iface=5
  (( w_ip < 2 )) && w_ip=2
  (( w_usb < 3 )) && w_usb=3

  local sep_mode sep_sn sep_chip sep_loc sep_iface sep_ip sep_usb i
  sep_mode="$(printf '%*s' "$w_mode" '' | tr ' ' '-')"
  sep_sn="$(printf '%*s' "$w_sn" '' | tr ' ' '-')"
  sep_chip="$(printf '%*s' "$w_chip" '' | tr ' ' '-')"
  sep_loc="$(printf '%*s' "$w_loc" '' | tr ' ' '-')"
  sep_iface="$(printf '%*s' "$w_iface" '' | tr ' ' '-')"
  sep_ip="$(printf '%*s' "$w_ip" '' | tr ' ' '-')"
  sep_usb="$(printf '%*s' "$w_usb" '' | tr ' ' '-')"

  printf "%-${w_mode}s  %-${w_sn}s  %-${w_chip}s  %-${w_loc}s  %-${w_iface}s  %-${w_ip}s  %-${w_usb}s\n" \
    MODE SN ChipID LocationID IFACE IP USB
  printf "%-${w_mode}s  %-${w_sn}s  %-${w_chip}s  %-${w_loc}s  %-${w_iface}s  %-${w_ip}s  %-${w_usb}s\n" \
    "$sep_mode" "$sep_sn" "$sep_chip" "$sep_loc" "$sep_iface" "$sep_ip" "$sep_usb"
  for i in "${!modes[@]}"; do
    printf "%-${w_mode}s  %-${w_sn}s  %-${w_chip}s  %-${w_loc}s  %-${w_iface}s  %-${w_ip}s  %-${w_usb}s\n" \
      "${modes[$i]}" "${sns[$i]}" "${chips[$i]}" "${locs[$i]}" "${ifaces[$i]}" "${ips[$i]}" "${usbs[$i]}"
  done
}

list_devices() {
  local out line mode serial loc iface addr usb state row chip

  DEVICE_TABLE_ROWS=()

  if command -v adb >/dev/null 2>&1; then
    if [[ -n "$SERIAL" ]] && ! is_android_emulator_serial "$SERIAL"; then
      adb connect "$SERIAL" >/dev/null 2>&1 || true
    fi
    while read -r serial state _; do
      [[ -z "$serial" ]] && continue
      is_android_emulator_serial "$serial" && continue
      case "$state" in
        device) mode=android ;;
        *) mode="$state" ;;
      esac
      # adb serial is the chip identity; SN matches ChipID on Android.
      device_table_add "$mode" "$serial" "$serial" "-" "-" "-" "-"
    done < <(adb devices 2>/dev/null | awk 'NR>1 && NF {print $1, $2}')
  fi

  if upgrade_tool_available; then
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
      # Loader SerialNo is chip identity; SN matches ChipID in RockUSB.
      device_table_add "$mode" "$serial" "$serial" "$loc" "-" "-" "$usb"
    done < <(grep -E 'DevNo=[0-9]+' <<<"$out" || true)
  fi

  while IFS=$'\t' read -r mode serial chip loc iface addr usb; do
    [[ -n "$mode" ]] || continue
    [[ -n "${chip:-}" ]] || chip="$serial"
    device_table_add "$mode" "$serial" "$chip" "$loc" "$iface" "$addr" "$usb"
  done < <(bash "$ROOT/scripts/usb-ssh-devices.sh" --tsv 2>/dev/null || true)

  while IFS=$'\t' read -r mode serial chip loc iface addr usb; do
    [[ -n "$mode" ]] || continue
    [[ -n "${chip:-}" ]] || chip="$serial"
    device_table_add "$mode" "$serial" "$chip" "$loc" "$iface" "$addr" "$usb"
  done < <(bash "$ROOT/scripts/ssh-devices.sh" --tsv 2>/dev/null || true)

  device_table_print
  warn_sshpass_if_usb_ssh "$(( $(usb_ssh_device_count) + $(ssh_registry_device_count) ))"
}

resolve_upgrade_tool_location() {
  local out="$1" count line
  count="$(rockusb_connected_count "$out")"
  ROCKUSB_COUNT="$count"
  [[ "$count" -gt 0 ]] || return 1

  # upgrade_tool v2.44 segfaults on macOS when -s is used with a single device.
  if [[ "$count" -eq 1 ]]; then
    UPGRADE_TOOL_LOCATION=""
    return 0
  fi

  if [[ -n "$SERIAL" ]]; then
    while read -r line; do
      parse_rockusb_line "$line"
      [[ "$_SERIAL" == "$SERIAL" ]] || continue
      UPGRADE_TOOL_LOCATION="$_LOCATION"
      return 0
    done < <(grep -E 'DevNo=[0-9]+' <<<"$out")
    die "SN=$SERIAL not found (make devices)"
  fi

  die "$count RockUSB devices — set SN= (make devices)"
}

upgrade_tool_cmd() {
  if [[ -n "$UPGRADE_TOOL_LOCATION" ]]; then
    echo "upgrade_tool -s $UPGRADE_TOOL_LOCATION $*"
    (cd "$UPGRADE_TOOL_DIR" && "$UPGRADE_TOOL" -s "$UPGRADE_TOOL_LOCATION" "$@")
  else
    echo "upgrade_tool $*"
    (cd "$UPGRADE_TOOL_DIR" && "$UPGRADE_TOOL" "$@")
  fi
}

require_rockusb_device() {
  local out count
  out="$(rockusb_list_output)"
  ROCKUSB_LIST_OUTPUT="$out"
  count="$(rockusb_connected_count "$out")"
  [[ "$count" -gt 0 ]] || die "No RockUSB device (upgrade_tool ld). Use make reboot-loader or MaskROM."
  resolve_upgrade_tool_location "$out"
}

resolve_selected_rockusb_mode() {
  local out="$1" count line
  count="$(rockusb_connected_count "$out")"
  while read -r line; do
    parse_rockusb_line "$line"
    [[ -n "$_DEVNO" ]] || continue
    if [[ "$count" -gt 1 ]]; then
      if [[ -n "$UPGRADE_TOOL_LOCATION" ]]; then
        [[ "$_LOCATION" == "$UPGRADE_TOOL_LOCATION" ]] || continue
      elif [[ -n "$SERIAL" ]]; then
        [[ "$_SERIAL" == "$SERIAL" ]] || continue
      else
        die "$count RockUSB devices — set SN= (make devices)"
      fi
    fi
    printf '%s\n' "${_MODE:-RockUSB}"
    return 0
  done < <(grep -E 'DevNo=[0-9]+' <<<"$out")
  return 1
}

rockusb_mode_needs_loader() {
  case "$1" in
    Maskrom|maskrom) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_adb() {
  command -v adb >/dev/null 2>&1 || die "adb not found"
}

resolve_adb_serial() {
  local lines=() count serial
  if [[ -n "$SERIAL" ]]; then
    adb connect "$SERIAL" >/dev/null 2>&1 || true
    echo "$SERIAL"
    return 0
  fi
  while IFS= read -r serial; do
    [[ -n "$serial" ]] || continue
    is_android_emulator_serial "$serial" && continue
    lines+=("$serial")
  done < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
  count="${#lines[@]}"
  [[ "$count" -gt 0 ]] || die "No adb device (set SN=)"
  [[ "$count" -eq 1 ]] || die "Multiple adb devices (set SN=)"
  echo "${lines[0]}"
}

reboot_to_rockusb_loader() {
  local serial="$1"
  echo "adb -s $serial reboot loader"
  adb -s "$serial" reboot loader 2>/dev/null \
    || adb -s "$serial" shell reboot loader 2>/dev/null \
    || die "adb reboot loader failed"
}

rockusb_already_ready() {
  local count line out
  count="$(host_rockusb_count)"
  [[ "$count" -gt 0 ]] || return 1
  if [[ -z "$SERIAL" ]]; then
    return 0
  fi
  if ! upgrade_tool_available; then
    return 0
  fi
  out="$(rockusb_list_output)"
  while read -r line; do
    parse_rockusb_line "$line"
    [[ -n "$_DEVNO" ]] || continue
    [[ "$_SERIAL" == "$SERIAL" ]] && return 0
  done < <(grep -E 'DevNo=[0-9]+' <<<"$out" || true)
  return 1
}

reboot_to_adb() {
  local serial="$1"
  echo "adb -s $serial reboot"
  adb -s "$serial" reboot 2>/dev/null \
    || die "adb reboot failed"
}

adb_android_device_count() {
  # Physical adb only — Android emulators (emulator-*) are excluded.
  command -v adb >/dev/null 2>&1 || { echo 0; return; }
  adb devices 2>/dev/null |
    awk 'NR>1 && $2=="device" && $1 !~ /^emulator-/ {n++} END{print n+0}'
}

adb_emulator_device_count() {
  command -v adb >/dev/null 2>&1 || { echo 0; return; }
  adb devices 2>/dev/null |
    awk 'NR>1 && $2=="device" && $1 ~ /^emulator-/ {n++} END{print n+0}'
}

usb_ssh_device_count() {
  bash "$ROOT/scripts/usb-ssh-devices.sh" --tsv 2>/dev/null \
    | awk -F'\t' '$1=="USB-SSH"{n++} END{print n+0}'
}

ssh_registry_device_count() {
  bash "$ROOT/scripts/ssh-devices.sh" --tsv 2>/dev/null \
    | awk -F'\t' '$1=="SSH"{n++} END{print n+0}'
}

# Select USB-SSH or registered SSH. Prints: TRANSPORT, IFACE, IP
select_linux_ssh_target() {
  local -a sel=() sel_out="" err_file
  err_file="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$err_file'" RETURN

  if ! sel_out="$(
    SN="$SN" CHIPID="$CHIPID" SERIAL="$SERIAL" IP="$IP" IFACE="${IFACE:-${LWS_HMI_USB_IFACE:-}}" \
      bash "$ROOT/scripts/device-target.sh" --select 2>"$err_file"
  )"; then
    [[ -s "$err_file" ]] && cat "$err_file" >&2
    die "could not select Linux board (run make devices)"
  fi
  while IFS= read -r line; do
    [[ -n "$line" ]] && sel+=("$line")
  done <<<"$sel_out"
  [[ ${#sel[@]} -eq 4 ]] || die "bad device selection (${#sel[@]} fields, expected 4)"
  printf '%s\n' "${sel[0]}" "${sel[2]}" "${sel[3]}"
}

usb_ssh_select_iface() {
  local -a sel=() sel_out="" err_file
  err_file="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$err_file'" RETURN

  if ! sel_out="$(
    SN="$SN" CHIPID="$CHIPID" SERIAL="$SERIAL" IFACE="${IFACE:-${LWS_HMI_USB_IFACE:-}}" \
      bash "$ROOT/scripts/usb-ssh-devices.sh" --select 2>"$err_file"
  )"; then
    [[ -s "$err_file" ]] && cat "$err_file" >&2
    die "USB-SSH: could not select Linux board (run make devices)"
  fi
  while IFS= read -r line; do
    [[ -n "$line" ]] && sel+=("$line")
  done <<<"$sel_out"
  [[ ${#sel[@]} -eq 3 ]] || die "USB-SSH: bad device selection (${#sel[@]} fields, expected 3)"
  printf '%s\n' "${sel[1]}"
}

run_linux_ssh_reboot() {
  local -a sel=()
  local transport iface addr
  while IFS= read -r line; do
    [[ -n "$line" ]] && sel+=("$line")
  done < <(select_linux_ssh_target)
  [[ ${#sel[@]} -eq 3 ]] || die "bad reboot target selection"
  transport="${sel[0]}"
  iface="${sel[1]}"
  addr="${sel[2]}"
  case "$transport" in
  usb-ssh)
    echo "Linux board via USB-SSH (iface=$iface) → reboot"
    usb_ssh_schedule_sysrq_reboot "$iface"
    ;;
  ssh)
    echo "Linux board via SSH ($addr) → reboot"
    remote_ssh_schedule_sysrq_reboot "$addr"
    ;;
  *)
    die "unsupported transport for reboot: $transport"
    ;;
  esac
  bash "$ROOT/scripts/ssh-devices.sh" dismiss-target \
    "$transport" "$iface" "$addr" || true
  echo "Reboot triggered."
}

run_usb_ssh_reboot_loader() {
  local iface
  iface="$(usb_ssh_select_iface)"
  echo "Linux board via USB-SSH (iface=$iface) → RockUSB Loader"
  usb_ssh_schedule_remote "$iface" "exec /usr/bin/reboot-loader"
  bash "$ROOT/scripts/ssh-devices.sh" dismiss-target \
    usb-ssh "$iface" "${LWS_HMI_USB_SSH_ADDR:-192.168.55.1}" || true
  wait_for_rockusb
  echo "RockUSB ready (via USB-SSH reboot-loader)."
}

run_reboot() {
  local n_usb n_ssh n_adb

  n_usb="$(usb_ssh_device_count)"
  n_ssh="$(ssh_registry_device_count)"
  if [[ "$n_usb" -gt 0 || "$n_ssh" -gt 0 ]]; then
    run_linux_ssh_reboot
    return 0
  fi

  n_adb="$(adb_android_device_count)"
  if [[ "$n_adb" -gt 0 ]]; then
    ensure_adb
    reboot_to_adb "$(resolve_adb_serial)"
    return 0
  fi

  die "No device for reboot. Linux: plug USB OTG or make connect <ip>. Android: connect adb."
}

run_reboot_loader() {
  local n_ssh n_adb n_reg n_emu

  reject_android_emulator_target "reboot-loader"

  if rockusb_already_ready; then
    echo "RockUSB Loader already connected."
    wait_for_rockusb
    return 0
  fi

  n_ssh="$(usb_ssh_device_count)"
  if [[ "$n_ssh" -gt 0 ]]; then
    run_usb_ssh_reboot_loader
    return 0
  fi

  # Android board only — Linux HMI has no adbd. Emulators are not supported.
  n_adb="$(adb_android_device_count)"
  if [[ "$n_adb" -gt 0 ]]; then
    ensure_adb
    reboot_to_rockusb_loader "$(resolve_adb_serial)"
    wait_for_rockusb
    echo "RockUSB ready (via adb reboot loader)."
    return 0
  fi

  n_emu="$(adb_emulator_device_count)"
  if [[ "$n_emu" -gt 0 ]]; then
    die "Android emulator is not supported for reboot-loader (physical board only; see make devices)"
  fi

  n_reg="$(ssh_registry_device_count)"
  if [[ "$n_reg" -gt 0 ]]; then
    die "reboot-loader requires USB-SSH (not registered SSH). Plug OTG, or enter MaskROM/Loader manually."
  fi

  die "No device for reboot-loader. Linux board: plug USB OTG, then make devices. Android: connect adb. Or enter MaskROM/Loader manually."
}

wait_for_rockusb() {
  local i count max="${1:-$BOOTLOADER_WAIT_SEC}" hint="RockUSB"
  if upgrade_tool_available; then
    hint="upgrade_tool ld"
  elif [[ "$(uname -s)" == Linux ]]; then
    hint="lsusb (Rockchip 2207)"
  fi
  for ((i = 1; i <= max; i++)); do
    count="$(host_rockusb_count)"
    if [[ "$count" -gt 0 ]]; then
      echo "RockUSB ready (${count} device(s))."
      return 0
    fi
    if (( i == 1 || i % 5 == 0 )); then
      echo "Waiting for RockUSB... (${i}s)"
    fi
    sleep 1
  done
  die "Timed out waiting for RockUSB ($hint). Re-enter MaskROM or Loader, then retry."
}

run_loader() {
  local -a args=(ul "$LOADER_BIN")
  ensure_upgrade_tool
  resolve_loader_bin
  ensure_readable "$LOADER_BIN" "LOADER"
  echo "LOADER:"
  bash "$SIZE_HELPER" "$LOADER_BIN"
  require_rockusb_device
  [[ "$LOADER_NORESET" == 1 ]] && args+=(-noreset)
  upgrade_tool_cmd "${args[@]}"
  if [[ "$LOADER_NORESET" == 1 ]]; then
    echo "Loader written (no reset)."
    return 0
  fi
  echo "Loader written — device rebooting; waiting for RockUSB..."
  sleep 3
  wait_for_rockusb "$LOADER_WAIT_SEC"
}

run_upgrade() {
  local -a args=(uf "$UPDATE_IMG")
  ensure_upgrade_tool
  ensure_readable "$UPDATE_IMG" "UPDATE_IMG"
  echo "UPDATE_IMG:"
  bash "$SIZE_HELPER" "$UPDATE_IMG"
  require_rockusb_device
  [[ "$UPGRADE_NORESET" == 1 ]] && args+=(-noreset)
  upgrade_tool_cmd "${args[@]}"
}

upgrade_tool_reset_after_flash() {
  # After uf/di the device often reboots and drops USB before rd completes.
  if upgrade_tool_cmd rd; then
    echo "Device reset."
    return 0
  fi
  echo "NOTE: reset after flash failed (device may have already rebooted — check boot)."
  return 0
}

run_flash() {
  local mode rock_n emu_n
  reject_android_emulator_target "flash"
  ensure_upgrade_tool
  ensure_readable "$UPDATE_IMG" "UPDATE_IMG"
  echo "UPDATE_IMG:"
  bash "$SIZE_HELPER" "$UPDATE_IMG"
  rock_n="$(host_rockusb_count)"
  if [[ "$rock_n" -eq 0 ]]; then
    emu_n="$(adb_emulator_device_count)"
    if [[ "$emu_n" -gt 0 ]]; then
      die "Android emulator is not supported for flash (physical RockUSB board only; see make devices)"
    fi
  fi
  require_rockusb_device
  mode="$(resolve_selected_rockusb_mode "$ROCKUSB_LIST_OUTPUT")" \
    || die "could not detect RockUSB mode (make devices)"

  if rockusb_mode_needs_loader "$mode"; then
    resolve_loader_bin
    echo "RockUSB: $mode — flash loader + $(basename "$UPDATE_IMG")"
    LOADER_NORESET=1 run_loader
    run_upgrade
  else
    echo "RockUSB: $mode — flash $(basename "$UPDATE_IMG") only"
    run_upgrade
  fi
}

case "$ACTION" in
  ""|-h|--help|help) usage; exit 0 ;;
esac

case "$ACTION" in
  devices|ld) list_devices ;;
  reboot)
    run_reboot
    ;;
  reboot-loader)
    run_reboot_loader
    ;;
  loader|ul)
    require_macos
    run_loader
    ;;
  upgrade|uf|update)
    require_macos
    run_upgrade
    ;;
  flash)
    require_macos
    run_flash
    ;;
  *) die "Unknown action: $ACTION" ;;
esac
