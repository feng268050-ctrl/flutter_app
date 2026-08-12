# Settings Apps — Role Decision

> **Canonical policy** for how **OS Settings** and **HMI Settings** relate inside **Cyber OS** (embedded appliance line). Implementation detail, lifecycle, and copy/migrate tables live in [`os-settings-app-plan.md`](os-settings-app-plan.md).

---

## 1. Role decision

| | **OS Settings** | **HMI Settings** |
|---|-----------------|------------------|
| **What it is** | The **real system Settings app** — a core component of the generic **Cyber OS** platform | A **simplified + product-customized** view of system settings, embedded in the product HMI |
| **App id / path** | `os_settings` → `/opt/os_settings` | `lws_hmi` (and future `*_hmi`) → `/opt/hmi` |
| **Boot** | On demand (`os-settings.service`, static) | Default seat (`hmi.service`, multi-user) |
| **Scope** | Full platform configuration (network stack, input devices, OS inventory, storage/secrets, locale, display/sound/power at HAL level) | Product operator workflow: device/peripheral versions, OTA, cloud, camera/LED, Advanced/Custom Home, plus **convenient copies** of everyday prefs |
| **Product assets** | OEM `board_profile` only — **no** `gpio.json` / `modbus.json` | Full product profile + Modbus register map + ship assets |
| **Audience** | Integrators, **factory / after-sales**, field service — settings end users rarely touch (e.g. UI Scale, cloud env tier) | Daily machine operators who stay in the welding/product UI |

**One sentence:** OS Settings is authoritative for **platform/system** configuration (including factory/field-service knobs); HMI Settings is the **product-facing subset** that keeps common everyday prefs reachable without leaving the HMI seat.

---

## 2. Two apps, one HAL

Both apps are Flutter clients of the same **`cyber_hal`** package. Persisted prefs live under `/var/lib/hal/` (and related paths). Changing Wi‑Fi, locale, brightness, etc. in either seat updates the **same store** — the other app sees the result on next open. **UI scale** (`display.conf` `ui_scale`) is written only from **OS Settings** (factory/after-sales); product HMI **reads** the same key at boot — `1.0` = physical 1:1 (no rematch); no slider in HMI Display.

Only **one Flutter seat** runs at a time (`hmi.service` ↔ `os-settings.service` bidirectional `Conflicts=`).

```
Operator on HMI seat
    → Device Info → tap Device SN 5× → switch-to-os-settings
    → full platform Settings (Exit → switch-to-hmi)

Operator on OS Settings seat
    → Status bar Exit → switch-to-hmi
```

See [`os-settings-app-plan.md` §7](os-settings-app-plan.md) for scripts and failure behavior.

---

## 3. Feature ownership

Legend: **Copy** = implemented in both apps (HMI keeps a shortcut); **Migrate** = OS Settings only (removed from HMI); **HMI-only** / **OS-only** = single owner.

### 3.1 OS Settings only (Migrate / platform / factory)

| Feature | Notes |
|---------|--------|
| **UI Scale** | HAL `display.conf` `ui_scale` (`1.0` = physical 1:1); factory/after-sales set once per panel — **not** exposed in HMI Display |
| **Power Mode** | HAL `power.conf` (`performance` / `balanced`); product HMI **reads** for continuous-paint policy — **no** Settings entry |
| Ethernet | Full link + **IPv4 Address / DNS** groups (Wi‑Fi Details parity; cable link under switch) |
| Bluetooth | Adapter + alias = Brand + Model |
| LAN SSH debug | On-demand SSH |
| Cloud Environment | Production (default) or test API tier; `/var/lib/network/cloud.conf`; HAL `CloudApiOriginProber` picks Worker/hyurl origin |
| Keyboard | Layout + Apply (restarts `os-settings.service`) |
| Mouse | Natural scroll, tracking, pointer size |
| USB OTG | debug / MTP / host |
| Operating System | Platform versions (no Platform section title) + Security (incl. Secrets Seal) + Runtime + Connectivity |
| About (platform) | Brand / model / SN (identity) |
| Storage | Capacity bar |

### 3.2 Copy — both apps, shared HAL

| Feature | HMI entry | OS Settings entry | Shared store |
|---------|-----------|-------------------|--------------|
| Wi‑Fi | Common → Network | Network | wpa / connection state |
| HTTP Proxy | Common → Network | Network | proxy prefs |
| Date & Time | Common | Date & Time | datetime HAL |
| Country / Region | Common (Locale card) | Locale | `locale.conf` `region` |
| Language | Common (Locale card) | Locale | `locale.conf` `language` |
| Unit | Common (Locale card) | Locale | `locale.conf` `unit` |
| Display | Common → Display (+ Sound + Camera card) | Display | `display.conf` (brightness, auto-sleep, wallpaper) |
| Sound (volume) | Common → Sound (+ Display + Camera card) | Sound | `sound.conf` `volume` |

**Copy is intentional** — operators can adjust everyday prefs from the HMI without a seat switch. OS Settings remains the **complete** surface for the same HAL keys plus migrated-only pages.

### 3.3 Split surfaces (same HAL, different UX depth)

| Topic | HMI Settings | OS Settings |
|-------|--------------|-------------|
| **Identity / storage** | Device Information tab: model, SN, QR, peripheral versions, storage bar | About + Storage + OS detail pages |
| **Display** | Brightness, auto-sleep, wallpaper + **Text size** (product `common-settings.json`) | Brightness, auto-sleep, wallpaper preview + **UI scale** (factory/field) — no text size |
| **Sound** | Volume + **sound effect picker** (installs catalog MP3s) | **Volume only** — uses HMI-installed click sample via HAL; no product audio assets |
| **OS version** | Single “OS Version” row → System Upgrade | Full grouped inventory (kernel, SELinux, Buildroot, …) |

### 3.4 HMI Settings only (never in OS Settings)

| Feature | Tab / area |
|---------|------------|
| Device/peripheral versions + OTA navigation | Device Information |
| Cloud services + LAN enhancement toggles | Common → Network (env tier **not** here) |
| RGB LED | Common (nav **hidden**; page code retained) |
| IP Camera | Common (with Display + Sound) |
| Advanced Settings (Modbus thresholds, AI, dangerous ops) | Advanced |
| Custom Home editor | Custom Home |
| Boot self-check, status overlay, safety-ground alarm toggles | Common → Misc |
| Text size (product UI scale) | Display sub-page |

Welding/process/monitor business UI stays in the HMI app routes, not in OS Settings.

---

## 4. Code review (2026-08)

Review against the role decision above.

### 4.1 OS Settings (`app/os_settings`)

| Check | Status |
|-------|--------|
| Flat platform IA (About, OS, Storage, Network, Access, Locale, Display, Input, …) | ✅ |
| No product gpio/modbus / Modbus thresholds / cloud / camera / OTA | ✅ |
| Migrated pages present (Ethernet, BT, SSH, Keyboard, Mouse, USB OTG, Power Mode) | ✅ |
| Copy pages share HAL with HMI | ✅ |
| Sound: volume only, no bundled click assets | ✅ (product HMI owns effect install + picker) |
| Exit → HMI, no multi-user autostart | ✅ |
| l10n wired to HAL `LocaleSettings` | ✅ (in progress on secondary pages) |

### 4.2 HMI Settings (`app/lws_hmi`)

| Check | Status |
|-------|--------|
| Four-tab shell (Device Info / Common / Advanced / Custom Home) | ✅ |
| Explicit **OS Settings** entry → `switch-to-os-settings` | ✅ Device Info → Device SN 5× (`device_information_tab.dart`) |
| Migrated rows **removed** (Ethernet, BT, SSH, Keyboard, Mouse, USB OTG, Power Mode) | ✅ |
| Copy rows retained (Wi‑Fi, proxy, locale, display, sound, datetime); Common regrouped (Date & Time before locale; Display+Sound+Camera; LED hidden) | ✅ |
| Sound effect + sample install stays in HMI | ✅ |
| Text size stays HMI-only | ✅ |
| Product-only tabs/content not duplicated in OS Settings | ✅ |

### 4.3 Known follow-ups (not role violations)

| Item | Owner | Notes |
|------|-------|-------|
| Archive `openspec/changes/os-settings-app` → main specs | Docs | `openspec/specs/settings-ui/spec.md` updated to match split |
| On-device acceptance 9.4–9.5 | QA | Round-trip seat switch, dual-bundle verify |
| Optional Home-page OS Settings shortcut | Product | Not used; entry is Device SN 5× only |
| OS Settings l10n coverage on all sub-pages | OS Settings | Infrastructure in place; finish remaining strings |

---

## 5. Related docs

| Doc | Role |
|-----|------|
| [`os-settings-app-plan.md`](os-settings-app-plan.md) | Build, IA, copy/migrate table, lifecycle, acceptance |
| [`hal-portability.md`](hal-portability.md) | Shared HAL pref paths (`display.conf`, `sound.conf`, …) |
| [`openspec/specs/settings-ui/spec.md`](../openspec/specs/settings-ui/spec.md) | Normative **HMI Settings** requirements (post-split) |
| [`openspec/changes/os-settings-app/specs/os-settings-app/spec.md`](../openspec/changes/os-settings-app/specs/os-settings-app/spec.md) | Normative **OS Settings** requirements |
| [`app/os_settings/README.md`](../app/os_settings/README.md) | App quick reference |
| [`AGENTS.md`](../AGENTS.md) | Rebuild commands for `APP=os_settings` |
