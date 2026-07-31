## Context

Buildroot package `bluez5_utils` is pinned at **5.77** in the Rockchip SDK tree. Product fragment `overlay/buildroot/chips/lws_hmi_bt.config` enables BlueZ + client/tools + `BLUEZ_ALSA` for opt-in A2DP Sink. `scripts/apply-overlay.sh` already **stashes** Rockchip’s `0001-bluez-modified-only-for-rockchip.patch` so Device1 Connect/Disconnect stay stock.

Device (2026-07-31): `bluetoothd` **5.77**, `JustWorksRepairing = always`, reconnect UUIDs include A2DP / AVRCP / HID / HOG; `obexd` binary present but not observed running; AVRCP UUIDs advertised.

Audit summary:

| Issue | Severity | Fix vehicle |
|-------|----------|-------------|
| CVE-2024-8805 (≈ CVE-2024-53144) | HIGH 8.8 | **Kernel** ≥ 6.1.115 (`kernel-61-lts-rebase`) |
| CVE-2023-44431 AVRCP | HIGH 8.0 | **No upstream fix** (Debian postponed through 5.87) |
| CVE-2023-51596 PBAP | HIGH 7.1 | **No upstream fix**; reduce surface if OBEX unused |
| AVRCP/OBEX Medium ZDI set | MEDIUM | Postponed; 5.82+ length/parsing fixes may help partially |
| General 5.78–5.87 deltas | — | Version bump |

Philosophy for this change: **take every available upgrade and hardening**, document what remains open, coordinate kernel work for the closable High.

## Goals / Non-Goals

**Goals:**

- Ship BlueZ userspace **≥ 5.87** from overlay-owned recipe.
- Keep stock D-Bus Device1 contract (Rockchip patch remains disabled).
- Close CVE-2024-8805 via dependency on kernel LTS rebase (not BlueZ `.mk` alone).
- Apply optional hardening that does not break required A2DP Sink / HID / HOGP product behaviors.
- Be honest in acceptance notes about postponed residual CVEs.

**Non-Goals:**

- Claiming zero High Bluetooth CVEs after this change alone.
- Waiting for upstream ZDI fixes before shipping 5.87.
- Replacing BlueZ or changing Flutter Bluetooth API shape.
- Enabling A2DP Source / HFP product roles.

## Decisions

### D1 — Userspace target: BlueZ 5.87+

Lock `BLUEZ5_UTILS_VERSION` (and matching `bluez5_utils-headers`) to **5.87** or newer 5.x tip at implement time. Prefer full recipe overlay under `overlay/buildroot/package/bluez5_utils/` (+ headers package dir if present) synced by `apply-overlay`, same pattern as planned `libopenssl` pin.

**Alternatives:** Stay on 5.77 + cherry-pick — rejected (poor SoT, misses 5.82 AVRCP length fixes). Jump only to 5.82 — rejected; tip is 5.87 and sid already tracks it.

### D2 — CVE-2024-8805 is a kernel deliverable

Do **not** treat BlueZ version bump as the fix for CVE-2024-8805. Implementation checklist MUST reference `kernel-61-lts-rebase` (ship kernel ≥ 6.1.115, preferably LTS tip). Order: kernel can land before/after BlueZ; **both** required for the HID Just-Works High narrative.

### D3 — Keep stock BlueZ; continue Rockchip patch stash

`sync_bluez5_utils_stock` remains mandatory after recipe sync so Connect(s) Rockchip ABI does not return. Document in tasks.

### D4 — Optional hardening ladder (apply what product allows)

| Tier | Action | When |
|------|--------|------|
| **H1** | Ensure OBEX/PBAP not started at boot; prefer Buildroot `--disable-obex` if phonebook/file transfer unused | Default **yes** unless a product requirement needs `obexd` |
| **H2** | Review `/etc/bluetooth/main.conf`: reconsider `JustWorksRepairing = always` → safer default (`never` / `confirm`) if UX allows; keep discoverable timeout | Spike with HID + phone pairing UX |
| **H3** | Trim reconnect UUID list to profiles actually needed | After confirming HID/A2DP still reconnect |
| **H4** | Keep `bluetoothd --noplugin=…` denylist for unused plugins if compile-time disable is harder | Only if H1 insufficient |

**Must keep:** Classic HID + HOGP input path, opt-in A2DP Sink + AVRCP for phone media (`linux-bluetooth`).

### D5 — Residual risk acceptance

Postponed ZDI items (esp. CVE-2023-44431 with AVRCP still enabled for A2DP Sink) remain a **known residual**. Acceptance text: upgraded to 5.87, kernel tip for CVE-2024-8805, OBEX/policy hardening as applied; AVRCP High tracked as upstream-wait / follow-up when a fix exists.

### D6 — bluez-alsa coupling

Rebuild/smoke `bluez-alsa` against new BlueZ libs if ABI/headers change. Existing overlay `bluez-alsa` patches (`0002-lws-…`) must still apply.

## Risks / Trade-offs

- **[Risk] 5.87 recipe needs newer Buildroot helpers** → Mitigation: adapt `.mk` from current BR recipe; fall back to highest buildable 5.8x ≥ 5.82 if 5.87 fails spike.
- **[Risk] HID/A2DP regress after bump** → Mitigation: mandatory smoke matrix; A/B rollback via previous rootfs letter.
- **[Risk] Hardening breaks Just-Works phone pairing** → Mitigation: H2 is spike-gated; do not ship stricter policy without Demo/product sign-off.
- **[Risk] False sense of security** → Mitigation: D5 residual documentation in PR / vendor-import or BT security note.
- **[Trade-off] Keep AVRCP for A2DP UX vs disable to dodge CVE-2023-44431** → Prefer keep AVRCP + tip upgrade; disabling AVRCP only if product accepts loss of phone volume/metadata control.

## Migration Plan

1. Overlay pin 5.87 + sync + stock stash.
2. `br-make-packages` rebuild BlueZ (+ headers) → `build-rootfs` → `upgrade`.
3. Parallel/series: land kernel LTS for CVE-2024-8805.
4. Apply H1 (and H2–H4 if spike OK).
5. Smoke: stack up, pair phone A2DP, HID keyboard/mouse, agent prompts.
6. Rollback: previous rootfs A/B letter / reflash prior rootfs.img.

## Open Questions

- Exact tip if 5.88+ ships before implement.
- Whether product ever needs OBEX (default assume **no**).
- Product/UX approval for changing `JustWorksRepairing`.
- Whether `bluez5_utils-headers` must be version-locked in the same overlay commit (expect **yes**).
