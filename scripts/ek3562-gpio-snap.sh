#!/bin/sh
# Fast SoC GPIO diff via debugfs (no gpio export — avoids hangs).
#
#   sh /userdata/gpio-snap.sh arm
#   # at prompt: short INx to GND, hold, press Enter
#
# Or:
#   sh /userdata/gpio-snap.sh save before
#   sh /userdata/gpio-snap.sh save after
#   sh /userdata/gpio-snap.sh diff before after
set -u

DIR=/userdata/gpio-snaps
DBG=/sys/kernel/debug/gpio
mkdir -p "$DIR"

if [ ! -r "$DBG" ]; then
	echo "ERROR: $DBG not readable (need debugfs). mount -t debugfs debugfs /sys/kernel/debug"
	exit 1
fi

# Parse " gpio-113 ( ... ) in  lo" / "hi" lines into "113 0" / "113 1"
snap_to() {
	name=$1
	out="$DIR/${name}.txt"
	# shellcheck disable=SC2016
	sed -n 's/^ gpio-\([0-9][0-9]*\).* in  *\(hi\|lo\).*/\1 \2/p' "$DBG" \
		| awk '{print $1, ($2=="hi")?1:0}' \
		| sort -n >"$out"
	echo "saved $out ($(wc -l <"$out") lines) from debugfs"
}

diff_files() {
	a="$DIR/${1}.txt"
	b="$DIR/${2}.txt"
	[ -f "$a" ] && [ -f "$b" ] || {
		echo "missing snap files"
		exit 1
	}
	echo "changed ($1 → $2):"
	awk 'NR==FNR {a[$1]=$2; next}
		($1 in a) && a[$1]!=$2 {
			print "linux", $1, "before", a[$1], "after", $2
		}' "$a" "$b"
	echo "(empty ⇒ no line moved — bad contact, or input not on SoC GPIO)"
}

cmd=${1:?}
case "$cmd" in
save)
	snap_to "${2:?name}"
	;;
diff)
	diff_files "${2:?}" "${3:?}"
	;;
arm)
	snap_to before
	echo ""
	echo ">>> SHORT silk INx to GND and HOLD it."
	echo ">>> Then press Enter (do not release short until after Enter)."
	printf 'Enter when shorted… '
	read -r _
	snap_to after
	echo ""
	diff_files before after
	;;
show)
	# quick peek current in lines
	sed -n 's/^ gpio-\([0-9][0-9]*\).* in  *\(hi\|lo\).*/gpio-\1 \2/p' "$DBG" | head -40
	;;
*)
	echo "usage: $0 arm | save <name> | diff <a> <b> | show" >&2
	exit 1
	;;
esac
