#!/bin/sh
# Publish or withdraw _lws-device._tcp via avahi-publish-service.
# Used by the HMI App (DeviceMdnsAdvertise) and for manual smoke checks.
#
# Usage:
#   device-mdns-advertise.sh publish <sn> <model> <system_version> [port]
#   device-mdns-advertise.sh withdraw
#
# Browse verification (same LAN):
#   avahi-browse -r _lws-device._tcp
set -eu

CMD="${1:-}"
case "$CMD" in
  publish)
    SN="${2:?sn required}"
    MODEL="${3:?model required}"
    VER="${4:?system_version required}"
    PORT="${5:-5580}"
    INSTANCE="$SN"
    exec avahi-publish-service -s "$INSTANCE" _lws-device._tcp "$PORT" \
      "sn=$SN" \
      "model=$MODEL" \
      "system_version=$VER" \
      "api_ver=1" \
      "connect_proto=http"
    ;;
  withdraw)
    # App owns the avahi-publish-service child; host helper is a no-op marker.
    echo "withdraw: stop the avahi-publish-service process started by publish" >&2
    exit 0
    ;;
  *)
    echo "usage: $0 publish <sn> <model> <system_version> [port]" >&2
    echo "       $0 withdraw" >&2
    exit 2
    ;;
esac
