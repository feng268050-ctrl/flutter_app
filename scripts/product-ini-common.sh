#!/usr/bin/env bash
# Shared helpers for /var/lib/hmi/product.ini upsert/delete (host make set-prop / del-prop).
# shellcheck shell=bash

_product_ini_die() {
	echo "ERROR: $*" >&2
	exit 1
}

# Validate product.ini key (lowercase identifier).
validate_product_ini_key() {
	local key="$1"
	if [[ "${key}" =~ ^[a-z][a-z0-9_]*$ ]]; then
		return 0
	fi
	if declare -F die >/dev/null 2>&1; then
		die "invalid property key '${key}' (use lowercase letters, digits, underscores)"
	fi
	_product_ini_die "invalid property key '${key}' (use lowercase letters, digits, underscores)"
}

# Upsert key=value in a local properties file (replace existing key or append).
upsert_product_ini_in_file() {
	local key="$1" value="$2" file="$3"
	local tmp line
	validate_product_ini_key "${key}"
	tmp="$(mktemp)"
	if [[ -f "${file}" ]]; then
		while IFS= read -r line || [[ -n "${line}" ]]; do
			[[ "${line}" =~ ^${key}= ]] && continue
			[[ -z "${line}" ]] && continue
			printf '%s\n' "${line}" >>"${tmp}"
		done <"${file}"
	fi
	printf '%s=%s\n' "${key}" "${value}" >>"${tmp}"
	mv "${tmp}" "${file}"
}

# Remove key=... line from a local properties file (no-op if key absent).
# Returns 0 if removed, 1 if key was not present.
delete_product_ini_from_file() {
	local key="$1" file="$2"
	local tmp line found=0
	validate_product_ini_key "${key}"
	[[ -f "${file}" ]] || return 1
	tmp="$(mktemp)"
	while IFS= read -r line || [[ -n "${line}" ]]; do
		if [[ "${line}" =~ ^${key}= ]]; then
			found=1
			continue
		fi
		[[ -z "${line}" ]] && continue
		printf '%s\n' "${line}" >>"${tmp}"
	done <"${file}"
	if [[ "${found}" -eq 1 ]]; then
		mv "${tmp}" "${file}"
		return 0
	fi
	rm -f "${tmp}"
	return 1
}
