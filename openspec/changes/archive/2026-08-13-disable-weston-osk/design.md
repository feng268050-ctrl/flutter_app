## Context

Device memory ranking showed `/usr/libexec/weston-keyboard` (~23 MB RSS) as a child of `weston`. It is Weston’s optional on-screen keyboard / input-method client, started because runtime `weston.ini` omits `[input-method]` and Weston 14 falls back to `@libexecdir@/weston-keyboard`.

This is **unrelated** to USB/BT physical keyboards (evdev → libinput → XKB → Flutter) and **unrelated** to CyberIME (in-app soft keyboard). An earlier idea to gate it behind an OS Settings “use physical keyboard” switch is dropped: there is no product need to ever run this client.

## Goals / Non-Goals

**Goals:**

- Never start `weston-keyboard` on the HMI Weston seat (cold boot and after ini rewrite).
- Keep CyberIME and physical-keyboard behavior unchanged.

**Non-Goals:**

- OS Settings toggle or `use_physical` preference.
- Changing CyberIME HID auto-hide.
- Removing `weston-desktop-shell`, deleting the binary from the package (optional later trim), or adding `weston-mouse` controls.
- Patching Weston upstream beyond ini policy.

## Decisions

### D1 — Always emit disabled `[input-method]` in HMI weston.ini

**Choice:** `weston_write_hmi_ini` always writes the smoke-proven disable form (prefer empty `path=`; sentinel path if empty falls back to default on 14.0.1). Mirror in static `weston.ini` / post-hook so non-runtime configs match.

**Rejected:** Settings-gated enable — no product consumer for Weston OSK; physical keyboard does not need it.

### D2 — No HAL / App surface

**Choice:** Overlay-only change. No `keyboard.conf` key, no OS Settings row, no CyberIME detector changes.

### D3 — weston-mouse

**Choice:** Absent; no work.

## Risks / Trade-offs

- **[Risk] Empty `path=` ignored → client still starts** → Device smoke; use non-executable sentinel if needed.
- **[Risk] Non-product Wayland clients lose Weston OSK** → Acceptable (`weston-terminal` etc. are not product UX).
- **[Trade-off] Binary may remain on rootfs** → Fine for v1; optional Buildroot trim later.

## Migration Plan

1. Ship overlay; next HMI start has no `weston-keyboard`.
2. No userdata migration.
3. Rollback: remove `[input-method]` disable → prior auto-start.

## Open Questions

1. ~~Confirm empty `path=` vs sentinel on device during implement (task 1.1).~~
   **Resolved:** On Weston 14.0.1, empty `path=` still launches `/usr/libexec/weston-keyboard`.
   Locked policy: `path=/bin/false` (client never starts; compositor retries then gives up).
