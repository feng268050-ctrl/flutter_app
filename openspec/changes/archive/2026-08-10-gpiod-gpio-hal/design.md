## Context

`cyber_hal` today exposes config-driven **named GPIO lines** (`GpioHal.openLine` → `GpioLine.set` / `get` / `setMode`), writing Innohi **`/sys/class/gpio_innohi/*/value`** (with classic `/sys/class/gpio` export fallback). Product App maps `led_red` / `led_yellow` / `led_green` via `GpioLedController`; RGB **policy** stays in App code.

On ynh960, `/dev/gpiochip0`–`gpiochip5` exist alongside **`/sys/class/gpio_innohi`** (`GPIO_1`…`GPIO_8`, **`BELL`**, plus `LED_RED` / `LED_BLUE` in DTS). Innohi `own-gpio` hogs those labeled lines for sysfs. Two of the side-panel LED pads were reclaimed from other functions (uart4 / COM4 silk → `GPIO_5`/`GPIO_4` per pinmux ledger). Appliance code wants **device** APIs (status lights, buzzer, keys, encoder), but the HAL must speak **both** character-device gpiod and legacy sysfs—often on the same board, chosen per line—because hogged lines may refuse a second gpiod request.

## Goals / Non-Goals

**Goals:**

- Portable **device** façade: Status LED bank, Buzzer, Button (long-press), RotaryEncoder (debounce).
- **Config-only hardware map:** which devices exist, how many LED channels / buttons / encoders, logical ids, scheme, chip/offset, and sysfs `path`/`label` come **only** from App-owned `gpio.json` (via `BoardProfile.configs.gpio`). Different boards enable a subset, a superset, or alternate paths without HAL code changes.
- **Dual Linux backends:** `gpiod` (`flutter_gpiod` / `/dev/gpiochip*`) **and** `sysfs_innohi` (configurable label/path under `/sys/class/…`), selectable **per binding** in config; stub/sim for host tests.
- Record ynh960 RGB + Bell as **example product config / docs** from DTS—not as package constants.
- Preserve Steady / Blink / Off semantics and App LED policy separation.
- No new GPIO daemon.

**Non-Goals:**

- Baking ynh960 (or any SKU) pin tables, `GPIO_N` labels, or `/sys/class/gpio_innohi/…` strings into `cyber_hal` Dart.
- Requiring every board to ship exactly three RGB channels or a buzzer/encoder.
- Changing RGB laser/alarm/ready policy.
- Removing or rewriting Innohi `own-gpio` / `gpio_innohi` in-tree driver in this change.
- Replacing audio / CyberUI sound-effect with the GPIO buzzer.
- Shipping `libproxy_gpiod.so` / pub `gpiod`+proxy.
- Product UI for encoder/key beyond HAL + tests (unless already present).

## Decisions

### D0 — Pins and paths only in `gpio.json`

**Choice:** HAL APIs take **logical device/channel ids** from the loaded config. Hardware addressing (scheme, chip, offset, sysfs path/label, active_low, debounce) is data. Product Apps MAY use stable logical names (`chassis_rgb` / `red`, `panel_buzzer`) across boards while each board’s `gpio.json` (or profile asset) supplies the map. Boards with no buzzer omit the device (or set capability false); boards with extra indicators add channels; boards with a different sysfs class use a different `path` prefix/label—still config-only.

**Forbidden in portable HAL:** `const` SoC numbers, hard-coded `GPIO_5`, hard-coded `/sys/class/gpio_innohi/…`, or “ynh960 always has these three lines” branches.

**Allowed:** Parsing helpers, scheme dispatch, device behavior (blink/long-press/quadrature). ynh960 numbers belong in `app/lws_hmi/assets/hal/gpio.json` and human docs (`ynh960-io-pinmux-ledger.md`), not in `packages/cyber_hal/lib/**` as literals tied to that board.

**Alternatives:** Board-id switch inside HAL — rejected (same motherboard, multiple products; profile already points at App assets).

### D1 — Dual line backends behind one device API

**Choice:** Device types are backend-agnostic. Each config line binding includes a **scheme**:

| Scheme | Addressing | Typical use |
|--------|------------|-------------|
| `gpiod` | `chip` + `offset` (optional chip `label`) | Free lines; inputs needing edges |
| `sysfs_innohi` | `label` and/or `path` under `/sys/class/gpio_innohi` | Lines owned by Innohi `own-gpio` today (RGB, BELL, …) |
| `sysfs_export` | classic `fallback_linux_gpio` export | Engineering fallback only |
| `stub` | in-memory | Host tests / sim |

Document-level `backend` MAY be a **default scheme** (`auto` / `gpiod` / `sysfs_innohi`); per-line `scheme` overrides. **Do not** delete sysfs support after adding gpiod.

**Alternatives considered:** gpiod-only cutover — rejected (own-gpio hog; field boards already on sysfs). Sysfs-only — rejected (no clean edges for button/encoder).

### D2 — Dart gpiod client: `flutter_gpiod`

**Choice:** Character-device path uses **`flutter_gpiod`**. Sysfs path keeps Dart `File` IO (current approach).

### D3 — Public API: devices first; inventory from config

**Choice:** `StatusLedBank`, `Buzzer`, `GpioButton`, `RotaryEncoder` as behavioral types. A Status LED bank’s **channel list is whatever `channels[]` declares** (not a fixed RGB enum inside HAL). Open-by-id returns only configured devices. Internal “logical line” driver dispatches by scheme. Product UI enums (e.g. App `LedColor.red`) map to **channel ids** that must exist in that product’s config—HAL does not assume red/yellow/green exist.

### D4 — Config schema v2 (devices + dual bindings)

**Choice:** `version: 2` with `devices[]`. v1 `lines[]` still loads via adapter → `status_led`. Sysfs bindings accept full `path` (boards with a non-Innohi class or alternate tree) and/or `label` resolved under a configurable base if needed later; v1 keeps today’s label+path fields.

Illustrative **product** snippet for ynh960 (lives in App assets—not HAL source):

```json
{
  "version": 2,
  "backend": "sysfs_innohi",
  "defaults": {
    "active_low": false,
    "blink_on_ms": 1000,
    "blink_off_ms": 1000,
    "button_debounce_ms": 30,
    "button_long_press_ms": 800,
    "encoder_debounce_ms": 2
  },
  "devices": [
    {
      "type": "status_led",
      "id": "chassis_rgb",
      "channels": [
        {
          "id": "red",
          "scheme": "sysfs_innohi",
          "label": "GPIO_5",
          "path": "/sys/class/gpio_innohi/GPIO_5/value",
          "gpiod": { "chip": "gpiochip3", "offset": 9 },
          "linux_gpio": 105
        },
        {
          "id": "yellow",
          "scheme": "sysfs_innohi",
          "label": "GPIO_4",
          "path": "/sys/class/gpio_innohi/GPIO_4/value",
          "gpiod": { "chip": "gpiochip3", "offset": 10 },
          "linux_gpio": 106
        },
        {
          "id": "green",
          "scheme": "sysfs_innohi",
          "label": "GPIO_7",
          "path": "/sys/class/gpio_innohi/GPIO_7/value",
          "gpiod": { "chip": "gpiochip4", "offset": 21 },
          "linux_gpio": 149
        }
      ]
    },
    {
      "type": "buzzer",
      "id": "panel_buzzer",
      "line": {
        "scheme": "sysfs_innohi",
        "label": "BELL",
        "path": "/sys/class/gpio_innohi/BELL/value",
        "gpiod": { "chip": "gpiochip3", "offset": 27 },
        "linux_gpio": 123
      }
    }
  ],
  "capabilities": {
    "status_led": true,
    "buzzer": true,
    "button": false,
    "rotary_encoder": false
  }
}
```

Optional parallel `gpiod` / `linux_gpio` fields are **documentation / future switch** when `scheme` flips; runtime uses `scheme` only.

### D5 — Example: ynh960 product map (docs / `gpio.json` only)

Authoritative for **this** board’s App config content; derived from `overlay/kernel/rockchip/ynh960-own-gpio.dtsi` (Rockchip: `PAx=0..7`, `PBx=8..15`, `PCx=16..23`, `PDx=24..31`; global `# = bank*32 + offset`). **Not** compiled into HAL.

| Role | gpio_innohi label | Pad | gpiochip / offset | Linux # |
|------|-------------------|-----|-------------------|---------|
| LED red | `GPIO_5` | gpio3 RK_PB1 | `gpiochip3` / **9** | 105 |
| LED yellow | `GPIO_4` | gpio3 RK_PB2 | `gpiochip3` / **10** | 106 |
| LED green | `GPIO_7` | gpio4 RK_PC5 | `gpiochip4` / **21** | 149 |
| Buzzer (candidate) | `BELL` (DTS comment Bell-CTL) | gpio3 RK_PD3 | `gpiochip3` / **27** | 123 |

Other own-gpio labels (`GPIO_1`…`3/6/8`, `LED_RED`/`LED_BLUE`, …) are available to **add** as further devices/channels in config when a product needs them. Button/encoder: omit from config until assigned; HAL still offers the device types.

### D6 — Blink / beep timers; input edges vs poll

**Choice:** LED blink and buzzer patterns = Dart `Timer` + logical line set (either backend).

**Inputs:**

- `scheme: gpiod` → edge events via `flutter_gpiod` (preferred for button/encoder).
- `scheme: sysfs_innohi` → **debounced poll** of `value` (or documented inotify if reliable); MUST be called out as lower quality than edges. Prefer migrating input lines to gpiod (and freeing them from `own-gpio`) when product needs solid long-press/encoder.

### D7 — Stub / sim / permissions / App migration

Unchanged intent: stub backend; sim JSON without requiring Innohi; `gpio` group for chardev when used; `GpioLedController` wraps `StatusLedBank`; wire `panel_buzzer` when ready.

## Risks / Trade-offs

- **[Risk] gpiod request fails while `own-gpio` holds the line** → Mitigation: default ynh960 product config to `sysfs_innohi` for RGB/BELL; document `EBUSY`; do not silently fight the hog.
- **[Risk] Wrong sysfs name for Bell** → Mitigation: probe `BELL` vs DTS comment; config `path`/`label` override.
- **[Risk] Chip index vs label drift across kernel builds** → Mitigation: prefer documented `gpiochipN` matching bank N on RK356x; allow label match; keep `linux_gpio` as human reference only.
- **[Risk] Sysfs poll misses short encoder detents** → Mitigation: require `gpiod` scheme for encoder when possible; document poll limits for buttons.
- **[Trade-off] Dual backends increase code paths** → Accepted for field compatibility and gradual migration.

## Migration Plan

1. Introduce device APIs + shared logical-line layer; keep current sysfs behavior for existing `lines[]`.
2. Add gpiod backend; per-binding `scheme`.
3. Ship v2 `gpio.json` with **sysfs_innohi** RGB (+ optional BELL buzzer) and recorded gpiod equivalents.
4. Button/encoder when pins known—prefer gpiod bindings.
5. Optional later: free selected lines from `own-gpio` and flip `scheme` to `gpiod` without App API changes.
6. **Do not** remove sysfs backend as a success criterion of this change.

## Open Questions

1. On-device sysfs name for buzzer: exact directory under `gpio_innohi` (`BELL` vs other)?
2. Active level for `BELL` (active-high assumed until measured).
3. Encoder push = sibling `button` device? (**Default: yes.**)
4. Which of `GPIO_1/2/3/6/8` (if any) are reserved for future key/encoder on this PCB?
