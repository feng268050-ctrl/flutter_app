## Smoke checklist (peripheral firmware cloud OTA)

Host (requires `OTA_SIGNING_KEY` / `make ota-release-keys`, board HMI with updated watchers):

1. `make upgrade-control-board` — host HTTP transfer completes; device Modbus-flashes without confirm
2. `make upgrade-camera` — same for camera CGI path
3. `make login` then `make publish-control-board-firmware` / `make publish-camera-firmware` — R2 objects + `release.json` (api-server may need key allowlist for `lws-hmi/control-board/*` and `lws-hmi/camera/*`)

On device (Settings):

1. Control-board / camera upgrade pages: Check for Updates hits `/r2/lws-hmi/{control-board|camera}/release.json`
2. Newest-wins vs bundled; Update Now downloads + verifies before apply
3. Device Information Auto-Check for Updates master switch gates Home tips + page auto-check; does not auto-apply; no per-page checkboxes
4. Home tip can offer cloud-newer candidate (CB before camera) when Auto-Check is on
5. Update Now: jobs stop; Wi‑Fi/BT off before flash; radios restored after; camera path quiets C002
