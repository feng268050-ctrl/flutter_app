#!/bin/bash -e

# Rockchip preflight probe (called from check-buildroot / check-debian / …).
#
# Board sets RK_NETWORK_CHECK=n (→ "# RK_NETWORK_CHECK is not set" in .config)
# for Docker/offline incremental builds. Only enforce when RK_NETWORK_CHECK=y.

SITE="${1:-www.baidu.com}"
SITE_NAME="${2:-$SITE}"
EXTRA_MSG="$3"

case "${RK_NETWORK_CHECK:-}" in
y | Y | 1) ;;
*)
	# Disabled / unset: skip curl + 5s soft-fail delay. Package fetches use
	# BR2 mirrors separately when a recipe actually needs a download.
	exit 0
	;;
esac

http_ok() {
	case "$1" in
		1*|2*|3*) return 0 ;;
		*) return 1 ;;
	esac
}

# HEAD first (fast). Some mirrors return 403 to HEAD on dirs but allow GET.
CODE="$(curl -I -s -m 10 -w "%{http_code}" -o /dev/null "$SITE" 2>/dev/null || echo 000)"
if http_ok "$CODE"; then
	exit 0
fi

# Byte-range GET works when HEAD is blocked (e.g. sources.buildroot.net root).
CODE="$(curl -s -m 10 -w "%{http_code}" -o /dev/null -r 0-0 "$SITE" 2>/dev/null || echo 000)"
if http_ok "$CODE"; then
	exit 0
fi

HOST="$(echo "$SITE" | sed -E 's#^https?://([^/]+).*#\1#')"
if ping "$HOST" -c 1 -W 1 &>/dev/null; then
	exit 0
fi

echo -e "\e[35m"
echo -e "Your network is not able to access $SITE_NAME!"
echo -e "$EXTRA_MSG"
echo "Set RK_NETWORK_CHECK=n in the board defconfig to skip this preflight."
echo -e "\e[0m"
exit 1
