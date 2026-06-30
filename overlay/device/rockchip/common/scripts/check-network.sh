#!/bin/bash -e

SITE="${1:-www.baidu.com}"
SITE_NAME="${2:-$SITE}"
EXTRA_MSG="$3"

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
echo -ne "\e[0m"

if [ -z "$RK_NETWORK_CHECK" ]; then
	echo -ne "\e[35m"
	echo "Will continue in 5 seconds ..."
	for S in $(seq 0 4); do
		echo "$((5 - $S)) ..."
		sleep 1
	done
	echo -e "\e[0m"
else
	echo -ne "\e[35m"
	echo "Unset RK_NETWORK_CHECK in the SDK config to continue..."
	echo -e "\e[0m"
	exit 1
fi
