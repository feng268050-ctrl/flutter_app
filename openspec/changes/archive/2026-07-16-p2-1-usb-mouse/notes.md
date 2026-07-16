# P2.1 USB mouse — spike notes

## Operator evidence (2026-07-15)

- USB mouse on existing host path **enumerates** and **scroll / click reach Flutter**.
- **No on-screen pointer** — motion still moves the logical cursor (wheel works under the hover/position path).

This matches a compositor cursor failure, not a missing HID path.

## Desk analysis (flutter-pi @ `37bd977`)

### Cursor path

1. Pointer capability → `on_set_cursor_enabled(true)` after first real mouse event.
2. Visual cursor = GBM BO with `GBM_BO_USE_CURSOR` + atomic fb layer (`prefer_cursor`) / `drmModeMoveCursor`.
3. **`cursor_buffer_new` rejects any BO whose stride ≠ `width * 4`:**

```c
if (gbm_bo_get_stride(bo) != rotated_size.x * 4) {
    LOG_ERROR("GBM BO has unsupported framebuffer stride...");
    goto fail_destroy_bo;  /* → no cursor at all */
}
```

Rockchip/Mali typically **pads** GBM cursor/scanout stride (e.g. 64-byte align). That fails this strict check → `window->kms.cursor` stays NULL → scroll/click still work, **no visible arrow**. Upstream issue class: ardera/flutter-pi#456 (`drmModeMoveCursor` / cursor buffer layout).

### libinput / scroll hardcodes

- Wheel → Flutter delta: `scroll / 15.0 * 53.0` in `on_mouse_axis_event` (no preference).
- No calls to `libinput_device_config_*` for natural scroll / accel / left-handed.

## Strategy decision (task 1.3)

| Option | Verdict |
|--------|---------|
| Fix DRM cursor stride/write in flutter-pi | **Chosen primary** — OS compositor owns the pointer |
| Software cursor only in Demo Flutter overlay | Reject as sole fix (not OS-shell chrome) |
| Flutter soft-cursor fallback at app root | Keep as optional belt if stride fix insufficient on device |

**Implement:** `0004` cursor stride-tolerant buffer upload; `0005` mouse prefs (`/var/lib/lws-hmi/mouse.conf`) + libinput apply + scroll scale + SIGHUP reload.

Device tasks 2.3 / 6.3 still need operator smoke after `make rebuild-flutter-pi` + image flash.

## Pref file (task 3.1)

Path: `/var/lib/lws-hmi/mouse.conf` (key=value, one per line):

| Key | Default | Meaning |
|-----|---------|---------|
| `natural_scroll` | `0` | `1` = invert wheel (libinput natural scroll) |
| `scroll_speed` | `50` | 0–100 → wheel delta multiplier (maps around base 53/15) |
| `pointer_speed` | `50` | 0–100 → libinput accel speed [-1, 1] |
| `pointer_size` | `20` | 0–100 → cursor icon density (~ldpi…xxxhdpi); ceil + upscale so hand/text match arrow |
| `primary_button` | `left` | `right` = left-handed (swap buttons) |

Reload: flutter-pi loads at start, on each pointer **device-add**, and via **1 Hz mtime poll** of `mouse.conf`. Dart **only writes the file** — never `kill -HUP` (SIGHUP exits flutter-pi; `Restart=on-failure` does not bring `hmi.service` back on a clean stop).

## Cursor travel vs resolution (2026-07-16)

Under `-o landscape_left` (ynh960 default): `display_size` = panel mode (800×1280), `view_size` = Flutter logical (1280×800).

`user_input` and the KMS cursor plane use **display** coordinates; `compositor_set_cursor` was clamping to **view_size**, so the visible pointer could not cover the full panel. Fix: `0008-cursor-clamp-display-size.patch` clamps to `display_size` (0 .. w−1 / h−1), matching `user_input`.
