# USB MTP for OTG mode=mtp (hal-usb-otg)

Kernel (ynh960-usb-gadget.config):

- `CONFIG_USB_CONFIGFS` / `CONFIG_USB_CONFIGFS_F_FS` / `CONFIG_USB_F_FS`
- `CONFIG_USB_CONFIGFS_UEVENT=y` — `android_work` uevents (Android UsbDeviceManager model)
- `CONFIG_USB_FUNCTIONFS=m` (optional `g_ffs`; we use configfs + FunctionFS mount)

Userspace:

- **umtprd** (uMTP-Responder) — `make build-umtprd` → `prebuilt/umtprd/aarch64/` + overlay `/usr/bin/umtprd`
- Helpers:
  - `/usr/libexec/hmi/usb-mtp-start.sh` — unload `g_ether`, create configfs gadget `lws-mtp`, mount FunctionFS, start umtprd, bind UDC
  - `/usr/libexec/hmi/usb-mtp-stop.sh` — kill umtprd, unbind UDC, unmount FunctionFS
- Storage root: `/userdata/storage` (created on start; FS stays mounted on device)
- Conf generated at `/etc/hmi/mtp/umtprd.conf` (VID `0x2207`, PID `0x0011`, product **LWS Storage**, Android MTP extensions)

Host clients: **OpenMTP**, Android File Transfer, `aft-mtp-cli`, etc. (not a USB mass-storage disk).

**Kernel note:** stock umtprd wants `CONFIG_POSIX_MQUEUE`. ynh960 enables it in `ynh960-usb-gadget.config`; until that kernel is flashed, the overlay ships a small umtprd patch that falls back to `/run/umtprd.lock` so MTP still starts.

**Out of scope:** cable attach/detach detection and status-bar USB icon. Mode is chosen in Settings → USB OTG only.
