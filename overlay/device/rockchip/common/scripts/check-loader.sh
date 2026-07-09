#!/bin/bash -e
# lws-hmi: allow U-Boot build with python3 when python2 is absent (Docker 22.04).

if ! command -v python2 >/dev/null 2>&1; then
	if command -v python3 >/dev/null 2>&1; then
		mkdir -p /usr/local/bin
		ln -sf "$(command -v python3)" /usr/local/bin/python2
	fi
fi

if ! command -v python2 >/dev/null 2>&1; then
	echo "ERROR: python2 or python3 required for U-Boot build" >&2
	exit 1
fi
