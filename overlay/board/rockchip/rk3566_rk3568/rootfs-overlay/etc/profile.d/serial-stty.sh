# Re-apply serial geometry on each login (getty resets winsize; host may connect late).
case "$(tty 2>/dev/null)" in
/dev/ttyFIQ0|/dev/console)
	/usr/lib/lws-hmi/serial-console-stty.sh
	;;
esac
