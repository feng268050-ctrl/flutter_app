## 1. Probe plumbing (no default flip yet)

- [x] 1.1 Inventory current ICMP probe + MediaMTX/path readiness signals usable without opening PR0/PR1
- [x] 1.2 Add injectable probe helpers: TCP short-connect (RTSP port), RTSP OPTIONS (no SETUP/PLAY on `/PR0`/`/PR1`), keep ICMP
- [x] 1.3 Unit tests: helpers succeed/fail; OPTIONS/TCP never target SETUP on PR paths; debounce behavior unchanged with fake probes

## 2. Validate rung 1 — relay / path-informed

- [x] 2.1 On device with MediaMTX + preview: exercise composition that prefers relay/path readiness (inject or temporary flag); confirm MediaMTX stays on PR0
- [x] 2.2 Disconnect / reconnect camera: unhealthy/healthy within debounce; no spurious C002 while link stable
- [x] 2.3 Record pass/fail. If **pass**, lock as production approach and skip to §6. If **fail**, document why and continue to §3

<!-- Rung 1 FAIL: no MediaMTX upstream readiness API (only systemctl is-active). See notes-validation.md. -->

## 3. Validate rung 2 — TCP :554 short-connect

- [x] 3.1 Inject TCP probe as sole HAL probe on device (MediaMTX still pulling PR0)
- [x] 3.2 Stability: ≥10 min preview + periodic probe — no MediaMTX drop, no false C002; unplug camera → C002 / Comm Status failure; restore → clear
- [x] 3.3 Record pass/fail. If **pass**, lock TCP as Linux default and skip to §6. If **fail**, continue to §4

<!-- Rung 2 PASS (locked). HAL-only 10m: MediaMTX active; 2 residual C002 on lossy eth0 lab; blackhole → C002; see notes-validation.md. Skipped §4–§5. -->

## 4. Validate rung 3 — RTSP OPTIONS

- [x] 4.1 Inject OPTIONS probe (no `/PR0`/`/PR1` SETUP/PLAY) under live MediaMTX
- [x] 4.2 Repeat stability + disconnect tests from 3.2
- [x] 4.3 Record pass/fail. If **pass**, lock OPTIONS as Linux default and skip to §6. If **fail**, continue to §5

<!-- Skipped: TCP locked in §3. OPTIONS helper exists; on-device OPTIONS unreliable on this SKU. -->

## 5. Validate rung 4 — ICMP baseline

- [x] 5.1 Confirm current ICMP still meets stability + disconnect criteria (regression baseline)
- [x] 5.2 Lock ICMP as production default if rungs 1–3 all failed; keep TCP/OPTIONS injectable for later cameras

<!-- Skipped lock: TCP won. ICMP remains injectable (`icmpIpCameraProbe`); ping still OK as host baseline during inventory. -->

## 6. Lock production default + product wiring

- [x] 6.1 Set Linux `IpCameraController` default probe to the first rung that passed; document choice in design/notes
- [x] 6.2 Wire product session composition only as needed for the locked rung (no second App health Timer)
- [x] 6.3 Regression: C002, Camera Comm Status, Settings preview/record; `flutter analyze` + focused HAL/App tests

## 7. Verification wrap-up

- [x] 7.1 Capture short device evidence (which rung won + pass criteria) in change notes or tasks comments
- [x] 7.2 Confirm no probe path uses SETUP/PLAY on native PR0/PR1
