# Manual verification checklist — align-cloud-local-server

Operator / board checks (not automated in CI):

- [ ] **Proxy off:** Device Information → tap Device SN five times → set Cloud Environment = Test; after Wi‑Fi up, HMI logs show API origin pin; WS connects or shows registration on 401.
- [ ] **Proxy on:** Enable HTTP proxy in Settings; confirm probe/WS still attempt via proxy (no crash).
- [ ] **Unbound bind:** With empty cloud users for SN, bind QR dialog appears; Cancel dismisses.
- [ ] **WS 401:** Registration dialog shows QR; Reconnect retries; Cancel does not auto-reconnect.
- [ ] **LAN `:5580`:** From host on same LAN: `curl http://<device-ip>:5580/lasercyber` → `Hello LaserCyber`.
- [ ] **LAN videos JSON:** `curl 'http://<device-ip>:5580/v1/videos'` → `ApiResult` JSON (may be empty list).
- [ ] **mDNS:** `avahi-browse -r _lws-device._tcp` shows device with TXT `connect_proto=http`, port `5580`.
- [ ] **OTA no-op:** If cloud sends `command.check_update`, HMI does not start download / progress UI.
- [ ] **Remote lock:** Force lock via WS (or set `/var/lib/hmi/remote-lock.json`); lock icon in status bar; Quick/Engineer blocked.

Automated coverage: `app/lws_hmi/test/cloud_local_server_foundation_test.dart`.
