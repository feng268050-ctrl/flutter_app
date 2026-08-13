## 1. Disable Weston OSK (overlay)

- [x] 1.1 Smoke on device: set `[input-method]` disable in `/run/user/0/weston.ini`, restart HMI, confirm `pidof weston-keyboard` is empty; lock empty `path=` vs sentinel in `weston-hmi-config.sh`
- [x] 1.2 Always emit that disable policy from `weston_write_hmi_ini` for HMI runtime ini
- [x] 1.3 Align static `etc/xdg/weston/weston.ini` and post-hook `91-weston-ini.sh` with the same policy

## 2. Verify on device

- [x] 2.1 `make apply-overlay` then rootfs/upgrade (or equivalent) so the board picks up ini helpers
- [x] 2.2 Cold boot: no `weston-keyboard`; CyberIME still works; physical HID typing still works; ~23 MB RSS client gone
- [x] 2.3 Confirm `weston-mouse` remains N/A
